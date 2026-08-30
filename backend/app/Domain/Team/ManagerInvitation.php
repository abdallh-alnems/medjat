<?php

declare(strict_types=1);

namespace App\Domain\Team;

use App\Mail\TeamInvitationMail;
use App\Support\Value;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * An invitation to join a company's management team.
 *
 * The code is stored hashed and returned exactly once. It is a credential that
 * turns a stranger into an administrator of somebody's company, so a database
 * read must not hand anybody a working one — the same reasoning as the kiosk
 * pairing code, and the opposite of the employee activation code, which is kept
 * in plaintext because it also has to be read aloud from a support call.
 */
final class ManagerInvitation
{
    public const VALIDITY_HOURS = 72;

    private const CODE_BYTES = 4;

    public static function hash(string $code): string
    {
        return hash('sha256', $code);
    }

    /**
     * @param  array{email: string, name: string, role: string, branch_id: int|null, permissions: list<string>|null}  $data
     * @return array{id: int, code: string, expires_at: string}
     */
    public static function create(int $tenantId, ?int $invitedBy, array $data): array
    {
        $code = self::generateUniqueCode();

        $id = (int) DB::table('manager_invitations')->insertGetId([
            'tenant_id' => $tenantId,
            'email' => $data['email'],
            'name' => $data['name'],
            'role' => $data['role'],
            'branch_id' => $data['branch_id'],
            'permissions' => $data['permissions'] === null ? null : json_encode($data['permissions']),
            'token_hash' => self::hash($code),
            'invited_by' => $invitedBy,
            // Computed by the database, not by PHP. PHP runs UTC while MySQL
            // runs the server zone, and the expiry is compared against the
            // database's NOW() — a PHP-computed one is hours short, so the
            // original's 72-hour window was really 69 in Cairo.
            'expires_at' => DB::raw('DATE_ADD(NOW(), INTERVAL '.self::VALIDITY_HOURS.' HOUR)'),
        ]);

        return ['id' => $id, 'code' => $code, 'expires_at' => self::expiryOf($id)];
    }

    /**
     * A fresh code on an existing invitation, and a fresh window.
     *
     * Also clears a cancellation, so "resend" un-does a cancel rather than
     * needing the row deleted and re-created — the invitation keeps its
     * identity and its audit trail.
     *
     * @return array{code: string, expires_at: string}|null
     */
    public static function regenerate(int $invitationId, int $tenantId): ?array
    {
        $code = self::generateUniqueCode();

        $affected = DB::update(
            'UPDATE manager_invitations'
            .' SET token_hash = ?, expires_at = DATE_ADD(NOW(), INTERVAL '.self::VALIDITY_HOURS.' HOUR),'
            .' cancelled_at = NULL'
            .' WHERE id = ? AND tenant_id = ? AND accepted_at IS NULL',
            [self::hash($code), $invitationId, $tenantId],
        );

        if ($affected === 0) {
            return null;
        }

        return ['code' => $code, 'expires_at' => self::expiryOf($invitationId)];
    }

    public static function cancel(int $invitationId, int $tenantId): void
    {
        DB::table('manager_invitations')
            ->where('id', $invitationId)->where('tenant_id', $tenantId)
            ->whereNull('cancelled_at')->whereNull('accepted_at')
            ->update(['cancelled_at' => DB::raw('NOW()')]);
    }

    /**
     * @return list<array<string, mixed>>
     */
    public static function forTenant(int $tenantId, ?string $status = null): array
    {
        $rows = DB::table('manager_invitations as mi')
            ->leftJoin('branches as b', 'b.id', '=', 'mi.branch_id')
            ->where('mi.tenant_id', $tenantId)
            ->when($status === 'pending', fn (QueryBuilder $q): QueryBuilder => $q
                ->whereNull('mi.cancelled_at')->whereNull('mi.accepted_at')
                ->whereRaw('mi.expires_at > NOW()'))
            ->when($status === 'accepted', fn (QueryBuilder $q): QueryBuilder => $q->whereNotNull('mi.accepted_at'))
            ->when($status === 'cancelled', fn (QueryBuilder $q): QueryBuilder => $q->whereNotNull('mi.cancelled_at'))
            ->when($status === 'expired', fn (QueryBuilder $q): QueryBuilder => $q
                ->whereNull('mi.cancelled_at')->whereNull('mi.accepted_at')
                ->whereRaw('mi.expires_at <= NOW()'))
            ->orderByDesc('mi.created_at')
            ->get(['mi.*', 'b.name as branch_name'])
            ->all();

        return array_values(array_map(
            static function (mixed $row): array {
                /** @var array<string, mixed> $columns */
                $columns = (array) $row;

                // The hash never leaves the server: it is the only thing
                // standing between a listing and a working invitation.
                unset($columns['token_hash']);

                return $columns;
            },
            $rows,
        ));
    }

    public static function pendingFor(int $tenantId, string $email): bool
    {
        return DB::table('manager_invitations')
            ->where('tenant_id', $tenantId)->where('email', $email)
            ->whereNull('cancelled_at')->whereNull('accepted_at')
            ->whereRaw('expires_at > NOW()')
            ->exists();
    }

    /**
     * The live invitation matching this code, or null.
     *
     * The expiry is compared in SQL. PHP runs UTC while MySQL runs the server
     * zone, so a PHP-side `strtotime($expires) < time()` — which is what the
     * join endpoint used to do — judges every invitation by a clock hours away
     * from the one that stamped it.
     *
     * @return array<string, mixed>|null
     */
    public static function redeemable(string $code): ?array
    {
        $row = DB::table('manager_invitations')
            ->where('token_hash', self::hash($code))
            ->first([
                'id', 'tenant_id', 'email', 'name', 'role', 'branch_id', 'permissions',
                'accepted_at', 'cancelled_at',
                DB::raw('expires_at < NOW() AS is_expired'),
            ]);

        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $invitation */
        $invitation = (array) $row;

        return $invitation;
    }

    /**
     * The most recent live invitation addressed to this email.
     *
     * @return array<string, mixed>|null
     */
    public static function pendingForEmail(string $email, ?int $invitationId = null): ?array
    {
        $row = DB::table('manager_invitations')
            ->where('email', $email)
            ->whereNull('cancelled_at')->whereNull('accepted_at')
            ->whereRaw('expires_at > NOW()')
            ->when($invitationId !== null, fn (QueryBuilder $q): QueryBuilder => $q->where('id', $invitationId))
            ->orderByDesc('created_at')
            ->first(['id', 'tenant_id', 'email', 'name', 'role', 'branch_id', 'permissions']);

        if ($row === null) {
            return null;
        }

        /** @var array<string, mixed> $invitation */
        $invitation = (array) $row;

        return $invitation;
    }

    /**
     * Claims the invitation for this administrator.
     *
     * The unclaimed guard lives inside the UPDATE, so two people racing the
     * same code cannot both be let into the company on one invitation.
     */
    public static function claim(int $invitationId, int $adminId): bool
    {
        return DB::table('manager_invitations')
            ->where('id', $invitationId)
            ->whereNull('accepted_at')->whereNull('cancelled_at')
            ->whereRaw('expires_at > NOW()')
            ->update(['accepted_at' => DB::raw('NOW()'), 'accepted_admin_id' => $adminId]) > 0;
    }

    /**
     * The page an invitee opens to redeem a code.
     *
     * Built from configuration rather than reconstructed from the request the
     * way the original did — it derived the backend root by cutting SCRIPT_NAME
     * at '/api/', which produced the wrong host the moment anything sat behind
     * a proxy or the endpoint moved.
     */
    public static function joinUrl(string $code): string
    {
        return rtrim(Config::string('medjat.join.base_url'), '/').'/join_team?code='.rawurlencode($code);
    }

    private static function expiryOf(int $invitationId): string
    {
        return Value::string(DB::table('manager_invitations')->where('id', $invitationId)->value('expires_at'));
    }

    private static function generateUniqueCode(): string
    {
        do {
            $code = strtoupper(bin2hex(random_bytes(self::CODE_BYTES)));
            $taken = DB::table('manager_invitations')->where('token_hash', self::hash($code))->exists();
        } while ($taken);

        return $code;
    }

    /**
     * Sends the invitation email, best-effort.
     *
     * The row is already committed by the time this runs and the code also
     * comes back in the API response for sharing by hand, so a dead mail server
     * must never cost anybody their invitation.
     */
    public static function email(string $to, string $code, string $role, string $companyName): void
    {
        try {
            Mail::to($to)->send(new TeamInvitationMail($code, $role, $companyName));
        } catch (Throwable $e) {
            Log::warning('Invitation email failed', ['email' => $to, 'exception' => $e]);
        }
    }
}

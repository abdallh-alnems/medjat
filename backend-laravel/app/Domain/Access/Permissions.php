<?php

declare(strict_types=1);

namespace App\Domain\Access;

use App\Models\CustomRole;

/**
 * Who can do what.
 *
 * Companies have no owner: `general_manager` is the top role, it can be granted
 * to anyone, and it holds everything — represented as the string '*' rather
 * than an exhaustive list so a newly added permission is covered the day it is
 * introduced instead of the day someone remembers to add it here.
 *
 * The clients gate their navigation on the effective set. A tab shown to
 * someone who cannot open it does not fail politely — it produces a backend 403
 * that surfaces as "an error occurred", so this list and the endpoint guards
 * have to agree.
 */
final class Permissions
{
    public const ALL = '*';

    /**
     * Every permission that exists, for the screen that hands them out.
     *
     * One list, deliberately. The original kept a second, staler catalogue for
     * granting — fourteen entries, missing the kiosk, biometric, analytics,
     * scheduling and approval permissions that the middleware had grown. That
     * gap was not cosmetic: an administrator holding a custom role built from
     * the small list could invite somebody into a *role*, and the invitee would
     * receive the middleware's larger set — permissions the inviter did not
     * hold. Equal-or-lower only means something if both sides are measured
     * against the same list.
     *
     * @var list<string>
     */
    public const CATALOGUE = [
        'manage_employees',
        'manage_attendance',
        'manage_schedule',
        'manage_leaves',
        'manage_payroll',
        'manage_deduction_rules',
        'manage_assets',
        'manage_documents',
        'documents_manage_types',
        'documents_verify',
        'documents_view_reports',
        'manage_recruitment',
        'manage_performance',
        'manage_engagement',
        'manage_approvals',
        'biometric_enroll',
        'biometric_delete',
        'kiosk_devices',
        'kiosk_access',
        'kiosk_evidence',
        'view_reports',
        'view_analytics',
        'add_managers',
        'manage_company_settings',
        'manage_support',
    ];

    /** The roles that belong on a company's team page. */
    public const MANAGEMENT_ROLES = ['general_manager', 'hr', 'branch_manager', 'attendance', 'viewer'];

    /**
     * @var array<string, string|list<string>>
     */
    private const ROLE_DEFAULTS = [
        'general_manager' => self::ALL,

        'hr' => [
            'manage_employees', 'manage_deduction_rules', 'manage_attendance', 'view_reports',
            'view_analytics', 'manage_documents', 'manage_payroll', 'manage_leaves',
            'manage_assets', 'manage_recruitment', 'manage_performance', 'manage_engagement',
            'manage_schedule', 'manage_approvals', 'biometric_enroll', 'biometric_delete',
            'kiosk_devices', 'kiosk_access', 'kiosk_evidence',
        ],

        // A branch manager runs the kiosk daily but does not pair or unpair
        // hardware — that is a decision about the fleet, not about a shift.
        'branch_manager' => [
            'manage_employees', 'manage_attendance', 'manage_documents', 'view_reports',
            'view_analytics', 'manage_assets', 'manage_recruitment', 'manage_performance',
            'manage_engagement', 'manage_schedule', 'biometric_enroll', 'kiosk_access',
            'kiosk_evidence',
        ],

        // An attendance clerk enrols faces but has no business browsing stored
        // captures of colleagues.
        'attendance' => ['manage_attendance', 'biometric_enroll', 'kiosk_access'],

        'viewer' => ['view_reports', 'view_analytics'],

        'employee' => [],
    ];

    /**
     * What a role grants before anybody customises it.
     *
     * @return list<string>|self::ALL
     */
    public static function defaultsFor(string $role): array|string
    {
        return self::ROLE_DEFAULTS[$role] ?? [];
    }

    /**
     * The permissions this administrator actually holds: a custom role if one
     * was assigned to them, otherwise their role's defaults.
     *
     * @return list<string>|self::ALL
     */
    public static function effectiveFor(int $adminId, int $tenantId, string $role): array|string
    {
        if ($role === 'general_manager') {
            return self::ALL;
        }

        $custom = CustomRole::permissionsFor($adminId, $tenantId);
        if ($custom !== null) {
            return $custom;
        }

        $defaults = self::ROLE_DEFAULTS[$role] ?? [];

        return is_string($defaults) ? $defaults : $defaults;
    }

    /**
     * Permissions that come free with a broader one.
     *
     * Documents were split into sub-permissions after the fact; anyone who
     * could already manage documents kept everything that used to be one
     * permission, rather than silently losing access on the day of the split.
     *
     * @var array<string, list<string>>
     */
    private const IMPLIED = [
        'manage_documents' => ['documents_manage_types', 'documents_verify', 'documents_view_reports'],
    ];

    /**
     * Does this administrator hold this permission, directly or by implication?
     *
     * The same question the middleware asks. Endpoints whose gate depends on
     * the request — reading somebody else's balance, or an action that needs
     * two permissions at once — ask it here rather than reimplementing it.
     */
    public static function holds(int $adminId, int $tenantId, string $role, string $permission): bool
    {
        $held = self::effectiveFor($adminId, $tenantId, $role);

        return $held === self::ALL || self::covers($held, $permission);
    }

    /**
     * @param  list<string>  $held
     */
    public static function covers(array $held, string $permission): bool
    {
        if (in_array($permission, $held, true)) {
            return true;
        }

        foreach (self::IMPLIED as $broader => $implied) {
            if (in_array($broader, $held, true) && in_array($permission, $implied, true)) {
                return true;
            }
        }

        return false;
    }

    /**
     * True when every permission in $granted is covered by $owner. Used to stop
     * an administrator granting a role or permission higher than their own.
     *
     * @param  list<string>  $granted
     * @param  list<string>|self::ALL  $owner
     */
    public static function isWithin(array $granted, array|string $owner): bool
    {
        if ($owner === self::ALL) {
            return true;
        }

        foreach ($granted as $permission) {
            if (! in_array($permission, $owner, true)) {
                return false;
            }
        }

        return true;
    }

    /**
     * True when the caller may edit, suspend or remove the target — that is,
     * when the caller's access is equal to or greater than the target's. Nobody
     * can act on someone holding a permission they lack; only a general manager
     * can act on a general manager.
     *
     * @param  list<string>|self::ALL  $caller
     * @param  list<string>|self::ALL  $target
     */
    public static function outranks(array|string $caller, array|string $target): bool
    {
        if ($caller === self::ALL) {
            return true;
        }

        if ($target === self::ALL) {
            return false;
        }

        return self::isWithin($target, $caller);
    }
}

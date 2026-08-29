<?php

declare(strict_types=1);

namespace App\Http\Controllers\Auth;

use App\Exceptions\ApiFailure;
use App\Http\ApiResponse;
use App\Mail\AuthActionMail;
use App\Services\Auth\FirebaseAccountManager;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Ports api/app/auth/send_password_reset.php and send_verification.php.
 *
 * Both answer success unconditionally. Telling a caller whether an address is
 * registered turns either endpoint into an account-enumeration oracle, and the
 * person who legitimately owns the address learns the answer from their inbox.
 */
final class SendAuthActionController
{
    public function __construct(private readonly FirebaseAccountManager $firebase) {}

    public function passwordReset(Request $request): JsonResponse
    {
        return $this->dispatch($request, AuthActionMail::RESET);
    }

    public function verification(Request $request): JsonResponse
    {
        return $this->dispatch($request, AuthActionMail::VERIFY);
    }

    private function dispatch(Request $request, string $kind): JsonResponse
    {
        $email = mb_strtolower(trim(Value::string($request->input('email'))));
        $lang = Value::string($request->input('lang'), 'ar');
        $name = trim(Value::string($request->input('name')));

        if ($lang !== 'en') {
            $lang = 'ar';
        }

        // A malformed address is refused: that is a client bug, not an account
        // that may or may not exist, so it leaks nothing to say so.
        if ($email === '' || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
            throw new ApiFailure('Invalid email', 400, 'invalid_email');
        }

        try {
            $link = $kind === AuthActionMail::RESET
                ? $this->firebase->passwordResetLink($email)
                : $this->firebase->emailVerificationLink($email);

            if ($link !== null) {
                Mail::to($email)->send(new AuthActionMail($kind, $lang, $name, $this->rebase($link)));
            }
        } catch (Throwable $e) {
            // Swallowed deliberately. A send failure must produce the same
            // response as an address nobody has registered.
            Log::warning('Auth action email not sent', ['kind' => $kind, 'exception' => $e->getMessage()]);
        }

        return ApiResponse::success(['success' => true]);
    }

    /**
     * Routes Firebase's action link through our own branded page, which enforces
     * the app's password rules.
     *
     * Only the base URL is swapped; Firebase's query string (mode, oobCode,
     * apiKey, lang) is carried across untouched, so this needs no change in the
     * Firebase console.
     */
    private function rebase(string $link): string
    {
        $base = Config::string('medjat.mail.action_url');
        $query = parse_url($link, PHP_URL_QUERY);

        if ($base === '' || ! is_string($query) || $query === '') {
            return $link;
        }

        return $base.(str_contains($base, '?') ? '&' : '?').$query;
    }
}

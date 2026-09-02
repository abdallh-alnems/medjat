<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Mail\AuthActionMail;
use App\Modules\Auth\Domain\AuthActionLink;
use App\Modules\Auth\Services\FirebaseAccountManager;
use App\Shared\Async\AfterResponse;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Mail;

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
            throw new ApiFailure(__('messages.email_invalid'), 400, 'invalid_email');
        }

        // After the response, not before it. This answers success no matter
        // what happens below — that is the enumeration guard — so there is
        // nothing the caller learns by waiting, and two network round trips
        // (Firebase for the link, then SMTP) is a long time to say nothing.
        // Failures are swallowed exactly as before: a send that failed must
        // look identical to an address nobody has registered.
        AfterResponse::run('Auth action email', function () use ($kind, $email, $lang, $name): void {
            $link = $kind === AuthActionMail::RESET
                ? $this->firebase->passwordResetLink($email)
                : $this->firebase->emailVerificationLink($email);

            if ($link !== null) {
                Mail::to($email)->send(new AuthActionMail($kind, $lang, $name, AuthActionLink::rebase($link)));
            }
        }, ['kind' => $kind]);

        return ApiResponse::success(['success' => true]);
    }
}

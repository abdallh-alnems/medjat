<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;

final class AdminLoginRequest extends ApiRequest
{
    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        return [
            'token' => ['required', 'string'],
            'device_id' => ['nullable', 'string'],
        ];
    }

    protected function validationMessage(): string
    {
        return 'Token is required';
    }

    protected function validationErrorCode(): string
    {
        return 'token_required';
    }

    protected function validationStatus(): int
    {
        return 400;
    }

    public function idToken(): string
    {
        return $this->requiredString('token');
    }

    /**
     * The header is what current builds send; the body field is what older ones
     * do. Both are accepted for as long as those builds are installed.
     */
    public function deviceId(): ?string
    {
        $header = $this->header('X-Device-Id');
        if (is_string($header) && $header !== '') {
            return $header;
        }

        return $this->nullableStr('device_id');
    }
}

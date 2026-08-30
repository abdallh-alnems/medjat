<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;

final class EmployeeWebLoginRequest extends ApiRequest
{
    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string'],
            // Not length- or format-checked here: the response to a malformed
            // PIN has to be identical to the response to a wrong one, or the
            // endpoint tells an attacker when they are close.
            'pin' => ['required', 'string'],
            'device_id' => ['required', 'string'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'phone' => trim($this->string('phone')->toString()),
            'device_id' => trim($this->string('device_id')->toString()),
        ]);
    }

    public function phone(): string
    {
        return $this->requiredString('phone');
    }

    public function pin(): string
    {
        return $this->requiredString('pin');
    }

    public function deviceId(): string
    {
        return $this->requiredString('device_id');
    }
}

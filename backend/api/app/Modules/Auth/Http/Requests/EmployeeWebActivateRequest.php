<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Requests;

use App\Shared\Http\ApiRequest;

final class EmployeeWebActivateRequest extends ApiRequest
{
    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string'],
            'activation_code' => ['required', 'string'],
            // Format is judged by PinPolicy once the employee is known, because
            // one of the rules compares the PIN against their phone number.
            'pin' => ['required', 'string'],
            'device_id' => ['required', 'string'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'phone' => trim($this->string('phone')->toString()),
            'activation_code' => strtoupper(trim($this->string('activation_code')->toString())),
            'device_id' => trim($this->string('device_id')->toString()),
        ]);
    }

    public function phone(): string
    {
        return $this->requiredString('phone');
    }

    public function activationCode(): string
    {
        return $this->requiredString('activation_code');
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

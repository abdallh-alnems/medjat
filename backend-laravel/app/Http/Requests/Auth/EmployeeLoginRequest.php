<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;

final class EmployeeLoginRequest extends ApiRequest
{
    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string'],
            'activation_code' => ['required', 'string'],
            'device_id' => ['required', 'string'],
            'device_model' => ['nullable', 'string'],
            // Not validated against a list: an unrecognised value is normalised
            // to android rather than refused, so a client build that starts
            // sending something new is not locked out over a label.
            'platform' => ['nullable', 'string'],
            'app_version' => ['nullable', 'string'],
        ];
    }

    /**
     * The apps send these with surrounding whitespace often enough to matter,
     * and the code is compared in upper case.
     */
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

    public function deviceId(): string
    {
        return $this->requiredString('device_id');
    }

    public function deviceModel(): ?string
    {
        return $this->nullableStr('device_model');
    }

    public function platform(): string
    {
        return $this->nullableStr('platform') ?? 'android';
    }

    public function appVersion(): ?string
    {
        return $this->nullableStr('app_version');
    }
}

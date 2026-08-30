<?php

declare(strict_types=1);

namespace App\Http\Requests\Auth;

use App\Http\Requests\ApiRequest;

final class EmployeeActivateTokenRequest extends ApiRequest
{
    /**
     * @return array<string, list<string>>
     */
    public function rules(): array
    {
        return [
            'token' => ['required', 'string'],
            'device_id' => ['required', 'string'],
            'device_model' => ['nullable', 'string'],
            'platform' => ['nullable', 'string'],
            'app_version' => ['nullable', 'string'],
        ];
    }

    protected function prepareForValidation(): void
    {
        $this->merge([
            'token' => trim($this->string('token')->toString()),
            'device_id' => trim($this->string('device_id')->toString()),
        ]);
    }

    public function token(): string
    {
        return $this->requiredString('token');
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

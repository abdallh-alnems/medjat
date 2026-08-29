<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Http\ApiResponse;
use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\Exceptions\HttpResponseException;

/**
 * Base request for the whole API.
 *
 * Two jobs. It renders a validation failure in our envelope rather than
 * Laravel's, because the published apps parse `status` / `code` / `error_code`
 * and would treat the framework's default body as an unrecognised error. And it
 * exposes typed accessors, so a controller never handles a `mixed` from
 * $request->input() — which is the difference between a wrong type surfacing in
 * static analysis and surfacing in production.
 */
abstract class ApiRequest extends FormRequest
{
    /**
     * The old backend answered a missing field with 422 + 'missing_fields'
     * regardless of which field it was. Subclasses override when an endpoint
     * distinguishes further.
     */
    protected function validationErrorCode(): string
    {
        return 'missing_fields';
    }

    protected function validationMessage(): string
    {
        return 'حقل مطلوب';
    }

    /**
     * Not always 422. Some endpoints answered a missing field with 400 and the
     * apps branch on the status, so the code each one returns is part of its
     * contract rather than a detail to standardise away.
     */
    protected function validationStatus(): int
    {
        return 422;
    }

    public function authorize(): bool
    {
        return true;
    }

    protected function failedValidation(Validator $validator): never
    {
        throw new HttpResponseException(
            ApiResponse::fail(
                $this->validationMessage(),
                $this->validationStatus(),
                $this->validationErrorCode(),
                ['fields' => array_keys($validator->errors()->toArray())],
            )
        );
    }

    /**
     * Required string: validation has already guaranteed it is present.
     * Named requiredString rather than str() because Request::str() exists and
     * returns a Stringable.
     */
    protected function requiredString(string $key): string
    {
        return (string) $this->string($key);
    }

    protected function nullableStr(string $key): ?string
    {
        $value = $this->input($key);

        return is_scalar($value) && (string) $value !== '' ? (string) $value : null;
    }
}

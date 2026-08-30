<?php

declare(strict_types=1);

namespace App\Exceptions;

use App\Shared\Http\ApiResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

/**
 * A refusal raised from anywhere below the controller.
 *
 * The old backend called Response::fail(), which wrote the body and called
 * exit() — convenient at the point of failure but it made any code path
 * containing one impossible to unit test, because asserting on it meant
 * catching a process exit. Throwing gives the same "stop here" ergonomics and a
 * failure a test can assert on.
 */
final class ApiFailure extends RuntimeException
{
    /**
     * @param  array<string, mixed>|null  $meta
     */
    public function __construct(
        string $message,
        private readonly int $status = 400,
        private readonly ?string $errorCode = null,
        private readonly ?array $meta = null,
    ) {
        parent::__construct($message);
    }

    public function render(Request $request): JsonResponse
    {
        return ApiResponse::fail($this->getMessage(), $this->status, $this->errorCode, $this->meta);
    }

    public function status(): int
    {
        return $this->status;
    }

    public function errorCode(): ?string
    {
        return $this->errorCode;
    }
}

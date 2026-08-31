<?php

declare(strict_types=1);

namespace App\Modules\Documents\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Models\Employee;
use App\Support\Value;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Symfony\Component\HttpFoundation\Response;

/**
 * Port of api/app/employees/my_document_view.php.
 *
 * An employee reading back a file they handed in. Scoped to their own
 * documents — the id is a small integer, so without the ownership check this
 * would hand anybody the identity documents of everyone in the company by
 * counting.
 */
final class MyDocumentController
{
    /** Fallbacks when the stored mime is missing. */
    private const EXTENSION_TYPES = [
        'pdf' => 'application/pdf',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
    ];

    public function __invoke(Request $request): Response
    {
        $employee = $request->attributes->get('employee');
        if (! $employee instanceof Employee) {
            throw new ApiFailure(__('messages.authentication_required'), 401);
        }

        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $documentId = Value::int($request->query('id'));

        if ($documentId <= 0) {
            throw new ApiFailure('id is required', 422, 'missing_fields');
        }

        /** @var object{file_path: string|null, original_name: string|null, mime_type: string|null}|null $document */
        $document = DB::table('employee_documents')
            ->where('id', $documentId)
            ->where('tenant_id', $tenantId)
            ->where('employee_id', $employee->id)
            ->first(['file_path', 'original_name', 'mime_type']);

        $path = $document === null ? '' : Value::string($document->file_path);

        if ($path === '' || ! Storage::disk('uploads')->exists($path)) {
            throw new ApiFailure(__('messages.document_not_found'), 404);
        }

        $name = Value::string($document?->original_name) ?: basename($path);

        return response(Storage::disk('uploads')->get($path), 200, [
            'Content-Type' => $this->contentType($document, $path),
            'Content-Disposition' => 'inline; filename="'.addslashes($name).'"',
            'X-Content-Type-Options' => 'nosniff',
            // An identity document, not an asset: it must not sit in a shared
            // proxy or on a CDN edge.
            'Cache-Control' => 'private, no-store, max-age=0',
        ]);
    }

    /**
     * @param  object{mime_type: string|null}|null  $document
     */
    private function contentType(?object $document, string $path): string
    {
        $stored = Value::string($document?->mime_type);
        if ($stored !== '') {
            return $stored;
        }

        $extension = mb_strtolower(pathinfo($path, PATHINFO_EXTENSION));

        // Anything unrecognised is served as a download rather than guessed at,
        // so the browser never renders a file whose type we cannot vouch for.
        return self::EXTENSION_TYPES[$extension] ?? 'application/octet-stream';
    }
}

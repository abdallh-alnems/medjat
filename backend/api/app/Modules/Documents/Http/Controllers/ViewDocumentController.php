<?php

declare(strict_types=1);

namespace App\Modules\Documents\Http\Controllers;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Port of api/app/documents/view.php.
 *
 * A manager opening somebody's document. The employee's own copy of this lives
 * in MyDocumentController and is scoped to them; this one is scoped to the
 * company and gated on the documents permission.
 *
 * Streamed through PHP rather than served as a path, because the uploads
 * directory is not web-served — an identity document behind a guessable URL is
 * exactly what that arrangement exists to prevent.
 */
final class ViewDocumentController
{
    /**
     * Only the types the company actually accepts. Anything else is downloaded
     * rather than rendered, so the browser never interprets a file whose type
     * cannot be vouched for.
     */
    private const EXTENSION_TYPES = [
        'pdf' => 'application/pdf',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
    ];

    public function __invoke(Request $request): Response
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $documentId = Value::int($request->query('id'));

        if ($documentId <= 0) {
            throw new ApiFailure('id is required', 422, 'missing_fields');
        }

        $document = DB::table('employee_documents')
            ->where('id', $documentId)->where('tenant_id', $tenantId)
            ->first(['file_path', 'original_name', 'mime_type']);

        $path = $document === null ? '' : Value::string($document->file_path);

        if ($path === '' || ! Storage::disk('uploads')->exists($path)) {
            throw new ApiFailure('Document not found', 404);
        }

        $name = Value::string($document?->original_name) ?: basename($path);
        $stored = Value::string($document?->mime_type);
        $extension = mb_strtolower(pathinfo($path, PATHINFO_EXTENSION));

        return response(Value::string(Storage::disk('uploads')->get($path)), 200, [
            'Content-Type' => $stored !== '' ? $stored : (self::EXTENSION_TYPES[$extension] ?? 'application/octet-stream'),
            'Content-Disposition' => 'inline; filename="'.addslashes($name).'"',
            'X-Content-Type-Options' => 'nosniff',
            // An identity document, not an asset: it must not sit in a shared
            // proxy or on a CDN edge.
            'Cache-Control' => 'private, no-store, max-age=0',
        ]);
    }
}

<?php

declare(strict_types=1);

namespace App\Domain\Documents;

use App\Exceptions\ApiFailure;
use App\Support\Value;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Storing a file somebody handed in.
 *
 * Identity documents, contracts and certificates: the most sensitive files in
 * the system after payslips. They go to a disk nginx refuses outright and are
 * only ever served back through an endpoint that checks who is asking.
 *
 * The stored name is generated rather than taken from the upload — a filename
 * chosen by the person uploading is a path, and the original is kept as a label
 * for the interface rather than as a location.
 */
final class DocumentUpload
{
    /**
     * @return int The employee_documents row id.
     *
     * @throws ApiFailure
     */
    public static function store(
        UploadedFile $file,
        int $tenantId,
        int $employeeId,
        int $requiredDocumentId,
        ?int $uploadedBy,
    ): int {
        $extension = mb_strtolower($file->getClientOriginalExtension());

        /** @var list<string> $allowed */
        $allowed = Config::array('medjat.uploads.allowed_types');
        if (! in_array($extension, $allowed, true)) {
            throw new ApiFailure('File type not allowed', 400, 'file_type_not_allowed');
        }

        if ($file->getSize() > Config::integer('medjat.uploads.max_bytes')) {
            throw new ApiFailure('File size exceeds limit', 400, 'file_size_exceeds_limit');
        }

        $directory = 'documents/'.$tenantId;
        $name = bin2hex(random_bytes(16)).'_'.time().'.'.$extension;

        // putFileAs, not put: handed an UploadedFile, put() treats the first
        // argument as a *directory* and invents its own name, which would throw
        // away the one generated above. It also streams, so a large upload never
        // sits in memory whole.
        Storage::disk('uploads')->putFileAs($directory, $file, $name);

        $path = $directory.'/'.$name;

        // 'uploaded' with verified_at left null means "awaiting review". The
        // enum has no 'pending' value, and writing one would be stored as the
        // empty string rather than refused.
        return (int) DB::table('employee_documents')->insertGetId([
            'tenant_id' => $tenantId,
            'employee_id' => $employeeId,
            'required_document_id' => $requiredDocumentId,
            'file_path' => $path,
            // Kept as a label for the interface, never as a location.
            'original_name' => mb_substr(Value::string($file->getClientOriginalName()), 0, 255),
            'file_size' => $file->getSize(),
            'mime_type' => $file->getMimeType(),
            'status' => 'uploaded',
            'uploaded_by' => $uploadedBy,
        ]);
    }
}

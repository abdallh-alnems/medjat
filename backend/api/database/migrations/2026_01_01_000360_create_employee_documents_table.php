<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('employee_documents', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->integer('required_document_id')->unsigned()->nullable();
            $table->string('file_path', 500);
            $table->string('original_name', 255)->nullable();
            $table->integer('file_size')->unsigned()->nullable();
            $table->string('mime_type', 50)->nullable();
            $table->enum('status', ['uploaded', 'expired', 'required', 'rejected'])->default('uploaded');
            $table->date('expires_at')->nullable();
            $table->integer('uploaded_by')->unsigned()->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->text('notes')->nullable();
            $table->string('rejected_reason', 500)->nullable();
            $table->dateTime('verified_at')->nullable();
            $table->integer('verified_by')->unsigned()->nullable();
            $table->index(['expires_at'], 'idx_edoc_expires');
            $table->index(['tenant_id'], 'idx_edoc_tenant');
            $table->index(['required_document_id'], 'required_document_id');
            $table->unique(['employee_id', 'required_document_id'], 'uniq_emp_doc');
            $table->index(['uploaded_by'], 'uploaded_by');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('employee_documents');
    }
};

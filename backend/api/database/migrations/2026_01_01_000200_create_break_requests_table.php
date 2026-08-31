<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('break_requests', function (Blueprint $table): void {
            $table->increments('id');
            $table->integer('tenant_id')->unsigned();
            $table->integer('employee_id')->unsigned();
            $table->date('date')->comment('يوم العمل المطلوب فيه الإذن/البريك');
            $table->time('start_time');
            $table->time('end_time');
            $table->smallInteger('duration_minutes')->unsigned()->default(0)->comment('محسوبة في PHP وقت الإدراج');
            $table->string('type', 100)->default('')->comment('نوع/وصف الطلب يُدخله المستخدم بحرية');
            $table->boolean('deduct_from_salary')->default(0)->comment('هل يُخصم من الراتب بنظام الساعة؟ يُحدَّد عند الإنشاء أو الموافقة');
            $table->text('reason')->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected', 'postponed', 'cancelled'])->default('pending');
            $table->integer('decided_by')->unsigned()->nullable()->comment('admins.id الذي اتخذ القرار');
            $table->timestamp('decided_at')->nullable();
            $table->text('decision_note')->nullable()->comment('سبب الرفض / ملاحظة الموافقة أو التأجيل');
            $table->date('suggested_date')->nullable()->comment('وقت بديل مقترح عند التأجيل');
            $table->time('suggested_start_time')->nullable();
            $table->time('suggested_end_time')->nullable();
            $table->timestamp('created_at')->nullable()->useCurrent();
            $table->timestamp('updated_at')->nullable()->useCurrent()->useCurrentOnUpdate();
            $table->index(['decided_by'], 'decided_by');
            $table->index(['employee_id', 'date'], 'idx_break_emp_date');
            $table->index(['status'], 'idx_break_status');
            $table->index(['tenant_id'], 'idx_break_tenant');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('break_requests');
    }
};

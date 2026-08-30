<?php

declare(strict_types=1);

use App\Http\Controllers\Attendance\BranchAttendanceController;
use App\Http\Controllers\Attendance\BranchQrCodeController;
use App\Http\Controllers\Attendance\CheckInController;
use App\Http\Controllers\Attendance\CheckOutController;
use App\Http\Controllers\Attendance\CrewCheckInController;
use App\Http\Controllers\Attendance\CrewListController;
use App\Http\Controllers\Attendance\FaceChallengeController;
use App\Http\Controllers\Attendance\FaceLogsController;
use App\Http\Controllers\Attendance\ManualCheckInController;
use App\Http\Controllers\Attendance\MyAttendanceController;
use App\Http\Controllers\Attendance\PunchPhotoController;
use App\Http\Controllers\Attendance\SecurityLogController;
use App\Http\Controllers\Attendance\SetDayStatusController;
use App\Http\Controllers\Attendance\SetMethodOverrideController;
use App\Http\Controllers\Attendance\SyncOfflineController;
use App\Http\Controllers\Attendance\UpdateNoteController;
use App\Http\Controllers\Attendance\WebStatusController;
use App\Http\Controllers\Auth\AdminLoginController;
use App\Http\Controllers\Auth\AdminLogoutController;
use App\Http\Controllers\Auth\DeleteAccountController;
use App\Http\Controllers\Auth\DesktopAuthController;
use App\Http\Controllers\Auth\EmployeeActivateTokenController;
use App\Http\Controllers\Auth\EmployeeLoginController;
use App\Http\Controllers\Auth\EmployeeLogoutController;
use App\Http\Controllers\Auth\EmployeeWebActivateController;
use App\Http\Controllers\Auth\EmployeeWebLoginController;
use App\Http\Controllers\Auth\EmployeeWebLogoutController;
use App\Http\Controllers\Auth\NotificationPrefsController;
use App\Http\Controllers\Auth\SendAuthActionController;
use App\Http\Controllers\Auth\UpdateFcmTokenController;
use App\Http\Controllers\Auth\UpdateProfileController;
use App\Http\Controllers\Documents\DocumentReportsController;
use App\Http\Controllers\Documents\EmployeeDocumentsController;
use App\Http\Controllers\Documents\MyDocumentController;
use App\Http\Controllers\Documents\RequestDocumentController;
use App\Http\Controllers\Documents\RequiredDocumentController;
use App\Http\Controllers\Documents\ReviewDocumentController;
use App\Http\Controllers\Documents\UploadDocumentController;
use App\Http\Controllers\Documents\ViewDocumentController;
use App\Http\Controllers\Employees\ActivationCodeController;
use App\Http\Controllers\Employees\AttendanceHistoryController;
use App\Http\Controllers\Employees\CreateEmployeeController;
use App\Http\Controllers\Employees\DeleteEmployeeController;
use App\Http\Controllers\Employees\EmployeeProfileController;
use App\Http\Controllers\Employees\EmployeeStatusController;
use App\Http\Controllers\Employees\FinancialSummaryController;
use App\Http\Controllers\Employees\ListEmployeesController;
use App\Http\Controllers\Employees\ListTerminatedController;
use App\Http\Controllers\Employees\MyProfileController;
use App\Http\Controllers\Employees\SuspensionController;
use App\Http\Controllers\Employees\UpdateEmployeeController;
use App\Http\Controllers\Kiosk\IdentifyController;
use App\Http\Controllers\Kiosk\KioskAdminController;
use App\Http\Controllers\Kiosk\KioskFleetController;
use App\Http\Controllers\Kiosk\KioskSessionController;
use App\Http\Controllers\Kiosk\PairingController;
use App\Http\Controllers\Kiosk\PunchController;
use App\Http\Controllers\Leave\CarryoverController;
use App\Http\Controllers\Leave\LeaveAdminController;
use App\Http\Controllers\Leave\MyLeaveController;
use App\Http\Controllers\Payroll\ApproveController;
use App\Http\Controllers\Payroll\AuditLogController as PayrollAuditLogController;
use App\Http\Controllers\Payroll\BankFileController;
use App\Http\Controllers\Payroll\BulkAdjustController;
use App\Http\Controllers\Payroll\CalculateController;
use App\Http\Controllers\Payroll\DisburseController;
use App\Http\Controllers\Payroll\EosbController;
use App\Http\Controllers\Payroll\GenerateController;
use App\Http\Controllers\Payroll\ListSlipsController;
use App\Http\Controllers\Payroll\LiveController;
use App\Http\Controllers\Payroll\MarkPaidController;
use App\Http\Controllers\Payroll\MySlipController;
use App\Http\Controllers\Payroll\OverrideLineController;
use App\Http\Controllers\Payroll\PayslipPdfController;
use App\Http\Controllers\Payroll\RevertController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API routes
|--------------------------------------------------------------------------
|
| Two names for every endpoint, on purpose.
|
| `legacy` reproduces the old backend's URLs, .php suffix and all, because
| API_HOST is compiled into the Flutter bundles: every medjat_app and
| medjat_central install already in Google Play, the App Store and AppGallery
| asks for /app/auth/employee_logout.php and will keep asking for as long as it
| stays installed. These are permanent, not transitional.
|
| `v1` is the shape new clients get. As each module is ported the legacy name
| stops being served by the old PHP backend and starts being served here, which
| is what makes this a strangler migration rather than a rewrite: at no point is
| there a version of the system that does not work.
|
*/

Route::middleware('throttle:api')->group(function (): void {

    // ── Employee sessions ────────────────────────────────────────────────
    Route::post('v1/auth/employee/activate', EmployeeActivateTokenController::class)
        ->name('employee.activate');
    Route::post('v1/auth/employee/login', EmployeeLoginController::class)
        ->name('employee.login');
    Route::post('v1/auth/employee/logout', EmployeeLogoutController::class)
        ->name('employee.logout');

    Route::post('app/auth/employee_activate_token.php', EmployeeActivateTokenController::class)
        ->name('legacy.employee.activate');
    Route::post('app/auth/employee_login.php', EmployeeLoginController::class)
        ->name('legacy.employee.login');
    Route::post('app/auth/employee_logout.php', EmployeeLogoutController::class)
        ->name('legacy.employee.logout');

    // ── Browser sessions ─────────────────────────────────────────────────
    // A separate identity from the phone: signing in here must not sign the
    // employee out of their app, and vice versa.
    Route::post('v1/auth/employee/web/activate', EmployeeWebActivateController::class)
        ->name('employee.web.activate');
    Route::post('v1/auth/employee/web/login', EmployeeWebLoginController::class)
        ->name('employee.web.login');
    Route::post('v1/auth/employee/web/logout', EmployeeWebLogoutController::class)
        ->name('employee.web.logout');

    Route::post('app/auth/employee_web_activate.php', EmployeeWebActivateController::class)
        ->name('legacy.employee.web.activate');
    Route::post('app/auth/employee_web_login.php', EmployeeWebLoginController::class)
        ->name('legacy.employee.web.login');
    Route::post('app/auth/employee_web_logout.php', EmployeeWebLogoutController::class)
        ->name('legacy.employee.web.logout');

    // ── Administrator sessions ───────────────────────────────────────────
    // Sign-in verifies the Firebase token itself, so it sits outside the guard.
    Route::post('v1/auth/admin/login', AdminLoginController::class)->name('admin.login');
    Route::post('app/auth/login.php', AdminLoginController::class)->name('legacy.admin.login');

    Route::middleware('auth.admin')->group(function (): void {
        Route::post('v1/auth/admin/logout', AdminLogoutController::class)
            ->name('admin.logout');
        Route::post('app/auth/logout.php', AdminLogoutController::class)
            ->name('legacy.admin.logout');
    });

    // ── Desktop shell sign-in ────────────────────────────────────────────
    // The exchange is unauthenticated on purpose: the code IS the credential.
    Route::post('v1/auth/desktop/exchange', [DesktopAuthController::class, 'exchange'])
        ->name('desktop.exchange');
    Route::post('app/auth/desktop_exchange.php', [DesktopAuthController::class, 'exchange'])
        ->name('legacy.desktop.exchange');

    Route::middleware('auth.admin')->group(function (): void {
        Route::post('v1/auth/desktop/authorize', [DesktopAuthController::class, 'authorize'])
            ->name('desktop.authorize');
        Route::post('app/auth/desktop_authorize.php', [DesktopAuthController::class, 'authorize'])
            ->name('legacy.desktop.authorize');

        Route::post('v1/auth/account', DeleteAccountController::class)->name('account.delete');
        Route::post('app/auth/delete_account.php', DeleteAccountController::class)
            ->name('legacy.account.delete');
    });

    // ── Transactional auth email ─────────────────────────────────────────
    // Unauthenticated, and both always answer success: saying whether an
    // address is registered would make either one an enumeration oracle.
    Route::post('v1/auth/password-reset', [SendAuthActionController::class, 'passwordReset'])
        ->name('password-reset.send');
    Route::post('v1/auth/verification', [SendAuthActionController::class, 'verification'])
        ->name('verification.send');

    Route::post('app/auth/send_password_reset.php', [SendAuthActionController::class, 'passwordReset'])
        ->name('legacy.password-reset.send');
    Route::post('app/auth/send_verification.php', [SendAuthActionController::class, 'verification'])
        ->name('legacy.verification.send');

    // ── Account settings ─────────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/auth/profile', UpdateProfileController::class)->name('profile.update');
        Route::post('app/auth/update_profile.php', UpdateProfileController::class)
            ->name('legacy.profile.update');
    });

    Route::middleware('auth.employee')->group(function (): void {
        Route::get('v1/auth/notification-prefs', [NotificationPrefsController::class, 'show'])
            ->name('notification-prefs.show');
        Route::post('v1/auth/notification-prefs', [NotificationPrefsController::class, 'update'])
            ->name('notification-prefs.update');

        // One legacy URL, two methods — the old file branched on the request
        // method inside itself.
        Route::get('app/auth/notification_prefs.php', [NotificationPrefsController::class, 'show'])
            ->name('legacy.notification-prefs.show');
        Route::post('app/auth/notification_prefs.php', [NotificationPrefsController::class, 'update'])
            ->name('legacy.notification-prefs.update');
    });

    // Called by both apps, so the principal follows whichever credential arrived.
    Route::middleware('auth.either')->group(function (): void {
        Route::post('v1/auth/fcm-token', UpdateFcmTokenController::class)->name('fcm-token.update');
        Route::post('app/auth/update_fcm_token.php', UpdateFcmTokenController::class)
            ->name('legacy.fcm-token.update');
    });

    // ── Attendance ───────────────────────────────────────────────────────
    // Both channels reach the same action; which one is in play comes from the
    // session, never from the request.
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/attendance/check-in', CheckInController::class)->name('attendance.check-in');
        Route::post('v1/attendance/check-out', CheckOutController::class)->name('attendance.check-out');

        Route::post('app/attendance/check_in.php', CheckInController::class)
            ->name('legacy.attendance.check-in');
        Route::post('app/attendance/check_out.php', CheckOutController::class)
            ->name('legacy.attendance.check-out');

        Route::post('v1/attendance/face-challenge', FaceChallengeController::class)
            ->name('attendance.face-challenge');
        Route::post('v1/attendance/crew', CrewListController::class)->name('attendance.crew');
        Route::post('v1/attendance/security-log', SecurityLogController::class)
            ->name('attendance.security-log');

        Route::post('app/attendance/face_challenge.php', FaceChallengeController::class)
            ->name('legacy.attendance.face-challenge');
        Route::post('app/attendance/crew_list.php', CrewListController::class)
            ->name('legacy.attendance.crew');

        Route::post('v1/attendance/crew/punch', CrewCheckInController::class)
            ->name('attendance.crew.punch');
        Route::post('app/attendance/crew_check_in.php', CrewCheckInController::class)
            ->name('legacy.attendance.crew.punch');

        Route::post('v1/attendance/sync-offline', SyncOfflineController::class)
            ->name('attendance.sync-offline');
        Route::post('app/attendance/sync_offline.php', SyncOfflineController::class)
            ->name('legacy.attendance.sync-offline');
        Route::post('app/attendance/security_log.php', SecurityLogController::class)
            ->name('legacy.attendance.security-log');

        Route::get('v1/attendance/mine', MyAttendanceController::class)->name('attendance.mine');
        Route::get('app/attendance/get_my_attendance.php', MyAttendanceController::class)
            ->name('legacy.attendance.mine');

        Route::post('v1/attendance/web-status', WebStatusController::class)
            ->name('attendance.web-status');
        Route::post('app/attendance/web_status.php', WebStatusController::class)
            ->name('legacy.attendance.web-status');
    });

    // Management side: recorded for an employee rather than by them.
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/attendance/method-override', SetMethodOverrideController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('attendance.method-override');
        Route::post('app/attendance/set_method_override.php', SetMethodOverrideController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('legacy.attendance.method-override');

        Route::post('v1/attendance/branch-qr', BranchQrCodeController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('attendance.branch-qr');
        Route::post('app/attendance/branch_qr_code.php', BranchQrCodeController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('legacy.attendance.branch-qr');

        Route::middleware('can.do:manage_attendance')->group(function (): void {
            Route::get('v1/attendance/branch', BranchAttendanceController::class)
                ->name('attendance.branch');
            Route::get('v1/attendance/photo', PunchPhotoController::class)
                ->name('attendance.photo');
            Route::post('v1/attendance/face-logs', FaceLogsController::class)
                ->name('attendance.face-logs');

            Route::get('app/attendance/get_branch_attendance.php', BranchAttendanceController::class)
                ->name('legacy.attendance.branch');
            Route::get('app/attendance/punch_photo.php', PunchPhotoController::class)
                ->name('legacy.attendance.photo');
            Route::post('app/attendance/face_logs.php', FaceLogsController::class)
                ->name('legacy.attendance.face-logs');

            Route::post('v1/attendance/day-status', SetDayStatusController::class)
                ->name('attendance.day-status');
            Route::post('app/attendance/set_day_status.php', SetDayStatusController::class)
                ->name('legacy.attendance.day-status');

            Route::post('v1/attendance/manual', ManualCheckInController::class)
                ->name('attendance.manual');
            Route::post('v1/attendance/note', UpdateNoteController::class)->name('attendance.note');

            Route::post('app/attendance/manual_check_in.php', ManualCheckInController::class)
                ->name('legacy.attendance.manual');
            Route::post('app/attendance/update_note.php', UpdateNoteController::class)
                ->name('legacy.attendance.note');
        });
    });

    // ── Employees ────────────────────────────────────────────────────────
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::get('v1/employees/me', MyProfileController::class)->name('employees.me');
        Route::get('app/employees/my_profile.php', MyProfileController::class)
            ->name('legacy.employees.me');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_employees'])->group(function (): void {
        Route::get('v1/employees', ListEmployeesController::class)->name('employees.list');
        Route::get('v1/employees/terminated', ListTerminatedController::class)
            ->name('employees.terminated');
        Route::post('v1/employees/delete', DeleteEmployeeController::class)->name('employees.delete');

        Route::get('app/employees/list.php', ListEmployeesController::class)
            ->name('legacy.employees.list');
        Route::get('app/employees/list_terminated.php', ListTerminatedController::class)
            ->name('legacy.employees.terminated');
        Route::post('app/employees/delete.php', DeleteEmployeeController::class)
            ->name('legacy.employees.delete');

        Route::post('v1/employees', CreateEmployeeController::class)->name('employees.create');
        Route::post('v1/employees/update', UpdateEmployeeController::class)->name('employees.update');

        Route::post('app/employees/create.php', CreateEmployeeController::class)
            ->name('legacy.employees.create');
        Route::post('app/employees/update.php', UpdateEmployeeController::class)
            ->name('legacy.employees.update');

        Route::get('v1/employees/suspensions', [SuspensionController::class, 'index'])
            ->name('employees.suspensions');
        Route::post('v1/employees/suspend', [SuspensionController::class, 'open'])
            ->name('employees.suspend');
        Route::post('v1/employees/end-suspension', [SuspensionController::class, 'close'])
            ->name('employees.end-suspension');
        Route::post('v1/employees/reactivate', [EmployeeStatusController::class, 'reactivate'])
            ->name('employees.reactivate');
        Route::post('v1/employees/crew-supervisor', [EmployeeStatusController::class, 'setCrewSupervisor'])
            ->name('employees.crew-supervisor');
        Route::post('v1/employees/reset-web-pin', [EmployeeStatusController::class, 'resetWebPin'])
            ->name('employees.reset-web-pin');

        Route::get('app/employees/get_suspensions.php', [SuspensionController::class, 'index'])
            ->name('legacy.employees.suspensions');
        Route::post('app/employees/suspend.php', [SuspensionController::class, 'open'])
            ->name('legacy.employees.suspend');
        Route::post('app/employees/end_suspension.php', [SuspensionController::class, 'close'])
            ->name('legacy.employees.end-suspension');
        Route::post('app/employees/reactivate.php', [EmployeeStatusController::class, 'reactivate'])
            ->name('legacy.employees.reactivate');
        Route::post('app/employees/set_crew_supervisor.php', [EmployeeStatusController::class, 'setCrewSupervisor'])
            ->name('legacy.employees.crew-supervisor');
        Route::post('app/employees/reset_web_pin.php', [EmployeeStatusController::class, 'resetWebPin'])
            ->name('legacy.employees.reset-web-pin');

        Route::get('v1/employees/activation-code', [ActivationCodeController::class, 'show'])
            ->name('employees.activation-code');
        Route::post('v1/employees/activation-code', [ActivationCodeController::class, 'regenerate'])
            ->name('employees.activation-code.regenerate');

        Route::get('app/employees/activation_code.php', [ActivationCodeController::class, 'show'])
            ->name('legacy.employees.activation-code');
        Route::post('app/employees/activation_code.php', [ActivationCodeController::class, 'regenerate'])
            ->name('legacy.employees.activation-code.regenerate');
    });

    // ── Employee documents ───────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::middleware('can.do:manage_documents')->group(function (): void {
            Route::get('v1/employees/documents', [EmployeeDocumentsController::class, 'index'])
                ->name('documents.index');
            Route::get('v1/employees/documents/missing', [EmployeeDocumentsController::class, 'missing'])
                ->name('documents.missing');
            Route::post('v1/employees/documents/update', [ReviewDocumentController::class, 'update'])
                ->name('documents.update');
            Route::post('v1/employees/documents/delete', [ReviewDocumentController::class, 'destroy'])
                ->name('documents.delete');

            Route::get('app/employees/get_documents.php', [EmployeeDocumentsController::class, 'index'])
                ->name('legacy.documents.index');
            Route::get('app/employees/get_missing_documents.php', [EmployeeDocumentsController::class, 'missing'])
                ->name('legacy.documents.missing');
            Route::post('app/employees/update_document.php', [ReviewDocumentController::class, 'update'])
                ->name('legacy.documents.update');
            Route::post('app/employees/delete_document.php', [ReviewDocumentController::class, 'destroy'])
                ->name('legacy.documents.delete');
        });

        // Verifying is its own permission: deciding whether a passport is
        // genuine is a different job from filing it.
        Route::middleware('can.do:documents_verify')->group(function (): void {
            Route::post('v1/employees/documents/verify', [ReviewDocumentController::class, 'verify'])
                ->name('documents.verify');
            Route::post('v1/employees/documents/reject', [ReviewDocumentController::class, 'reject'])
                ->name('documents.reject');

            Route::post('app/employees/verify_document.php', [ReviewDocumentController::class, 'verify'])
                ->name('legacy.documents.verify');
            Route::post('app/employees/reject_document.php', [ReviewDocumentController::class, 'reject'])
                ->name('legacy.documents.reject');
        });
    });

    // ── Employee profile ─────────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/employees/profile', [EmployeeProfileController::class, 'show'])
            ->name('employees.profile');
        Route::get('app/employees/get_profile.php', [EmployeeProfileController::class, 'show'])
            ->name('legacy.employees.profile');

        Route::get('v1/employees/expiring-compliance', [EmployeeProfileController::class, 'expiringCompliance'])
            ->middleware('can.do:manage_employees')
            ->name('employees.expiring-compliance');
        Route::get('app/employees/expiring_compliance.php', [EmployeeProfileController::class, 'expiringCompliance'])
            ->middleware('can.do:manage_employees')
            ->name('legacy.employees.expiring-compliance');

        Route::get('v1/employees/year-to-date', [EmployeeProfileController::class, 'yearToDate'])
            ->middleware('can.do:manage_payroll')
            ->name('employees.year-to-date');
        Route::get('app/employees/get_year_to_date.php', [EmployeeProfileController::class, 'yearToDate'])
            ->middleware('can.do:manage_payroll')
            ->name('legacy.employees.year-to-date');
    });

    // ── Handing documents in ─────────────────────────────────────────────
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/employees/documents/submit', [UploadDocumentController::class, 'byEmployee'])
            ->name('documents.submit');
        Route::get('v1/employees/documents/mine', MyDocumentController::class)
            ->name('documents.mine');

        Route::post('app/employees/submit_document.php', [UploadDocumentController::class, 'byEmployee'])
            ->name('legacy.documents.submit');
        Route::get('app/employees/my_document_view.php', MyDocumentController::class)
            ->name('legacy.documents.mine');
    });

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/employees/documents/upload', [UploadDocumentController::class, 'byAdmin'])
            ->middleware('can.do:manage_documents')
            ->name('documents.upload');
        Route::post('app/employees/upload_document.php', [UploadDocumentController::class, 'byAdmin'])
            ->middleware('can.do:manage_documents')
            ->name('legacy.documents.upload');

        Route::post('v1/employees/documents/request', RequestDocumentController::class)
            ->middleware('can.do:manage_documents')
            ->name('documents.request');
        Route::post('app/employees/request_document.php', RequestDocumentController::class)
            ->middleware('can.do:manage_documents')
            ->name('legacy.documents.request');

        Route::get('v1/employees/attendance-history', AttendanceHistoryController::class)
            ->middleware('can.do:manage_attendance')
            ->name('employees.attendance-history');
        Route::get('app/employees/get_attendance_history.php', AttendanceHistoryController::class)
            ->middleware('can.do:manage_attendance')
            ->name('legacy.employees.attendance-history');
    });

    /*
    |--------------------------------------------------------------------------
    | Payroll
    |--------------------------------------------------------------------------
    |
    | Everything here except the employee's own payslip needs manage_payroll.
    | The gate is on the route rather than inside the controllers so the
    | permission a client must hold is visible in one place — the mismatch
    | between a visible menu item and the permission behind it is what turns a
    | 403 into "an error occurred" on somebody's screen.
    |
    */

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::get('v1/payroll/me', MySlipController::class)->name('payroll.me');
        Route::get('app/payroll/get_slip.php', MySlipController::class)->name('legacy.payroll.me');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_payroll'])->group(function (): void {
        Route::get('v1/payroll/live', LiveController::class)->name('payroll.live');
        Route::get('v1/employees/financial-summary', FinancialSummaryController::class)
            ->name('employees.financial-summary');
        Route::get('v1/payroll/calculate', CalculateController::class)->name('payroll.calculate');
        Route::get('v1/payroll/slips', ListSlipsController::class)->name('payroll.slips');
        Route::get('v1/payroll/audit-log', PayrollAuditLogController::class)->name('payroll.audit-log');
        Route::get('v1/payroll/eosb', EosbController::class)->name('payroll.eosb');
        Route::get('v1/payroll/payslip.pdf', PayslipPdfController::class)->name('payroll.payslip-pdf');
        Route::get('v1/payroll/bank-file/preview', [BankFileController::class, 'preview'])
            ->name('payroll.bank-file.preview');
        Route::get('v1/payroll/bank-file', [BankFileController::class, 'download'])
            ->name('payroll.bank-file');

        Route::post('v1/payroll/generate', GenerateController::class)->name('payroll.generate');
        Route::post('v1/payroll/approve', [ApproveController::class, 'one'])->name('payroll.approve');
        Route::post('v1/payroll/approve-bulk', [ApproveController::class, 'bulk'])->name('payroll.approve-bulk');
        Route::post('v1/payroll/mark-paid', MarkPaidController::class)->name('payroll.mark-paid');
        Route::post('v1/payroll/revert', RevertController::class)->name('payroll.revert');
        Route::post('v1/payroll/disburse', [DisburseController::class, 'one'])->name('payroll.disburse');
        Route::post('v1/payroll/disburse-all', [DisburseController::class, 'all'])->name('payroll.disburse-all');
        Route::post('v1/payroll/override-line', OverrideLineController::class)->name('payroll.override-line');
        Route::post('v1/payroll/bulk-adjust', BulkAdjustController::class)->name('payroll.bulk-adjust');

        Route::get('app/payroll/live.php', LiveController::class)->name('legacy.payroll.live');
        Route::get('app/employees/get_financial_summary.php', FinancialSummaryController::class)
            ->name('legacy.employees.financial-summary');
        Route::get('app/payroll/calculate.php', CalculateController::class)->name('legacy.payroll.calculate');
        Route::get('app/payroll/list_slips.php', ListSlipsController::class)->name('legacy.payroll.slips');
        Route::get('app/payroll/audit_log.php', PayrollAuditLogController::class)->name('legacy.payroll.audit-log');
        Route::get('app/payroll/eosb_calculate.php', EosbController::class)->name('legacy.payroll.eosb');
        Route::get('app/payroll/get_slip_pdf.php', PayslipPdfController::class)->name('legacy.payroll.payslip-pdf');
        Route::get('app/payroll/bank_file_preview.php', [BankFileController::class, 'preview'])
            ->name('legacy.payroll.bank-file.preview');
        Route::get('app/payroll/export_bank_file.php', [BankFileController::class, 'download'])
            ->name('legacy.payroll.bank-file');

        Route::post('app/payroll/generate.php', GenerateController::class)->name('legacy.payroll.generate');
        Route::post('app/payroll/approve.php', [ApproveController::class, 'one'])->name('legacy.payroll.approve');
        Route::post('app/payroll/approve_bulk.php', [ApproveController::class, 'bulk'])
            ->name('legacy.payroll.approve-bulk');
        Route::post('app/payroll/mark_paid.php', MarkPaidController::class)->name('legacy.payroll.mark-paid');
        Route::post('app/payroll/revert.php', RevertController::class)->name('legacy.payroll.revert');
        Route::post('app/payroll/disburse.php', [DisburseController::class, 'one'])->name('legacy.payroll.disburse');
        Route::post('app/payroll/disburse_all.php', [DisburseController::class, 'all'])
            ->name('legacy.payroll.disburse-all');
        Route::post('app/payroll/override_line.php', OverrideLineController::class)
            ->name('legacy.payroll.override-line');
        Route::post('app/payroll/bulk_adjust.php', BulkAdjustController::class)->name('legacy.payroll.bulk-adjust');
    });

    /*
    |--------------------------------------------------------------------------
    | Leave
    |--------------------------------------------------------------------------
    |
    | An employee's own requests need no permission beyond being signed in —
    | they are scoped to the token holder. Everything on the management side
    | needs manage_leaves, except the two endpoints whose gate depends on the
    | request itself and check inside the controller.
    |
    */

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/leaves/apply', [MyLeaveController::class, 'apply'])->name('leaves.apply');
        Route::get('v1/leaves/mine', [MyLeaveController::class, 'index'])->name('leaves.mine');
        Route::get('v1/leaves/my-balance', [MyLeaveController::class, 'balance'])->name('leaves.my-balance');
        Route::post('v1/leaves/cancel', [MyLeaveController::class, 'cancel'])->name('leaves.cancel');
        Route::post('v1/leaves/update', [MyLeaveController::class, 'update'])->name('leaves.update');

        Route::post('app/leaves/apply.php', [MyLeaveController::class, 'apply'])->name('legacy.leaves.apply');
        Route::get('app/leaves/my_leaves.php', [MyLeaveController::class, 'index'])->name('legacy.leaves.mine');
        Route::get('app/leaves/my_balance.php', [MyLeaveController::class, 'balance'])
            ->name('legacy.leaves.my-balance');
        Route::post('app/leaves/cancel.php', [MyLeaveController::class, 'cancel'])->name('legacy.leaves.cancel');
        Route::post('app/leaves/update.php', [MyLeaveController::class, 'update'])->name('legacy.leaves.update');
    });

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        // The gate depends on whose balance is asked for, so it is checked in
        // the controller rather than on the route.
        Route::get('v1/leaves/balance', [LeaveAdminController::class, 'balance'])->name('leaves.balance');
        Route::get('app/leaves/get_balance.php', [LeaveAdminController::class, 'balance'])
            ->name('legacy.leaves.balance');

        // Needs both manage_leaves and manage_attendance: it cancels leave and
        // writes attendance.
        Route::post('v1/leaves/convert-to-absence', [LeaveAdminController::class, 'convertToAbsence'])
            ->name('leaves.convert-to-absence');
        Route::post('app/leaves/convert_to_absence.php', [LeaveAdminController::class, 'convertToAbsence'])
            ->name('legacy.leaves.convert-to-absence');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_leaves'])->group(function (): void {
        Route::get('v1/leaves', [LeaveAdminController::class, 'index'])->name('leaves.list');
        Route::post('v1/leaves', [LeaveAdminController::class, 'create'])->name('leaves.create');
        Route::post('v1/leaves/approve', [LeaveAdminController::class, 'approve'])->name('leaves.approve');
        Route::post('v1/leaves/reject', [LeaveAdminController::class, 'reject'])->name('leaves.reject');
        Route::post('v1/leaves/recurring', [LeaveAdminController::class, 'createRecurring'])
            ->name('leaves.recurring');

        Route::get('v1/leaves/carryover-policies', [CarryoverController::class, 'index'])
            ->name('leaves.carryover-policies');
        Route::post('v1/leaves/carryover-policies', [CarryoverController::class, 'save'])
            ->name('leaves.carryover-policy-save');
        Route::post('v1/leaves/carryover-policies/delete', [CarryoverController::class, 'delete'])
            ->name('leaves.carryover-policy-delete');
        Route::post('v1/leaves/rollover', [CarryoverController::class, 'rollover'])->name('leaves.rollover');
        Route::get('v1/leaves/encashments', [CarryoverController::class, 'encashments'])
            ->name('leaves.encashments');

        Route::get('app/leaves/list.php', [LeaveAdminController::class, 'index'])->name('legacy.leaves.list');
        Route::post('app/leaves/create.php', [LeaveAdminController::class, 'create'])->name('legacy.leaves.create');
        Route::post('app/leaves/approve.php', [LeaveAdminController::class, 'approve'])
            ->name('legacy.leaves.approve');
        Route::post('app/leaves/reject.php', [LeaveAdminController::class, 'reject'])->name('legacy.leaves.reject');
        Route::post('app/leaves/create_recurring.php', [LeaveAdminController::class, 'createRecurring'])
            ->name('legacy.leaves.recurring');

        Route::get('app/leaves/carryover_policies_list.php', [CarryoverController::class, 'index'])
            ->name('legacy.leaves.carryover-policies');
        Route::post('app/leaves/carryover_policy_save.php', [CarryoverController::class, 'save'])
            ->name('legacy.leaves.carryover-policy-save');
        Route::post('app/leaves/carryover_policy_delete.php', [CarryoverController::class, 'delete'])
            ->name('legacy.leaves.carryover-policy-delete');
        Route::post('app/leaves/rollover.php', [CarryoverController::class, 'rollover'])
            ->name('legacy.leaves.rollover');
        Route::get('app/leaves/encashments_list.php', [CarryoverController::class, 'encashments'])
            ->name('legacy.leaves.encashments');
    });

    /*
    |--------------------------------------------------------------------------
    | Branch kiosk
    |--------------------------------------------------------------------------
    |
    | Three groups, because a kiosk is a third authentication principal. The
    | management app configures the fleet as a person; the tablet itself
    | authenticates as a branch; and pairing is the one door that is not behind
    | a token at all, because the pairing code IS the credential there.
    |
    */

    // The only kiosk endpoint that accepts an unauthenticated request.
    Route::post('v1/kiosk/pair', [PairingController::class, 'pair'])->name('kiosk.pair');
    Route::post('app/kiosk/pair.php', [PairingController::class, 'pair'])->name('legacy.kiosk.pair');

    Route::middleware('auth.kiosk')->group(function (): void {
        Route::post('v1/kiosk/heartbeat', [KioskSessionController::class, 'heartbeat'])->name('kiosk.heartbeat');
        Route::post('v1/kiosk/challenge', [KioskSessionController::class, 'challenge'])->name('kiosk.challenge');
        Route::post('v1/kiosk/identify', [IdentifyController::class, 'byFace'])->name('kiosk.identify');
        Route::post('v1/kiosk/identify-by-code', [IdentifyController::class, 'byCode'])
            ->name('kiosk.identify-by-code');
        Route::post('v1/kiosk/punch', PunchController::class)->name('kiosk.punch');
        Route::post('v1/kiosk/open-admin', [PairingController::class, 'openAdmin'])->name('kiosk.open-admin');
        Route::post('v1/kiosk/admin/roster', [KioskAdminController::class, 'roster'])->name('kiosk.admin.roster');
        Route::post('v1/kiosk/admin/enroll', [KioskAdminController::class, 'enroll'])->name('kiosk.admin.enroll');
        Route::post('v1/kiosk/admin/close', [KioskAdminController::class, 'close'])->name('kiosk.admin.close');

        Route::post('app/kiosk/heartbeat.php', [KioskSessionController::class, 'heartbeat'])
            ->name('legacy.kiosk.heartbeat');
        Route::post('app/kiosk/challenge.php', [KioskSessionController::class, 'challenge'])
            ->name('legacy.kiosk.challenge');
        Route::post('app/kiosk/identify.php', [IdentifyController::class, 'byFace'])->name('legacy.kiosk.identify');
        Route::post('app/kiosk/identify_by_code.php', [IdentifyController::class, 'byCode'])
            ->name('legacy.kiosk.identify-by-code');
        Route::post('app/kiosk/punch.php', PunchController::class)->name('legacy.kiosk.punch');
        Route::post('app/kiosk/open_admin.php', [PairingController::class, 'openAdmin'])
            ->name('legacy.kiosk.open-admin');
        Route::post('app/kiosk/admin/roster.php', [KioskAdminController::class, 'roster'])
            ->name('legacy.kiosk.admin.roster');
        Route::post('app/kiosk/admin/enroll.php', [KioskAdminController::class, 'enroll'])
            ->name('legacy.kiosk.admin.enroll');
        Route::post('app/kiosk/admin/close.php', [KioskAdminController::class, 'close'])
            ->name('legacy.kiosk.admin.close');
    });

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        // Pairing and unpairing hardware, versus issuing an access code to
        // enrol faces: deliberately different permissions, because somebody who
        // can enrol should not thereby be able to unpair the fleet.
        Route::post('v1/kiosk/stations', [KioskFleetController::class, 'index'])
            ->middleware('can.do:kiosk_devices')->name('kiosk.stations');
        Route::post('v1/kiosk/pairing-code', [PairingController::class, 'createPairingCode'])
            ->middleware('can.do:kiosk_devices')->name('kiosk.pairing-code');
        Route::post('v1/kiosk/revoke', [PairingController::class, 'revoke'])
            ->middleware('can.do:kiosk_devices')->name('kiosk.revoke');
        Route::post('v1/kiosk/access-code', [PairingController::class, 'createAccessCode'])
            ->middleware('can.do:kiosk_access')->name('kiosk.access-code');
        Route::post('v1/kiosk/set-pin', [KioskFleetController::class, 'setPin'])
            ->middleware('can.do:manage_employees')->name('kiosk.set-pin');
        Route::post('v1/kiosk/recognition-logs', [KioskFleetController::class, 'recognitionLogs'])
            ->middleware('can.do:manage_attendance')->name('kiosk.recognition-logs');
        Route::post('v1/kiosk/capture', [KioskFleetController::class, 'capture'])
            ->middleware('can.do:kiosk_evidence')->name('kiosk.capture');

        Route::post('app/kiosk/list.php', [KioskFleetController::class, 'index'])
            ->middleware('can.do:kiosk_devices')->name('legacy.kiosk.stations');
        Route::post('app/kiosk/create_pairing_code.php', [PairingController::class, 'createPairingCode'])
            ->middleware('can.do:kiosk_devices')->name('legacy.kiosk.pairing-code');
        Route::post('app/kiosk/revoke.php', [PairingController::class, 'revoke'])
            ->middleware('can.do:kiosk_devices')->name('legacy.kiosk.revoke');
        Route::post('app/kiosk/create_access_code.php', [PairingController::class, 'createAccessCode'])
            ->middleware('can.do:kiosk_access')->name('legacy.kiosk.access-code');
        Route::post('app/kiosk/set_pin.php', [KioskFleetController::class, 'setPin'])
            ->middleware('can.do:manage_employees')->name('legacy.kiosk.set-pin');
        Route::post('app/kiosk/recognition_logs.php', [KioskFleetController::class, 'recognitionLogs'])
            ->middleware('can.do:manage_attendance')->name('legacy.kiosk.recognition-logs');
        Route::post('app/kiosk/capture.php', [KioskFleetController::class, 'capture'])
            ->middleware('can.do:kiosk_evidence')->name('legacy.kiosk.capture');
    });

    /*
    |--------------------------------------------------------------------------
    | Document catalogue and compliance
    |--------------------------------------------------------------------------
    |
    | Three permissions, because these are three different jobs: changing what
    | the company asks for, reading somebody's file, and reading the compliance
    | numbers. manage_documents implies all three for anybody who held it
    | before they were split apart.
    |
    */

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/documents/required', [RequiredDocumentController::class, 'index'])
            ->middleware('can.do:manage_documents')->name('documents.required');
        Route::get('v1/documents/required/submissions', [RequiredDocumentController::class, 'submissions'])
            ->middleware('can.do:manage_documents')->name('documents.required.submissions');
        Route::get('v1/documents/view', ViewDocumentController::class)
            ->middleware('can.do:manage_documents')->name('documents.view');

        Route::post('v1/documents/required', [RequiredDocumentController::class, 'create'])
            ->middleware('can.do:documents_manage_types')->name('documents.required.create');
        Route::post('v1/documents/required/update', [RequiredDocumentController::class, 'update'])
            ->middleware('can.do:documents_manage_types')->name('documents.required.update');
        Route::post('v1/documents/required/delete', [RequiredDocumentController::class, 'delete'])
            ->middleware('can.do:documents_manage_types')->name('documents.required.delete');
        Route::post('v1/documents/required/toggle', [RequiredDocumentController::class, 'toggle'])
            ->middleware('can.do:documents_manage_types')->name('documents.required.toggle');
        Route::post('v1/documents/mark-expired', [DocumentReportsController::class, 'markExpired'])
            ->middleware('can.do:documents_manage_types')->name('documents.mark-expired');

        Route::get('v1/documents/reports/missing', [DocumentReportsController::class, 'missing'])
            ->middleware('can.do:documents_view_reports')->name('documents.reports.missing');
        Route::get('v1/documents/reports/expiring-soon', [DocumentReportsController::class, 'expiringSoon'])
            ->middleware('can.do:documents_view_reports')->name('documents.reports.expiring-soon');
        Route::get('v1/documents/reports/expired', [DocumentReportsController::class, 'expired'])
            ->middleware('can.do:documents_view_reports')->name('documents.reports.expired');
        Route::get('v1/documents/reports/stats', [DocumentReportsController::class, 'stats'])
            ->middleware('can.do:documents_view_reports')->name('documents.reports.stats');

        Route::get('app/documents/get_required.php', [RequiredDocumentController::class, 'index'])
            ->middleware('can.do:manage_documents')->name('legacy.documents.required');
        Route::get('app/documents/get_required_submissions.php', [RequiredDocumentController::class, 'submissions'])
            ->middleware('can.do:manage_documents')->name('legacy.documents.required.submissions');
        Route::get('app/documents/view.php', ViewDocumentController::class)
            ->middleware('can.do:manage_documents')->name('legacy.documents.view');

        Route::post('app/documents/create_required.php', [RequiredDocumentController::class, 'create'])
            ->middleware('can.do:documents_manage_types')->name('legacy.documents.required.create');
        Route::post('app/documents/update_required.php', [RequiredDocumentController::class, 'update'])
            ->middleware('can.do:documents_manage_types')->name('legacy.documents.required.update');
        Route::post('app/documents/delete_required.php', [RequiredDocumentController::class, 'delete'])
            ->middleware('can.do:documents_manage_types')->name('legacy.documents.required.delete');
        Route::post('app/documents/toggle_required.php', [RequiredDocumentController::class, 'toggle'])
            ->middleware('can.do:documents_manage_types')->name('legacy.documents.required.toggle');
        Route::post('app/documents/mark_expired.php', [DocumentReportsController::class, 'markExpired'])
            ->middleware('can.do:documents_manage_types')->name('legacy.documents.mark-expired');

        Route::get('app/documents/reports_missing.php', [DocumentReportsController::class, 'missing'])
            ->middleware('can.do:documents_view_reports')->name('legacy.documents.reports.missing');
        Route::get('app/documents/reports_expiring_soon.php', [DocumentReportsController::class, 'expiringSoon'])
            ->middleware('can.do:documents_view_reports')->name('legacy.documents.reports.expiring-soon');
        Route::get('app/documents/reports_expired.php', [DocumentReportsController::class, 'expired'])
            ->middleware('can.do:documents_view_reports')->name('legacy.documents.reports.expired');
        Route::get('app/documents/reports_stats.php', [DocumentReportsController::class, 'stats'])
            ->middleware('can.do:documents_view_reports')->name('legacy.documents.reports.stats');
    });

});

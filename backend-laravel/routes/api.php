<?php

declare(strict_types=1);

use App\Http\Controllers\Assets\AssetController;
use App\Http\Controllers\Assets\MyAssetsController;
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
use App\Http\Controllers\Audit\AuditFeedController;
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
use App\Http\Controllers\Biometric\EnrollmentController;
use App\Http\Controllers\Biometric\SelfEnrollmentController;
use App\Http\Controllers\Branches\BranchController;
use App\Http\Controllers\Branches\BranchNetworkController;
use App\Http\Controllers\Breaks\BreakDecisionsController;
use App\Http\Controllers\Breaks\MyBreaksController;
use App\Http\Controllers\Categories\CategoryController;
use App\Http\Controllers\Cron\CronController;
use App\Http\Controllers\Dashboard\LiveAttendanceController;
use App\Http\Controllers\Dashboard\OverviewController;
use App\Http\Controllers\Devices\DeviceFleetController;
use App\Http\Controllers\Devices\DeviceUsersController;
use App\Http\Controllers\Devices\ImportPunchesController;
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
use App\Http\Controllers\Loans\LoanController;
use App\Http\Controllers\Loans\MyAdvanceController;
use App\Http\Controllers\Notifications\MyNotificationsController;
use App\Http\Controllers\Payroll\AllowanceController;
use App\Http\Controllers\Payroll\ApproveController;
use App\Http\Controllers\Payroll\AuditLogController as PayrollAuditLogController;
use App\Http\Controllers\Payroll\BankFileController;
use App\Http\Controllers\Payroll\BulkAdjustController;
use App\Http\Controllers\Payroll\BulkAdjustmentBatchController;
use App\Http\Controllers\Payroll\CalculateController;
use App\Http\Controllers\Payroll\DeductionRulesController;
use App\Http\Controllers\Payroll\DisburseController;
use App\Http\Controllers\Payroll\EosbController;
use App\Http\Controllers\Payroll\GenerateController;
use App\Http\Controllers\Payroll\ListSlipsController;
use App\Http\Controllers\Payroll\LiveController;
use App\Http\Controllers\Payroll\ManualAdjustmentController;
use App\Http\Controllers\Payroll\MarkPaidController;
use App\Http\Controllers\Payroll\MySlipController;
use App\Http\Controllers\Payroll\OverrideLineController;
use App\Http\Controllers\Payroll\PayslipPdfController;
use App\Http\Controllers\Payroll\RevertController;
use App\Http\Controllers\Performance\ReviewController;
use App\Http\Controllers\Reports\ReportController;
use App\Http\Controllers\Schedule\RosterController;
use App\Http\Controllers\Settings\CompanySettingsController;
use App\Http\Controllers\Settings\LeaveSettingsController;
use App\Http\Controllers\Settings\StatutoryPayrollController;
use App\Http\Controllers\Settlements\SettlementController;
use App\Http\Controllers\Shifts\ShiftController;
use App\Http\Controllers\Support\SupportController;
use App\Http\Controllers\Team\AdminPermissionsController;
use App\Http\Controllers\Team\InvitationController;
use App\Http\Controllers\Team\TeamController;
use App\Http\Controllers\Tenant\OnboardingController;
use App\Http\Controllers\Warnings\WarningController;
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

        Route::post('v1/deductions/manual', [ManualAdjustmentController::class, 'addDeduction'])
            ->name('deductions.manual.add');
        Route::post('v1/deductions/manual/update', [ManualAdjustmentController::class, 'updateDeduction'])
            ->name('deductions.manual.update');
        Route::post('v1/deductions/manual/delete', [ManualAdjustmentController::class, 'deleteDeduction'])
            ->name('deductions.manual.delete');
        Route::post('v1/bonuses/manual', [ManualAdjustmentController::class, 'addBonus'])
            ->name('bonuses.manual.add');
        Route::post('v1/bonuses/manual/update', [ManualAdjustmentController::class, 'updateBonus'])
            ->name('bonuses.manual.update');
        Route::post('v1/bonuses/manual/delete', [ManualAdjustmentController::class, 'deleteBonus'])
            ->name('bonuses.manual.delete');

        Route::post('app/deductions/add_manual.php', [ManualAdjustmentController::class, 'addDeduction'])
            ->name('legacy.deductions.manual.add');
        Route::post('app/deductions/update_manual.php', [ManualAdjustmentController::class, 'updateDeduction'])
            ->name('legacy.deductions.manual.update');
        Route::post('app/deductions/delete_manual.php', [ManualAdjustmentController::class, 'deleteDeduction'])
            ->name('legacy.deductions.manual.delete');
        Route::post('app/bonuses/add_manual.php', [ManualAdjustmentController::class, 'addBonus'])
            ->name('legacy.bonuses.manual.add');
        Route::post('app/bonuses/update_manual.php', [ManualAdjustmentController::class, 'updateBonus'])
            ->name('legacy.bonuses.manual.update');
        Route::post('app/bonuses/delete_manual.php', [ManualAdjustmentController::class, 'deleteBonus'])
            ->name('legacy.bonuses.manual.delete');

        Route::get('v1/allowances', [AllowanceController::class, 'index'])->name('allowances.index');
        Route::post('v1/allowances', [AllowanceController::class, 'create'])->name('allowances.create');
        Route::post('v1/allowances/update', [AllowanceController::class, 'update'])->name('allowances.update');
        Route::post('v1/allowances/delete', [AllowanceController::class, 'delete'])->name('allowances.delete');

        Route::get('app/allowances/list.php', [AllowanceController::class, 'index'])
            ->name('legacy.allowances.index');
        Route::post('app/allowances/create.php', [AllowanceController::class, 'create'])
            ->name('legacy.allowances.create');
        Route::post('app/allowances/update.php', [AllowanceController::class, 'update'])
            ->name('legacy.allowances.update');
        Route::post('app/allowances/delete.php', [AllowanceController::class, 'delete'])
            ->name('legacy.allowances.delete');

        Route::get('v1/bulk-adjustments', [BulkAdjustmentBatchController::class, 'index'])
            ->name('bulk-adjustments.index');
        Route::get('v1/bulk-adjustments/get', [BulkAdjustmentBatchController::class, 'show'])
            ->name('bulk-adjustments.show');
        Route::post('v1/bulk-adjustments', [BulkAdjustmentBatchController::class, 'create'])
            ->name('bulk-adjustments.create');
        Route::post('v1/bulk-adjustments/update', [BulkAdjustmentBatchController::class, 'update'])
            ->name('bulk-adjustments.update');
        Route::post('v1/bulk-adjustments/delete', [BulkAdjustmentBatchController::class, 'delete'])
            ->name('bulk-adjustments.delete');
        Route::post('v1/bulk-adjustments/remove-member', [BulkAdjustmentBatchController::class, 'removeMember'])
            ->name('bulk-adjustments.remove-member');

        Route::get('app/bulk_adjustments/list.php', [BulkAdjustmentBatchController::class, 'index'])
            ->name('legacy.bulk-adjustments.index');
        Route::get('app/bulk_adjustments/get.php', [BulkAdjustmentBatchController::class, 'show'])
            ->name('legacy.bulk-adjustments.show');
        Route::post('app/bulk_adjustments/create.php', [BulkAdjustmentBatchController::class, 'create'])
            ->name('legacy.bulk-adjustments.create');
        Route::post('app/bulk_adjustments/update.php', [BulkAdjustmentBatchController::class, 'update'])
            ->name('legacy.bulk-adjustments.update');
        Route::post('app/bulk_adjustments/delete.php', [BulkAdjustmentBatchController::class, 'delete'])
            ->name('legacy.bulk-adjustments.delete');
        Route::post('app/bulk_adjustments/remove_member.php', [BulkAdjustmentBatchController::class, 'removeMember'])
            ->name('legacy.bulk-adjustments.remove-member');
    });

    /*
    |--------------------------------------------------------------------------
    | Deduction rules
    |--------------------------------------------------------------------------
    |
    | Saving the ladder is a separate permission from running payroll: deciding
    | what lateness costs is a policy decision, and the clerk who enters this
    | month's bonuses is not necessarily the person who sets it. Reading it is
    | ungated beyond tenancy, as it was — every screen that shows an employee
    | why they were docked needs it.
    |
    */

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/deduction-rules', [DeductionRulesController::class, 'show'])->name('deduction-rules.show');
        Route::get('app/deductions/get_rules.php', [DeductionRulesController::class, 'show'])
            ->name('legacy.deduction-rules.show');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_deduction_rules'])->group(function (): void {
        Route::post('v1/deduction-rules', [DeductionRulesController::class, 'save'])->name('deduction-rules.save');
        Route::post('app/deductions/save_config.php', [DeductionRulesController::class, 'save'])
            ->name('legacy.deduction-rules.save');
    });

    /*
    |--------------------------------------------------------------------------
    | Biometrics
    |--------------------------------------------------------------------------
    |
    | Enrolling and clearing are separate permissions. Enrolling is routine —
    | an attendance clerk does it as people join. Clearing is what authorises a
    | re-enrollment, so it is the one that could be used to swap somebody's
    | reference face, and it is held more narrowly.
    |
    | Reading the status is ungated beyond tenancy, as it was: the employee list
    | shows an enrollment badge on every row.
    |
    */

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/biometric/self/face', [SelfEnrollmentController::class, 'enroll'])
            ->name('biometric.self.enroll');
        Route::post('v1/biometric/self/status', [SelfEnrollmentController::class, 'status'])
            ->name('biometric.self.status');

        Route::post('app/biometric/enroll_self.php', [SelfEnrollmentController::class, 'enroll'])
            ->name('legacy.biometric.self.enroll');
        Route::post('app/biometric/my_status.php', [SelfEnrollmentController::class, 'status'])
            ->name('legacy.biometric.self.status');
    });

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/biometric/status', [EnrollmentController::class, 'status'])
            ->name('biometric.status');
        Route::get('app/biometric/status.php', [EnrollmentController::class, 'status'])
            ->name('legacy.biometric.status');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:biometric_enroll'])->group(function (): void {
        Route::post('v1/biometric/face', [EnrollmentController::class, 'enrollFace'])
            ->name('biometric.enroll-face');
        Route::post('v1/biometric/fingerprint', [EnrollmentController::class, 'enrollFingerprint'])
            ->name('biometric.enroll-fingerprint');

        Route::post('app/biometric/enroll_face.php', [EnrollmentController::class, 'enrollFace'])
            ->name('legacy.biometric.enroll-face');
        Route::post('app/biometric/enroll_fingerprint.php', [EnrollmentController::class, 'enrollFingerprint'])
            ->name('legacy.biometric.enroll-fingerprint');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:biometric_delete'])->group(function (): void {
        Route::post('v1/biometric/delete', [EnrollmentController::class, 'delete'])
            ->name('biometric.delete');
        // The original also answered DELETE here. Both verbs are kept: the
        // published app bundles speak POST and cannot be changed.
        Route::match(['post', 'delete'], 'app/biometric/delete.php', [EnrollmentController::class, 'delete'])
            ->name('legacy.biometric.delete');
    });

    /*
    |--------------------------------------------------------------------------
    | End-of-service settlements
    |--------------------------------------------------------------------------
    |
    | The final account with somebody leaving. Approving one ends the
    | employment, so the whole module sits behind manage_payroll: it is the
    | permission that already carries the authority to decide what a person is
    | paid.
    |
    */

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_payroll'])->group(function (): void {
        Route::get('v1/settlements', [SettlementController::class, 'show'])->name('settlements.show');
        Route::get('v1/settlements/preview', [SettlementController::class, 'preview'])
            ->name('settlements.preview');
        Route::post('v1/settlements', [SettlementController::class, 'save'])->name('settlements.save');
        Route::post('v1/settlements/approve', [SettlementController::class, 'approve'])
            ->name('settlements.approve');
        Route::post('v1/settlements/mark-paid', [SettlementController::class, 'markPaid'])
            ->name('settlements.mark-paid');

        Route::get('app/settlements/get.php', [SettlementController::class, 'show'])
            ->name('legacy.settlements.show');
        Route::get('app/settlements/preview.php', [SettlementController::class, 'preview'])
            ->name('legacy.settlements.preview');
        Route::post('app/settlements/save.php', [SettlementController::class, 'save'])
            ->name('legacy.settlements.save');
        Route::post('app/settlements/approve.php', [SettlementController::class, 'approve'])
            ->name('legacy.settlements.approve');
        Route::post('app/settlements/mark_paid.php', [SettlementController::class, 'markPaid'])
            ->name('legacy.settlements.mark-paid');
    });

    /*
    |--------------------------------------------------------------------------
    | Rotating-shift roster
    |--------------------------------------------------------------------------
    |
    | Reading and editing the grid both sit behind manage_company_settings, as
    | they did: deciding who works when is a scheduling decision, not an
    | attendance one.
    |
    */

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::get('v1/schedule/week', [RosterController::class, 'week'])->name('schedule.week');
        Route::post('v1/schedule/assign', [RosterController::class, 'assign'])->name('schedule.assign');
        Route::post('v1/schedule/clear', [RosterController::class, 'clear'])->name('schedule.clear');
        Route::post('v1/schedule/copy-week', [RosterController::class, 'copyWeek'])->name('schedule.copy-week');
        Route::post('v1/schedule/publish', [RosterController::class, 'publish'])->name('schedule.publish');

        Route::get('app/schedule/week.php', [RosterController::class, 'week'])->name('legacy.schedule.week');
        Route::post('app/schedule/assign.php', [RosterController::class, 'assign'])
            ->name('legacy.schedule.assign');
        Route::post('app/schedule/clear.php', [RosterController::class, 'clear'])
            ->name('legacy.schedule.clear');
        Route::post('app/schedule/copy_week.php', [RosterController::class, 'copyWeek'])
            ->name('legacy.schedule.copy-week');
        Route::post('app/schedule/publish.php', [RosterController::class, 'publish'])
            ->name('legacy.schedule.publish');
    });

    /*
    |--------------------------------------------------------------------------
    | Acquiring a company
    |--------------------------------------------------------------------------
    |
    | These run before there is a tenant to authenticate against, so they take a
    | Firebase token directly rather than going through the tenant middleware.
    | Each refuses an administrator who already belongs somewhere: one person
    | belongs to exactly one company, and a second would leave every
    | tenant-scoped query with two possible answers.
    |
    */

    Route::post('v1/tenants', [OnboardingController::class, 'create'])->name('tenants.create');
    Route::post('v1/tenants/join', [OnboardingController::class, 'join'])->name('tenants.join');
    Route::post('v1/tenants/accept-invitation', [OnboardingController::class, 'acceptInvitation'])
        ->name('tenants.accept-invitation');

    Route::post('app/tenant/create.php', [OnboardingController::class, 'create'])
        ->name('legacy.tenants.create');
    Route::post('app/tenant/join.php', [OnboardingController::class, 'join'])
        ->name('legacy.tenants.join');
    Route::post('app/tenant/accept_invitation.php', [OnboardingController::class, 'acceptInvitation'])
        ->name('legacy.tenants.accept-invitation');

    /*
    |--------------------------------------------------------------------------
    | Company settings
    |--------------------------------------------------------------------------
    |
    | Reading is open to anybody signed in: the attendance rules, the currency
    | and the week start are what half the other screens render themselves
    | against, so gating the read would break screens their own permission
    | already allows. Writing needs manage_company_settings — except the
    | statutory payroll figures, which are payroll's, not the office manager's.
    |
    | The originals answered GET and POST/PUT on one URL. Both verbs are kept on
    | the legacy paths because published app bundles use them.
    |
    */

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/settings/company', [CompanySettingsController::class, 'show'])
            ->name('settings.company.show');
        Route::get('v1/settings/leave', [LeaveSettingsController::class, 'show'])
            ->name('settings.leave.show');

        Route::get('app/settings/company.php', [CompanySettingsController::class, 'show'])
            ->name('legacy.settings.company.show');
        Route::get('app/settings/leave_settings.php', [LeaveSettingsController::class, 'show'])
            ->name('legacy.settings.leave.show');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::post('v1/settings/company', [CompanySettingsController::class, 'save'])
            ->name('settings.company.save');
        Route::post('v1/settings/leave', [LeaveSettingsController::class, 'save'])
            ->name('settings.leave.save');

        Route::match(['post', 'put'], 'app/settings/company.php', [CompanySettingsController::class, 'save'])
            ->name('legacy.settings.company.save');
        Route::match(['post', 'put'], 'app/settings/leave_settings.php', [LeaveSettingsController::class, 'save'])
            ->name('legacy.settings.leave.save');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_payroll'])->group(function (): void {
        Route::get('v1/settings/statutory-payroll', [StatutoryPayrollController::class, 'show'])
            ->name('settings.statutory.show');
        Route::post('v1/settings/statutory-payroll', [StatutoryPayrollController::class, 'save'])
            ->name('settings.statutory.save');

        Route::get('app/settings/statutory_payroll.php', [StatutoryPayrollController::class, 'show'])
            ->name('legacy.settings.statutory.show');
        Route::match(['post', 'put'], 'app/settings/statutory_payroll.php', [StatutoryPayrollController::class, 'save'])
            ->name('legacy.settings.statutory.save');
    });

    /*
    |--------------------------------------------------------------------------
    | Performance reviews
    |--------------------------------------------------------------------------
    */

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_performance'])->group(function (): void {
        Route::get('v1/performance/reviews', [ReviewController::class, 'index'])->name('performance.reviews');
        Route::post('v1/performance/reviews', [ReviewController::class, 'create'])
            ->name('performance.reviews.create');
        Route::post('v1/performance/reviews/delete', [ReviewController::class, 'delete'])
            ->name('performance.reviews.delete');

        Route::get('app/performance/review_list.php', [ReviewController::class, 'index'])
            ->name('legacy.performance.reviews');
        Route::post('app/performance/review_create.php', [ReviewController::class, 'create'])
            ->name('legacy.performance.reviews.create');
        Route::post('app/performance/review_delete.php', [ReviewController::class, 'delete'])
            ->name('legacy.performance.reviews.delete');
    });

    /*
    |--------------------------------------------------------------------------
    | Dashboard, activity log, warnings, notifications
    |--------------------------------------------------------------------------
    |
    | The overview is ungated beyond tenancy, as it was — it is the screen the
    | app opens on, and everybody who can sign in sees a version of it. The live
    | board needs view_reports; the activity log needs the settings permission,
    | because it exposes every management action in the company.
    |
    */

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/dashboard/overview', OverviewController::class)->name('dashboard.overview');
        Route::get('app/dashboard/overview.php', OverviewController::class)
            ->name('legacy.dashboard.overview');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:view_reports'])->group(function (): void {
        Route::get('v1/dashboard/live-attendance', LiveAttendanceController::class)
            ->name('dashboard.live-attendance');
        Route::get('app/dashboard/live_attendance.php', LiveAttendanceController::class)
            ->name('legacy.dashboard.live-attendance');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::get('v1/audit', AuditFeedController::class)->name('audit.index');
        Route::get('app/audit/list.php', AuditFeedController::class)->name('legacy.audit.index');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_employees'])->group(function (): void {
        Route::post('v1/warnings', [WarningController::class, 'create'])->name('warnings.create');
        Route::post('v1/warnings/delete', [WarningController::class, 'delete'])->name('warnings.delete');

        Route::post('app/warnings/add.php', [WarningController::class, 'create'])
            ->name('legacy.warnings.create');
        Route::post('app/warnings/delete.php', [WarningController::class, 'delete'])
            ->name('legacy.warnings.delete');
    });

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::get('v1/notifications', [MyNotificationsController::class, 'index'])
            ->name('notifications.index');
        Route::post('v1/notifications/read', [MyNotificationsController::class, 'markRead'])
            ->name('notifications.read');

        Route::get('app/notifications/list.php', [MyNotificationsController::class, 'index'])
            ->name('legacy.notifications.index');
        Route::post('app/notifications/read.php', [MyNotificationsController::class, 'markRead'])
            ->name('legacy.notifications.read');
    });

    /*
    |--------------------------------------------------------------------------
    | Scheduled jobs
    |--------------------------------------------------------------------------
    |
    | Reachable over HTTP because that is how the installed crontab calls them,
    | authenticating with a shared secret rather than as any of the three
    | principals. The work lives in App\Services\Cron and is also exposed as
    | artisan commands, so the server can move to the scheduler without a code
    | change here.
    |
    | GET, as the crontab issues, even though these write.
    |
    */

    Route::middleware('auth.cron')->group(function (): void {
        Route::match(['get', 'post'], 'v1/cron/catch-up-absences', [CronController::class, 'catchUpAbsences'])
            ->name('cron.catch-up-absences');
        Route::match(['get', 'post'], 'v1/cron/run-alerts', [CronController::class, 'runAlerts'])
            ->name('cron.run-alerts');
        Route::match(['get', 'post'], 'v1/cron/purge-kiosk-captures', [CronController::class, 'purgeKioskCaptures'])
            ->name('cron.purge-kiosk-captures');

        Route::match(['get', 'post'], 'app/cron/catchup_absences.php', [CronController::class, 'catchUpAbsences'])
            ->name('legacy.cron.catch-up-absences');
        Route::match(['get', 'post'], 'app/cron/run_alerts.php', [CronController::class, 'runAlerts'])
            ->name('legacy.cron.run-alerts');
        Route::match(['get', 'post'], 'app/cron/purge_kiosk_captures.php', [CronController::class, 'purgeKioskCaptures'])
            ->name('legacy.cron.purge-kiosk-captures');
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

    /*
    |--------------------------------------------------------------------------
    | The management team
    |--------------------------------------------------------------------------
    |
    | add_managers throughout, except the permission catalogue, which the
    | reports screens read to render names for permissions they display.
    |
    */

    Route::middleware(['auth.admin', 'tenant', 'can.do:add_managers'])->group(function (): void {
        Route::get('v1/team', [TeamController::class, 'index'])->name('team.list');
        Route::post('v1/team/update', [TeamController::class, 'update'])->name('team.update');
        Route::post('v1/team/set-active', [TeamController::class, 'setActive'])->name('team.set-active');
        Route::post('v1/team/remove', [TeamController::class, 'remove'])->name('team.remove');

        Route::get('v1/team/permissions', [AdminPermissionsController::class, 'show'])->name('team.permissions');
        Route::post('v1/team/permissions', [AdminPermissionsController::class, 'update'])
            ->name('team.permissions.update');
        Route::post('v1/team/permissions/reset', [AdminPermissionsController::class, 'reset'])
            ->name('team.permissions.reset');

        Route::get('v1/team/invitations', [InvitationController::class, 'index'])->name('team.invitations');
        Route::post('v1/team/invitations', [InvitationController::class, 'invite'])->name('team.invite');
        Route::get('v1/team/invitations/cancel', [InvitationController::class, 'cancel'])->name('team.invite.cancel');
        Route::post('v1/team/invitations/resend', [InvitationController::class, 'resend'])->name('team.invite.resend');

        Route::get('app/managers/list_admins.php', [TeamController::class, 'index'])->name('legacy.team.list');
        Route::post('app/managers/update_admin.php', [TeamController::class, 'update'])->name('legacy.team.update');
        Route::post('app/managers/set_admin_active.php', [TeamController::class, 'setActive'])
            ->name('legacy.team.set-active');
        Route::post('app/managers/remove_admin.php', [TeamController::class, 'remove'])->name('legacy.team.remove');

        Route::get('app/managers/get_admin_permissions.php', [AdminPermissionsController::class, 'show'])
            ->name('legacy.team.permissions');
        Route::post('app/managers/update_admin_permissions.php', [AdminPermissionsController::class, 'update'])
            ->name('legacy.team.permissions.update');
        Route::post('app/managers/reset_admin_permissions.php', [AdminPermissionsController::class, 'reset'])
            ->name('legacy.team.permissions.reset');

        Route::get('app/managers/list_invitations.php', [InvitationController::class, 'index'])
            ->name('legacy.team.invitations');
        Route::post('app/managers/invite.php', [InvitationController::class, 'invite'])->name('legacy.team.invite');
        // A GET that mutates, kept as it is: the published apps call it this way.
        Route::get('app/managers/cancel_invitation.php', [InvitationController::class, 'cancel'])
            ->name('legacy.team.invite.cancel');
        Route::post('app/managers/resend_invitation.php', [InvitationController::class, 'resend'])
            ->name('legacy.team.invite.resend');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:view_reports'])->group(function (): void {
        Route::get('v1/roles/permissions', [AdminPermissionsController::class, 'catalogue'])
            ->name('roles.permissions');
        Route::get('app/roles/list_permissions.php', [AdminPermissionsController::class, 'catalogue'])
            ->name('legacy.roles.permissions');
    });

    /*
    |--------------------------------------------------------------------------
    | Permissions (short breaks during a shift)
    |--------------------------------------------------------------------------
    |
    | Gated on manage_leaves, the same permission as leave: a manager who
    | decides one decides the other, and splitting them would leave companies
    | granting two permissions to describe one job.
    |
    */

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/breaks/request', [MyBreaksController::class, 'request'])->name('breaks.request');
        Route::get('v1/breaks/mine', [MyBreaksController::class, 'index'])->name('breaks.mine');
        Route::post('v1/breaks/cancel', [MyBreaksController::class, 'cancel'])->name('breaks.cancel');
        Route::post('v1/breaks/respond-postpone', [MyBreaksController::class, 'respondToPostpone'])
            ->name('breaks.respond-postpone');

        Route::post('app/breaks/request.php', [MyBreaksController::class, 'request'])->name('legacy.breaks.request');
        Route::get('app/breaks/my_list.php', [MyBreaksController::class, 'index'])->name('legacy.breaks.mine');
        Route::post('app/breaks/cancel.php', [MyBreaksController::class, 'cancel'])->name('legacy.breaks.cancel');
        Route::post('app/breaks/respond_postpone.php', [MyBreaksController::class, 'respondToPostpone'])
            ->name('legacy.breaks.respond-postpone');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_leaves'])->group(function (): void {
        Route::get('v1/breaks', [BreakDecisionsController::class, 'index'])->name('breaks.list');
        Route::post('v1/breaks', [BreakDecisionsController::class, 'createFor'])->name('breaks.create');
        Route::post('v1/breaks/approve', [BreakDecisionsController::class, 'approve'])->name('breaks.approve');
        Route::post('v1/breaks/reject', [BreakDecisionsController::class, 'reject'])->name('breaks.reject');
        Route::post('v1/breaks/postpone', [BreakDecisionsController::class, 'postpone'])->name('breaks.postpone');

        Route::get('app/breaks/list.php', [BreakDecisionsController::class, 'index'])->name('legacy.breaks.list');
        Route::post('app/breaks/create_for.php', [BreakDecisionsController::class, 'createFor'])
            ->name('legacy.breaks.create');
        Route::post('app/breaks/approve.php', [BreakDecisionsController::class, 'approve'])
            ->name('legacy.breaks.approve');
        Route::post('app/breaks/reject.php', [BreakDecisionsController::class, 'reject'])
            ->name('legacy.breaks.reject');
        Route::post('app/breaks/postpone.php', [BreakDecisionsController::class, 'postpone'])
            ->name('legacy.breaks.postpone');
    });

    /*
    |--------------------------------------------------------------------------
    | Fingerprint terminals
    |--------------------------------------------------------------------------
    |
    | The read screens accept either permission. They are reachable from two
    | directions — the person who runs attendance day to day, and the person
    | who set the hardware up — and either must not meet a 403 on a page their
    | own navigation offers them. Claiming and configuring hardware is a
    | company-settings decision; linking a User ID to a person is an attendance
    | one.
    |
    */

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/devices', [DeviceFleetController::class, 'index'])
            ->middleware('can.do:manage_attendance|manage_company_settings')->name('devices.list');
        Route::get('v1/devices/users', [DeviceUsersController::class, 'index'])
            ->middleware('can.do:manage_attendance|manage_company_settings')->name('devices.users');
        Route::get('v1/devices/punches', [DeviceFleetController::class, 'punches'])
            ->middleware('can.do:manage_attendance|manage_company_settings')->name('devices.punches');

        Route::post('v1/devices', [DeviceFleetController::class, 'register'])
            ->middleware('can.do:manage_company_settings')->name('devices.register');
        Route::post('v1/devices/update', [DeviceFleetController::class, 'update'])
            ->middleware('can.do:manage_company_settings')->name('devices.update');
        Route::post('v1/devices/delete', [DeviceFleetController::class, 'delete'])
            ->middleware('can.do:manage_company_settings')->name('devices.delete');
        Route::post('v1/devices/command', [DeviceFleetController::class, 'command'])
            ->middleware('can.do:manage_company_settings')->name('devices.command');

        Route::post('v1/devices/link-user', [DeviceUsersController::class, 'link'])
            ->middleware('can.do:manage_attendance')->name('devices.link-user');
        Route::post('v1/devices/import-punches', ImportPunchesController::class)
            ->middleware('can.do:manage_attendance')->name('devices.import-punches');

        Route::get('app/devices/list.php', [DeviceFleetController::class, 'index'])
            ->middleware('can.do:manage_attendance|manage_company_settings')->name('legacy.devices.list');
        Route::get('app/devices/users.php', [DeviceUsersController::class, 'index'])
            ->middleware('can.do:manage_attendance|manage_company_settings')->name('legacy.devices.users');
        Route::get('app/devices/punches.php', [DeviceFleetController::class, 'punches'])
            ->middleware('can.do:manage_attendance|manage_company_settings')->name('legacy.devices.punches');

        Route::post('app/devices/register.php', [DeviceFleetController::class, 'register'])
            ->middleware('can.do:manage_company_settings')->name('legacy.devices.register');
        Route::post('app/devices/update.php', [DeviceFleetController::class, 'update'])
            ->middleware('can.do:manage_company_settings')->name('legacy.devices.update');
        Route::post('app/devices/delete.php', [DeviceFleetController::class, 'delete'])
            ->middleware('can.do:manage_company_settings')->name('legacy.devices.delete');
        Route::post('app/devices/command.php', [DeviceFleetController::class, 'command'])
            ->middleware('can.do:manage_company_settings')->name('legacy.devices.command');

        Route::post('app/devices/link_user.php', [DeviceUsersController::class, 'link'])
            ->middleware('can.do:manage_attendance')->name('legacy.devices.link-user');
        Route::post('app/devices/import_punches.php', ImportPunchesController::class)
            ->middleware('can.do:manage_attendance')->name('legacy.devices.import-punches');
    });

    /*
    |--------------------------------------------------------------------------
    | Loans and salary advances
    |--------------------------------------------------------------------------
    |
    | An employee's own advance requests land in the same queue as anything an
    | administrator creates, so there is no second list to remember to check.
    |
    */

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/loans/request', [MyAdvanceController::class, 'request'])->name('loans.request');
        Route::get('v1/loans/mine', [MyAdvanceController::class, 'index'])->name('loans.mine');
        Route::post('v1/loans/cancel-request', [MyAdvanceController::class, 'cancel'])->name('loans.cancel-request');

        Route::post('app/loans/request.php', [MyAdvanceController::class, 'request'])->name('legacy.loans.request');
        Route::get('app/loans/my_list.php', [MyAdvanceController::class, 'index'])->name('legacy.loans.mine');
        Route::post('app/loans/cancel_request.php', [MyAdvanceController::class, 'cancel'])
            ->name('legacy.loans.cancel-request');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_payroll'])->group(function (): void {
        Route::get('v1/loans', [LoanController::class, 'index'])->name('loans.list');
        Route::get('v1/loans/show', [LoanController::class, 'show'])->name('loans.show');
        Route::post('v1/loans', [LoanController::class, 'create'])->name('loans.create');
        Route::post('v1/loans/approve', [LoanController::class, 'approve'])->name('loans.approve');
        Route::post('v1/loans/cancel', [LoanController::class, 'cancel'])->name('loans.cancel');

        Route::get('app/loans/list.php', [LoanController::class, 'index'])->name('legacy.loans.list');
        Route::get('app/loans/get.php', [LoanController::class, 'show'])->name('legacy.loans.show');
        Route::post('app/loans/create.php', [LoanController::class, 'create'])->name('legacy.loans.create');
        Route::post('app/loans/approve.php', [LoanController::class, 'approve'])->name('legacy.loans.approve');
        Route::post('app/loans/cancel.php', [LoanController::class, 'cancel'])->name('legacy.loans.cancel');
    });

    /*
    |--------------------------------------------------------------------------
    | Branches
    |--------------------------------------------------------------------------
    |
    | The list is open to anybody signed in: every screen with a branch picker
    | needs it, and gating it would break navigation for roles that can
    | legitimately reach those screens. Changing a branch is a company-settings
    | decision.
    |
    */

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/branches', [BranchController::class, 'index'])->name('branches.list');
        Route::get('app/branches/list.php', [BranchController::class, 'index'])->name('legacy.branches.list');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::post('v1/branches', [BranchController::class, 'create'])->name('branches.create');
        Route::post('v1/branches/update', [BranchController::class, 'update'])->name('branches.update');
        Route::post('v1/branches/generate-qr', [BranchController::class, 'generateQr'])->name('branches.generate-qr');
        Route::post('v1/branches/attendance-method', [BranchController::class, 'updateAttendanceMethod'])
            ->name('branches.attendance-method');

        Route::post('v1/branches/networks/capture', [BranchNetworkController::class, 'capture'])
            ->name('branches.networks.capture');
        Route::post('v1/branches/networks/approve', [BranchNetworkController::class, 'approve'])
            ->name('branches.networks.approve');
        Route::post('v1/branches/networks/sightings', [BranchNetworkController::class, 'sightings'])
            ->name('branches.networks.sightings');

        Route::post('app/branches/create.php', [BranchController::class, 'create'])->name('legacy.branches.create');
        Route::post('app/branches/update.php', [BranchController::class, 'update'])->name('legacy.branches.update');
        Route::post('app/branches/generate_qr.php', [BranchController::class, 'generateQr'])
            ->name('legacy.branches.generate-qr');
        Route::post('app/branches/update_attendance_method.php', [BranchController::class, 'updateAttendanceMethod'])
            ->name('legacy.branches.attendance-method');

        Route::post('app/branches/capture_network.php', [BranchNetworkController::class, 'capture'])
            ->name('legacy.branches.networks.capture');
        Route::post('app/branches/approve_networks.php', [BranchNetworkController::class, 'approve'])
            ->name('legacy.branches.networks.approve');
        Route::post('app/branches/network_sightings.php', [BranchNetworkController::class, 'sightings'])
            ->name('legacy.branches.networks.sightings');
    });

    /*
    |--------------------------------------------------------------------------
    | Custody
    |--------------------------------------------------------------------------
    |
    | Returning something is a two-step exchange: the employee says they are
    | handing it back, and somebody with the item in front of them confirms it.
    | So the two halves sit behind different guards.
    |
    */

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::get('v1/assets/mine', [MyAssetsController::class, 'index'])->name('assets.mine');
        Route::post('v1/assets/request-return', [MyAssetsController::class, 'requestReturn'])
            ->name('assets.request-return');

        Route::get('app/assets/my_list.php', [MyAssetsController::class, 'index'])->name('legacy.assets.mine');
        Route::post('app/assets/request_return.php', [MyAssetsController::class, 'requestReturn'])
            ->name('legacy.assets.request-return');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_assets'])->group(function (): void {
        Route::get('v1/assets', [AssetController::class, 'index'])->name('assets.list');
        Route::post('v1/assets', [AssetController::class, 'create'])->name('assets.create');
        Route::post('v1/assets/update', [AssetController::class, 'update'])->name('assets.update');
        Route::post('v1/assets/delete', [AssetController::class, 'delete'])->name('assets.delete');
        Route::post('v1/assets/approve-return', [AssetController::class, 'approveReturn'])
            ->name('assets.approve-return');
        Route::post('v1/assets/reject-return', [AssetController::class, 'rejectReturn'])
            ->name('assets.reject-return');

        Route::get('app/assets/list.php', [AssetController::class, 'index'])->name('legacy.assets.list');
        Route::post('app/assets/create.php', [AssetController::class, 'create'])->name('legacy.assets.create');
        Route::post('app/assets/update.php', [AssetController::class, 'update'])->name('legacy.assets.update');
        Route::post('app/assets/delete.php', [AssetController::class, 'delete'])->name('legacy.assets.delete');
        Route::post('app/assets/approve_return.php', [AssetController::class, 'approveReturn'])
            ->name('legacy.assets.approve-return');
        Route::post('app/assets/reject_return.php', [AssetController::class, 'rejectReturn'])
            ->name('legacy.assets.reject-return');
    });

    /*
    |--------------------------------------------------------------------------
    | Shifts, categories, reports and support
    |--------------------------------------------------------------------------
    |
    | Reading a shift or a category list accepts several permissions: both are
    | filter dimensions on screens that many roles can reach, and gating them
    | on the permission that *manages* them left those screens silently empty.
    | Managing either stays where it was.
    |
    */

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/shifts', [ShiftController::class, 'index'])
            ->middleware('can.do:manage_company_settings|manage_employees|manage_attendance|manage_schedule|view_reports')
            ->name('shifts.list');
        Route::get('app/shifts/list.php', [ShiftController::class, 'index'])
            ->middleware('can.do:manage_company_settings|manage_employees|manage_attendance|manage_schedule|view_reports')
            ->name('legacy.shifts.list');

        Route::get('v1/categories', [CategoryController::class, 'index'])
            ->middleware('can.do:manage_employees|view_reports|manage_company_settings')
            ->name('categories.list');
        Route::get('app/categories/list.php', [CategoryController::class, 'index'])
            ->middleware('can.do:manage_employees|view_reports|manage_company_settings')
            ->name('legacy.categories.list');

        // The browser-attendance exception is the company switch at a finer
        // grain, so it costs the same permission the switch does — not the one
        // that merely renames a category.
        Route::post('v1/categories/web-access', [CategoryController::class, 'updateWebAccess'])
            ->middleware('can.do:manage_company_settings')->name('categories.web-access');
        Route::post('app/categories/update_web_access.php', [CategoryController::class, 'updateWebAccess'])
            ->middleware('can.do:manage_company_settings')->name('legacy.categories.web-access');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::post('v1/shifts', [ShiftController::class, 'create'])->name('shifts.create');
        Route::post('v1/shifts/update', [ShiftController::class, 'update'])->name('shifts.update');
        Route::post('v1/shifts/delete', [ShiftController::class, 'delete'])->name('shifts.delete');
        Route::post('v1/shifts/assign', [ShiftController::class, 'assign'])->name('shifts.assign');
        Route::post('v1/shifts/unassign', [ShiftController::class, 'unassign'])->name('shifts.unassign');

        Route::post('app/shifts/create.php', [ShiftController::class, 'create'])->name('legacy.shifts.create');
        Route::post('app/shifts/update.php', [ShiftController::class, 'update'])->name('legacy.shifts.update');
        Route::post('app/shifts/delete.php', [ShiftController::class, 'delete'])->name('legacy.shifts.delete');
        Route::post('app/shifts/assign.php', [ShiftController::class, 'assign'])->name('legacy.shifts.assign');
        Route::post('app/shifts/unassign.php', [ShiftController::class, 'unassign'])->name('legacy.shifts.unassign');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_employees'])->group(function (): void {
        Route::post('v1/categories', [CategoryController::class, 'create'])->name('categories.create');
        Route::post('v1/categories/update', [CategoryController::class, 'update'])->name('categories.update');
        Route::post('v1/categories/delete', [CategoryController::class, 'delete'])->name('categories.delete');
        Route::post('v1/categories/assign', [CategoryController::class, 'assign'])->name('categories.assign');

        Route::post('app/categories/create.php', [CategoryController::class, 'create'])
            ->name('legacy.categories.create');
        Route::post('app/categories/update.php', [CategoryController::class, 'update'])
            ->name('legacy.categories.update');
        Route::post('app/categories/delete.php', [CategoryController::class, 'delete'])
            ->name('legacy.categories.delete');
        Route::post('app/categories/assign.php', [CategoryController::class, 'assign'])
            ->name('legacy.categories.assign');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:view_reports'])->group(function (): void {
        Route::get('v1/reports/attendance', [ReportController::class, 'attendance'])->name('reports.attendance');
        Route::get('v1/reports/employees', [ReportController::class, 'employees'])->name('reports.employees');
        Route::get('v1/reports/leaves', [ReportController::class, 'leaves'])->name('reports.leaves');
        Route::get('v1/reports/overtime-late', [ReportController::class, 'overtimeAndLate'])
            ->name('reports.overtime-late');
        Route::get('v1/reports/payroll', [ReportController::class, 'payroll'])->name('reports.payroll');

        Route::get('app/reports/attendance.php', [ReportController::class, 'attendance'])
            ->name('legacy.reports.attendance');
        Route::get('app/reports/employees.php', [ReportController::class, 'employees'])
            ->name('legacy.reports.employees');
        Route::get('app/reports/leaves.php', [ReportController::class, 'leaves'])->name('legacy.reports.leaves');
        Route::get('app/reports/overtime_late.php', [ReportController::class, 'overtimeAndLate'])
            ->name('legacy.reports.overtime-late');
        Route::get('app/reports/payroll.php', [ReportController::class, 'payroll'])->name('legacy.reports.payroll');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_support'])->group(function (): void {
        Route::get('v1/support/tickets', [SupportController::class, 'index'])->name('support.list');
        Route::post('v1/support/tickets', [SupportController::class, 'create'])->name('support.create');
        Route::get('v1/support/messages', [SupportController::class, 'messages'])->name('support.messages');
        Route::post('v1/support/reply', [SupportController::class, 'reply'])->name('support.reply');
        Route::post('v1/support/close', [SupportController::class, 'close'])->name('support.close');
        Route::get('v1/support/attachment', [SupportController::class, 'attachment'])->name('support.attachment');

        Route::get('app/support/list.php', [SupportController::class, 'index'])->name('legacy.support.list');
        Route::post('app/support/create.php', [SupportController::class, 'create'])->name('legacy.support.create');
        Route::get('app/support/messages.php', [SupportController::class, 'messages'])->name('legacy.support.messages');
        Route::post('app/support/reply.php', [SupportController::class, 'reply'])->name('legacy.support.reply');
        Route::post('app/support/close.php', [SupportController::class, 'close'])->name('legacy.support.close');
        Route::get('app/support/attachment.php', [SupportController::class, 'attachment'])
            ->name('legacy.support.attachment');
    });

});

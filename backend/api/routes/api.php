<?php

declare(strict_types=1);

use App\Modules\AdminSupport\Http\Controllers\AdminDeviceController;
use App\Modules\AdminSupport\Http\Controllers\AdminSupportController;
use App\Modules\AppControl\Http\Controllers\AppControlController;
use App\Modules\Assets\Http\Controllers\AssetController;
use App\Modules\Assets\Http\Controllers\MyAssetsController;
use App\Modules\Attendance\Http\Controllers\BranchAttendanceController;
use App\Modules\Attendance\Http\Controllers\BranchQrCodeController;
use App\Modules\Attendance\Http\Controllers\CheckInController;
use App\Modules\Attendance\Http\Controllers\CheckOutController;
use App\Modules\Attendance\Http\Controllers\CrewCheckInController;
use App\Modules\Attendance\Http\Controllers\CrewListController;
use App\Modules\Attendance\Http\Controllers\FaceChallengeController;
use App\Modules\Attendance\Http\Controllers\FaceLogsController;
use App\Modules\Attendance\Http\Controllers\ManualCheckInController;
use App\Modules\Attendance\Http\Controllers\MyAttendanceController;
use App\Modules\Attendance\Http\Controllers\PunchPhotoController;
use App\Modules\Attendance\Http\Controllers\SecurityLogController;
use App\Modules\Attendance\Http\Controllers\SetDayStatusController;
use App\Modules\Attendance\Http\Controllers\SetMethodOverrideController;
use App\Modules\Attendance\Http\Controllers\SyncOfflineController;
use App\Modules\Attendance\Http\Controllers\UpdateNoteController;
use App\Modules\Attendance\Http\Controllers\WebStatusController;
use App\Modules\Audit\Http\Controllers\AuditFeedController;
use App\Modules\Auth\Http\Controllers\AdminLoginController;
use App\Modules\Auth\Http\Controllers\AdminLogoutController;
use App\Modules\Auth\Http\Controllers\DeleteAccountController;
use App\Modules\Auth\Http\Controllers\DesktopAuthController;
use App\Modules\Auth\Http\Controllers\EmployeeActivateTokenController;
use App\Modules\Auth\Http\Controllers\EmployeeLoginController;
use App\Modules\Auth\Http\Controllers\EmployeeLogoutController;
use App\Modules\Auth\Http\Controllers\EmployeeWebActivateController;
use App\Modules\Auth\Http\Controllers\EmployeeWebLoginController;
use App\Modules\Auth\Http\Controllers\EmployeeWebLogoutController;
use App\Modules\Auth\Http\Controllers\NotificationPrefsController;
use App\Modules\Auth\Http\Controllers\SendAuthActionController;
use App\Modules\Auth\Http\Controllers\UpdateFcmTokenController;
use App\Modules\Auth\Http\Controllers\UpdateProfileController;
use App\Modules\Biometric\Http\Controllers\EnrollmentController;
use App\Modules\Biometric\Http\Controllers\SelfEnrollmentController;
use App\Modules\Branches\Http\Controllers\BranchController;
use App\Modules\Branches\Http\Controllers\BranchNetworkController;
use App\Modules\Breaks\Http\Controllers\BreakDecisionsController;
use App\Modules\Breaks\Http\Controllers\MyBreaksController;
use App\Modules\Categories\Http\Controllers\CategoryController;
use App\Modules\Cron\Http\Controllers\CronController;
use App\Modules\Dashboard\Http\Controllers\LiveAttendanceController;
use App\Modules\Dashboard\Http\Controllers\OverviewController;
use App\Modules\Devices\Http\Controllers\DeviceFleetController;
use App\Modules\Devices\Http\Controllers\DeviceUsersController;
use App\Modules\Devices\Http\Controllers\ImportPunchesController;
use App\Modules\Documents\Http\Controllers\DocumentReportsController;
use App\Modules\Documents\Http\Controllers\EmployeeDocumentsController;
use App\Modules\Documents\Http\Controllers\MyDocumentController;
use App\Modules\Documents\Http\Controllers\RequestDocumentController;
use App\Modules\Documents\Http\Controllers\RequiredDocumentController;
use App\Modules\Documents\Http\Controllers\ReviewDocumentController;
use App\Modules\Documents\Http\Controllers\UploadDocumentController;
use App\Modules\Documents\Http\Controllers\ViewDocumentController;
use App\Modules\Employees\Http\Controllers\ActivationCodeController;
use App\Modules\Employees\Http\Controllers\AttendanceHistoryController;
use App\Modules\Employees\Http\Controllers\CreateEmployeeController;
use App\Modules\Employees\Http\Controllers\DeleteEmployeeController;
use App\Modules\Employees\Http\Controllers\EmployeeProfileController;
use App\Modules\Employees\Http\Controllers\EmployeeStatusController;
use App\Modules\Employees\Http\Controllers\FinancialSummaryController;
use App\Modules\Employees\Http\Controllers\ListEmployeesController;
use App\Modules\Employees\Http\Controllers\ListTerminatedController;
use App\Modules\Employees\Http\Controllers\MyProfileController;
use App\Modules\Employees\Http\Controllers\SuspensionController;
use App\Modules\Employees\Http\Controllers\UpdateEmployeeController;
use App\Modules\Kiosk\Http\Controllers\IdentifyController;
use App\Modules\Kiosk\Http\Controllers\KioskAdminController;
use App\Modules\Kiosk\Http\Controllers\KioskFleetController;
use App\Modules\Kiosk\Http\Controllers\KioskSessionController;
use App\Modules\Kiosk\Http\Controllers\PairingController;
use App\Modules\Kiosk\Http\Controllers\PunchController;
use App\Modules\Landing\Http\Controllers\JoinLinkController;
use App\Modules\Landing\Http\Controllers\WellKnownController;
use App\Modules\Leave\Http\Controllers\CarryoverController;
use App\Modules\Leave\Http\Controllers\LeaveAdminController;
use App\Modules\Leave\Http\Controllers\MyLeaveController;
use App\Modules\Loans\Http\Controllers\LoanController;
use App\Modules\Loans\Http\Controllers\MyAdvanceController;
use App\Modules\Notifications\Http\Controllers\MyNotificationsController;
use App\Modules\Payroll\Http\Controllers\AllowanceController;
use App\Modules\Payroll\Http\Controllers\ApproveController;
use App\Modules\Payroll\Http\Controllers\AuditLogController as PayrollAuditLogController;
use App\Modules\Payroll\Http\Controllers\BankFileController;
use App\Modules\Payroll\Http\Controllers\BulkAdjustController;
use App\Modules\Payroll\Http\Controllers\BulkAdjustmentBatchController;
use App\Modules\Payroll\Http\Controllers\CalculateController;
use App\Modules\Payroll\Http\Controllers\DeductionRulesController;
use App\Modules\Payroll\Http\Controllers\DisburseController;
use App\Modules\Payroll\Http\Controllers\EosbController;
use App\Modules\Payroll\Http\Controllers\GenerateController;
use App\Modules\Payroll\Http\Controllers\ListSlipsController;
use App\Modules\Payroll\Http\Controllers\LiveController;
use App\Modules\Payroll\Http\Controllers\ManualAdjustmentController;
use App\Modules\Payroll\Http\Controllers\MarkPaidController;
use App\Modules\Payroll\Http\Controllers\MySlipController;
use App\Modules\Payroll\Http\Controllers\OverrideLineController;
use App\Modules\Payroll\Http\Controllers\PayslipPdfController;
use App\Modules\Payroll\Http\Controllers\RevertController;
use App\Modules\Performance\Http\Controllers\ReviewController;
use App\Modules\Reports\Http\Controllers\ReportController;
use App\Modules\Reports\Http\Controllers\WordExportController;
use App\Modules\Schedule\Http\Controllers\RosterController;
use App\Modules\Settings\Http\Controllers\CompanySettingsController;
use App\Modules\Settings\Http\Controllers\LeaveSettingsController;
use App\Modules\Settings\Http\Controllers\StatutoryPayrollController;
use App\Modules\Settlements\Http\Controllers\SettlementController;
use App\Modules\Shifts\Http\Controllers\ShiftController;
use App\Modules\SuperAdmin\Http\Controllers\AdminAccountController;
use App\Modules\SuperAdmin\Http\Controllers\AuthController as SuperAdminAuthController;
use App\Modules\SuperAdmin\Http\Controllers\DiagnosticsController;
use App\Modules\SuperAdmin\Http\Controllers\DirectoryController;
use App\Modules\SuperAdmin\Http\Controllers\PlatformController;
use App\Modules\SuperAdmin\Http\Controllers\TenantController as SuperAdminTenantController;
use App\Modules\Support\Http\Controllers\SupportController;
use App\Modules\Team\Http\Controllers\AdminPermissionsController;
use App\Modules\Team\Http\Controllers\InvitationController;
use App\Modules\Team\Http\Controllers\TeamController;
use App\Modules\Tenant\Http\Controllers\OnboardingController;
use App\Modules\Terminal\Http\Controllers\IclockController;
use App\Modules\Warnings\Http\Controllers\WarningController;
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

/*
|--------------------------------------------------------------------------
| Deep links
|--------------------------------------------------------------------------
|
| The only HTML this backend serves, and the association files the two mobile
| platforms fetch to decide whether a domain may open an app.
|
| Outside every gate: an app-link check is made by the operating system before
| anybody has signed in, and the landing pages are for a visitor who does not
| have the app yet. Nothing here reads the database or reveals anything the
| visitor is not already holding in their URL.
|
*/

Route::get('join', [JoinLinkController::class, 'employee'])->name('landing.join');
Route::get('join_team', [JoinLinkController::class, 'team'])->name('landing.join-team');

// The legacy filenames, still linked from published builds and sent emails.

Route::get('.well-known/{file}', WellKnownController::class)
    ->where('file', 'assetlinks\.json|apple-app-site-association')
    ->name('landing.well-known');

/*
|--------------------------------------------------------------------------
| Attendance terminals
|--------------------------------------------------------------------------
|
| The one door not opened by a signed-in human. A ZKTeco terminal cannot
| send any credential the firmware knows about — what it sends is its serial
| number, and a serial no company has claimed can do nothing here.
|
| Both shapes are registered: /iclock/<action>, which is what the firmware
| derives from its server setting, and the direct filename the old
| deployment used. Every verb, because the protocol uses GET for the
| handshake and POST for uploads and does not always agree with itself.
|
| Reached over plain HTTP on port 8090 straight to the origin: old ZK
| firmware has weak or no TLS and sends no SNI, so it cannot pass Cloudflare.
|
*/

Route::any('iclock/{action}', IclockController::class)
    ->where('action', '[A-Za-z]+')
    ->name('terminal.iclock');

Route::middleware(['app.secret', 'throttle:api'])->group(function (): void {

    // ── Employee sessions ────────────────────────────────────────────────
    Route::post('v1/auth/employee/activate', EmployeeActivateTokenController::class)
        ->name('employee.activate');
    Route::post('v1/auth/employee/login', EmployeeLoginController::class)
        ->name('employee.login');
    Route::post('v1/auth/employee/logout', EmployeeLogoutController::class)
        ->name('employee.logout');

    // ── Browser sessions ─────────────────────────────────────────────────
    // A separate identity from the phone: signing in here must not sign the
    // employee out of their app, and vice versa.
    Route::post('v1/auth/employee/web/activate', EmployeeWebActivateController::class)
        ->name('employee.web.activate');
    Route::post('v1/auth/employee/web/login', EmployeeWebLoginController::class)
        ->name('employee.web.login');
    Route::post('v1/auth/employee/web/logout', EmployeeWebLogoutController::class)
        ->name('employee.web.logout');

    // ── Administrator sessions ───────────────────────────────────────────
    // Sign-in verifies the Firebase token itself, so it sits outside the guard.
    Route::post('v1/auth/admin/login', AdminLoginController::class)->name('admin.login');

    Route::middleware('auth.admin')->group(function (): void {
        Route::post('v1/auth/admin/logout', AdminLogoutController::class)
            ->name('admin.logout');
    });

    // ── Desktop shell sign-in ────────────────────────────────────────────
    // The exchange is unauthenticated on purpose: the code IS the credential.
    Route::post('v1/auth/desktop/exchange', [DesktopAuthController::class, 'exchange'])
        ->name('desktop.exchange');

    Route::middleware('auth.admin')->group(function (): void {
        Route::post('v1/auth/desktop/authorize', [DesktopAuthController::class, 'authorize'])
            ->name('desktop.authorize');

        Route::post('v1/auth/account', DeleteAccountController::class)->name('account.delete');
    });

    // ── Transactional auth email ─────────────────────────────────────────
    // Unauthenticated, and both always answer success: saying whether an
    // address is registered would make either one an enumeration oracle.
    Route::post('v1/auth/password-reset', [SendAuthActionController::class, 'passwordReset'])
        ->name('password-reset.send');
    Route::post('v1/auth/verification', [SendAuthActionController::class, 'verification'])
        ->name('verification.send');

    // ── Account settings ─────────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/auth/profile', UpdateProfileController::class)->name('profile.update');
    });

    Route::middleware('auth.employee')->group(function (): void {
        Route::get('v1/auth/notification-prefs', [NotificationPrefsController::class, 'show'])
            ->name('notification-prefs.show');
        Route::post('v1/auth/notification-prefs', [NotificationPrefsController::class, 'update'])
            ->name('notification-prefs.update');

        // One legacy URL, two methods — the old file branched on the request
        // method inside itself.
    });

    // Called by both apps, so the principal follows whichever credential arrived.
    Route::middleware('auth.either')->group(function (): void {
        Route::post('v1/auth/fcm-token', UpdateFcmTokenController::class)->name('fcm-token.update');
    });

    // ── Attendance ───────────────────────────────────────────────────────
    // Both channels reach the same action; which one is in play comes from the
    // session, never from the request.
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/attendance/check-in', CheckInController::class)->name('attendance.check-in');
        Route::post('v1/attendance/check-out', CheckOutController::class)->name('attendance.check-out');

        Route::post('v1/attendance/face-challenge', FaceChallengeController::class)
            ->name('attendance.face-challenge');
        Route::post('v1/attendance/crew', CrewListController::class)->name('attendance.crew');
        Route::post('v1/attendance/security-log', SecurityLogController::class)
            ->name('attendance.security-log');

        Route::post('v1/attendance/crew/punch', CrewCheckInController::class)
            ->name('attendance.crew.punch');

        Route::post('v1/attendance/sync-offline', SyncOfflineController::class)
            ->name('attendance.sync-offline');

        Route::get('v1/attendance/mine', MyAttendanceController::class)->name('attendance.mine');

        Route::post('v1/attendance/web-status', WebStatusController::class)
            ->name('attendance.web-status');
    });

    // Management side: recorded for an employee rather than by them.
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/attendance/method-override', SetMethodOverrideController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('attendance.method-override');

        Route::post('v1/attendance/branch-qr', BranchQrCodeController::class)
            ->middleware('can.do:manage_company_settings')
            ->name('attendance.branch-qr');

        Route::middleware('can.do:manage_attendance')->group(function (): void {
            Route::get('v1/attendance/branch', BranchAttendanceController::class)
                ->name('attendance.branch');
            Route::get('v1/attendance/photo', PunchPhotoController::class)
                ->name('attendance.photo');
            Route::post('v1/attendance/face-logs', FaceLogsController::class)
                ->name('attendance.face-logs');

            Route::post('v1/attendance/day-status', SetDayStatusController::class)
                ->name('attendance.day-status');

            Route::post('v1/attendance/manual', ManualCheckInController::class)
                ->name('attendance.manual');
            Route::post('v1/attendance/note', UpdateNoteController::class)->name('attendance.note');

        });
    });

    // ── Employees ────────────────────────────────────────────────────────
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::get('v1/employees/me', MyProfileController::class)->name('employees.me');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_employees'])->group(function (): void {
        Route::get('v1/employees', ListEmployeesController::class)->name('employees.list');
        Route::get('v1/employees/terminated', ListTerminatedController::class)
            ->name('employees.terminated');
        Route::post('v1/employees/{id}/terminate', DeleteEmployeeController::class)->name('employees.terminate');

        Route::post('v1/employees', CreateEmployeeController::class)->name('employees.create');
        Route::patch('v1/employees/{id}', UpdateEmployeeController::class)->name('employees.update');

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

        Route::get('v1/employees/activation-code', [ActivationCodeController::class, 'show'])
            ->name('employees.activation-code');
        Route::post('v1/employees/activation-code', [ActivationCodeController::class, 'regenerate'])
            ->name('employees.activation-code.regenerate');

    });

    // ── Employee documents ───────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::middleware('can.do:manage_documents')->group(function (): void {
            Route::get('v1/employees/documents', [EmployeeDocumentsController::class, 'index'])
                ->name('documents.index');
            Route::get('v1/employees/documents/missing', [EmployeeDocumentsController::class, 'missing'])
                ->name('documents.missing');
            Route::patch('v1/employees/documents/{id}', [ReviewDocumentController::class, 'update'])
                ->name('documents.update');
            Route::delete('v1/employees/documents/{id}', [ReviewDocumentController::class, 'destroy'])
                ->name('documents.delete');

        });

        // Verifying is its own permission: deciding whether a passport is
        // genuine is a different job from filing it.
        Route::middleware('can.do:documents_verify')->group(function (): void {
            Route::post('v1/employees/documents/verify', [ReviewDocumentController::class, 'verify'])
                ->name('documents.verify');
            Route::post('v1/employees/documents/reject', [ReviewDocumentController::class, 'reject'])
                ->name('documents.reject');

        });
    });

    // ── Employee profile ─────────────────────────────────────────────────
    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/employees/profile', [EmployeeProfileController::class, 'show'])
            ->name('employees.profile');

        Route::get('v1/employees/expiring-compliance', [EmployeeProfileController::class, 'expiringCompliance'])
            ->middleware('can.do:manage_employees')
            ->name('employees.expiring-compliance');

        Route::get('v1/employees/year-to-date', [EmployeeProfileController::class, 'yearToDate'])
            ->middleware('can.do:manage_payroll')
            ->name('employees.year-to-date');
    });

    // ── Handing documents in ─────────────────────────────────────────────
    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::post('v1/employees/documents/submit', [UploadDocumentController::class, 'byEmployee'])
            ->name('documents.submit');
        Route::get('v1/employees/documents/mine', MyDocumentController::class)
            ->name('documents.mine');

    });

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::post('v1/employees/documents/upload', [UploadDocumentController::class, 'byAdmin'])
            ->middleware('can.do:manage_documents')
            ->name('documents.upload');

        Route::post('v1/employees/documents/request', RequestDocumentController::class)
            ->middleware('can.do:manage_documents')
            ->name('documents.request');

        Route::get('v1/employees/attendance-history', AttendanceHistoryController::class)
            ->middleware('can.do:manage_attendance')
            ->name('employees.attendance-history');
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

        Route::post('v1/deductions/manual', [ManualAdjustmentController::class, 'addDeduction'])
            ->name('deductions.manual.add');
        Route::patch('v1/deductions/manual/{id}', [ManualAdjustmentController::class, 'updateDeduction'])
            ->name('deductions.manual.update');
        Route::delete('v1/deductions/manual/{id}', [ManualAdjustmentController::class, 'deleteDeduction'])
            ->name('deductions.manual.delete');
        Route::post('v1/bonuses/manual', [ManualAdjustmentController::class, 'addBonus'])
            ->name('bonuses.manual.add');
        Route::patch('v1/bonuses/manual/{id}', [ManualAdjustmentController::class, 'updateBonus'])
            ->name('bonuses.manual.update');
        Route::delete('v1/bonuses/manual/{id}', [ManualAdjustmentController::class, 'deleteBonus'])
            ->name('bonuses.manual.delete');

        Route::get('v1/allowances', [AllowanceController::class, 'index'])->name('allowances.index');
        Route::post('v1/allowances', [AllowanceController::class, 'create'])->name('allowances.create');
        Route::patch('v1/allowances/{id}', [AllowanceController::class, 'update'])->name('allowances.update');
        Route::delete('v1/allowances/{id}', [AllowanceController::class, 'delete'])->name('allowances.delete');

        Route::get('v1/bulk-adjustments', [BulkAdjustmentBatchController::class, 'index'])
            ->name('bulk-adjustments.index');
        Route::get('v1/bulk-adjustments/get', [BulkAdjustmentBatchController::class, 'show'])
            ->name('bulk-adjustments.show');
        Route::post('v1/bulk-adjustments', [BulkAdjustmentBatchController::class, 'create'])
            ->name('bulk-adjustments.create');
        Route::patch('v1/bulk-adjustments/{id}', [BulkAdjustmentBatchController::class, 'update'])
            ->name('bulk-adjustments.update');
        Route::delete('v1/bulk-adjustments/{id}', [BulkAdjustmentBatchController::class, 'delete'])
            ->name('bulk-adjustments.delete');
        Route::post('v1/bulk-adjustments/remove-member', [BulkAdjustmentBatchController::class, 'removeMember'])
            ->name('bulk-adjustments.remove-member');

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
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_deduction_rules'])->group(function (): void {
        Route::post('v1/deduction-rules', [DeductionRulesController::class, 'save'])->name('deduction-rules.save');
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

    });

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        Route::get('v1/biometric/status', [EnrollmentController::class, 'status'])
            ->name('biometric.status');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:biometric_enroll'])->group(function (): void {
        Route::post('v1/biometric/face', [EnrollmentController::class, 'enrollFace'])
            ->name('biometric.enroll-face');
        Route::post('v1/biometric/fingerprint', [EnrollmentController::class, 'enrollFingerprint'])
            ->name('biometric.enroll-fingerprint');

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:biometric_delete'])->group(function (): void {
        Route::delete('v1/biometric/{id}', [EnrollmentController::class, 'delete'])
            ->name('biometric.delete');
        // The original also answered DELETE here. Both verbs are kept: the
        // published app bundles speak POST and cannot be changed.
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

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::post('v1/settings/company', [CompanySettingsController::class, 'save'])
            ->name('settings.company.save');
        Route::post('v1/settings/leave', [LeaveSettingsController::class, 'save'])
            ->name('settings.leave.save');

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_payroll'])->group(function (): void {
        Route::get('v1/settings/statutory-payroll', [StatutoryPayrollController::class, 'show'])
            ->name('settings.statutory.show');
        Route::post('v1/settings/statutory-payroll', [StatutoryPayrollController::class, 'save'])
            ->name('settings.statutory.save');

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
        Route::delete('v1/performance/reviews/{id}', [ReviewController::class, 'delete'])
            ->name('performance.reviews.delete');

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
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:view_reports'])->group(function (): void {
        Route::get('v1/dashboard/live-attendance', LiveAttendanceController::class)
            ->name('dashboard.live-attendance');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::get('v1/audit', AuditFeedController::class)->name('audit.index');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_employees'])->group(function (): void {
        Route::post('v1/warnings', [WarningController::class, 'create'])->name('warnings.create');
        Route::delete('v1/warnings/{id}', [WarningController::class, 'delete'])->name('warnings.delete');

    });

    Route::middleware(['auth.employee', 'tenant'])->group(function (): void {
        Route::get('v1/notifications', [MyNotificationsController::class, 'index'])
            ->name('notifications.index');
        Route::post('v1/notifications/read', [MyNotificationsController::class, 'markRead'])
            ->name('notifications.read');

    });

    /*
    |--------------------------------------------------------------------------
    | Scheduled jobs
    |--------------------------------------------------------------------------
    |
    | Reachable over HTTP because that is how the installed crontab calls them,
    | authenticating with a shared secret rather than as any of the three
    | principals. The work lives in App\Modules\Cron\Services and is also exposed as
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

    });

    /*
    |--------------------------------------------------------------------------
    | The support desk
    |--------------------------------------------------------------------------
    |
    | The internal panel, authenticating with its own bearer session rather than
    | a Firebase credential, and deliberately not scoped to a company — looking
    | across them is the point. Every action lands in the super-admin audit log.
    |
    | App control is superadmin only: raising a minimum version locks out every
    | installed build below it, and for the kiosk that means physically visiting
    | each branch.
    |
    */

    Route::middleware('auth.super:admin')->group(function (): void {
        Route::get('v1/admin/support/tickets', [AdminSupportController::class, 'index'])
            ->name('admin.support.tickets');
        Route::get('v1/admin/support/messages', [AdminSupportController::class, 'messages'])
            ->name('admin.support.messages');
        Route::get('v1/admin/support/attachment', [AdminSupportController::class, 'attachment'])
            ->name('admin.support.attachment');
        Route::post('v1/admin/support/reply', [AdminSupportController::class, 'reply'])
            ->name('admin.support.reply');
        Route::post('v1/admin/support/status', [AdminSupportController::class, 'setStatus'])
            ->name('admin.support.status');

        Route::post('v1/admin/devices', AdminDeviceController::class)->name('admin.devices.register');
    });

    Route::middleware('auth.super:superadmin')->group(function (): void {
        Route::get('v1/admin/app-control', [AppControlController::class, 'show'])
            ->name('admin.app-control.show');
        Route::post('v1/admin/app-control', [AppControlController::class, 'save'])
            ->name('admin.app-control.save');

    });

    /*
    |--------------------------------------------------------------------------
    | The internal admin panel
    |--------------------------------------------------------------------------
    |
    | Three rungs. `readonly` sees everything and changes nothing; `admin` acts
    | on companies and their people; `superadmin` does the things that cannot be
    | undone from a phone call — creating a company, adding an operator, raising
    | the update floor, and signing in as a customer.
    |
    */

    Route::post('v1/admin/auth/login', [SuperAdminAuthController::class, 'login'])
        ->name('super.auth.login');

    Route::middleware('auth.super:readonly')->group(function (): void {
        Route::post('v1/admin/auth/logout', [SuperAdminAuthController::class, 'logout'])
            ->name('super.auth.logout');
        Route::get('v1/admin/auth/me', [SuperAdminAuthController::class, 'me'])->name('super.auth.me');
        Route::post('v1/admin/auth/password', [SuperAdminAuthController::class, 'changePassword'])
            ->name('super.auth.password');

        Route::get('v1/admin/dashboard', [PlatformController::class, 'overview'])
            ->name('super.dashboard');
        Route::get('v1/admin/tenants', [SuperAdminTenantController::class, 'index'])
            ->name('super.tenants.index');
        Route::get('v1/admin/tenants/detail', [SuperAdminTenantController::class, 'show'])
            ->name('super.tenants.show');
        Route::get('v1/admin/tenants/diagnostics', DiagnosticsController::class)
            ->name('super.tenants.diagnostics');
        Route::get('v1/admin/company-admins', [DirectoryController::class, 'admins'])
            ->name('super.company-admins');
        Route::get('v1/admin/audit', [DirectoryController::class, 'audit'])->name('super.audit');

    });

    Route::middleware('auth.super:admin')->group(function (): void {
        Route::patch('v1/admin/tenants/{id}', [SuperAdminTenantController::class, 'update'])
            ->name('super.tenants.update');
        Route::post('v1/admin/tenants/activate', [SuperAdminTenantController::class, 'activate'])
            ->name('super.tenants.activate');
        Route::post('v1/admin/tenants/deactivate', [SuperAdminTenantController::class, 'deactivate'])
            ->name('super.tenants.deactivate');

        Route::post('v1/admin/company-admins/invite', [AdminAccountController::class, 'invite'])
            ->name('super.company-admins.invite');
        Route::post('v1/admin/company-admins/reset-password', [AdminAccountController::class, 'resetPassword'])
            ->name('super.company-admins.reset-password');
        Route::post('v1/admin/company-admins/set-active', [AdminAccountController::class, 'setActive'])
            ->name('super.company-admins.set-active');

        Route::post('v1/admin/announcements/all', [PlatformController::class, 'announceToAll'])
            ->name('super.announcements.all');
        Route::post('v1/admin/announcements/tenant', [PlatformController::class, 'announceToTenant'])
            ->name('super.announcements.tenant');

    });

    Route::middleware('auth.super:superadmin')->group(function (): void {
        Route::post('v1/admin/tenants', [SuperAdminTenantController::class, 'create'])
            ->name('super.tenants.create');
        Route::post('v1/admin/operators', [DirectoryController::class, 'createOperator'])
            ->name('super.operators.create');
        Route::post('v1/admin/force-update', [PlatformController::class, 'forceUpdate'])
            ->name('super.force-update');
        Route::post('v1/admin/company-admins/impersonate', [AdminAccountController::class, 'impersonate'])
            ->name('super.company-admins.impersonate');

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
        Route::patch('v1/leaves/{id}', [MyLeaveController::class, 'update'])->name('leaves.update');

    });

    Route::middleware(['auth.admin', 'tenant'])->group(function (): void {
        // The gate depends on whose balance is asked for, so it is checked in
        // the controller rather than on the route.
        Route::get('v1/leaves/balance', [LeaveAdminController::class, 'balance'])->name('leaves.balance');

        // Needs both manage_leaves and manage_attendance: it cancels leave and
        // writes attendance.
        Route::post('v1/leaves/convert-to-absence', [LeaveAdminController::class, 'convertToAbsence'])
            ->name('leaves.convert-to-absence');
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
        Route::delete('v1/leaves/carryover-policies/{id}', [CarryoverController::class, 'delete'])
            ->name('leaves.carryover-policy-delete');
        Route::post('v1/leaves/rollover', [CarryoverController::class, 'rollover'])->name('leaves.rollover');
        Route::get('v1/leaves/encashments', [CarryoverController::class, 'encashments'])
            ->name('leaves.encashments');

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
        Route::patch('v1/documents/required/{id}', [RequiredDocumentController::class, 'update'])
            ->middleware('can.do:documents_manage_types')->name('documents.required.update');
        Route::delete('v1/documents/required/{id}', [RequiredDocumentController::class, 'delete'])
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
        Route::patch('v1/team/{id}', [TeamController::class, 'update'])->name('team.update');
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

        // A GET that mutates, kept as it is: the published apps call it this way.
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:view_reports'])->group(function (): void {
        Route::get('v1/roles/permissions', [AdminPermissionsController::class, 'catalogue'])
            ->name('roles.permissions');
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

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_leaves'])->group(function (): void {
        Route::get('v1/breaks', [BreakDecisionsController::class, 'index'])->name('breaks.list');
        Route::post('v1/breaks', [BreakDecisionsController::class, 'createFor'])->name('breaks.create');
        Route::post('v1/breaks/approve', [BreakDecisionsController::class, 'approve'])->name('breaks.approve');
        Route::post('v1/breaks/reject', [BreakDecisionsController::class, 'reject'])->name('breaks.reject');
        Route::post('v1/breaks/postpone', [BreakDecisionsController::class, 'postpone'])->name('breaks.postpone');

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
        Route::patch('v1/devices/{id}', [DeviceFleetController::class, 'update'])
            ->middleware('can.do:manage_company_settings')->name('devices.update');
        Route::delete('v1/devices/{id}', [DeviceFleetController::class, 'delete'])
            ->middleware('can.do:manage_company_settings')->name('devices.delete');
        Route::post('v1/devices/command', [DeviceFleetController::class, 'command'])
            ->middleware('can.do:manage_company_settings')->name('devices.command');

        Route::post('v1/devices/link-user', [DeviceUsersController::class, 'link'])
            ->middleware('can.do:manage_attendance')->name('devices.link-user');
        Route::post('v1/devices/import-punches', ImportPunchesController::class)
            ->middleware('can.do:manage_attendance')->name('devices.import-punches');

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

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_payroll'])->group(function (): void {
        Route::get('v1/loans', [LoanController::class, 'index'])->name('loans.list');
        Route::get('v1/loans/show', [LoanController::class, 'show'])->name('loans.show');
        Route::post('v1/loans', [LoanController::class, 'create'])->name('loans.create');
        Route::post('v1/loans/approve', [LoanController::class, 'approve'])->name('loans.approve');
        Route::post('v1/loans/cancel', [LoanController::class, 'cancel'])->name('loans.cancel');

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
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::post('v1/branches', [BranchController::class, 'create'])->name('branches.create');
        Route::patch('v1/branches/{id}', [BranchController::class, 'update'])->name('branches.update');
        Route::post('v1/branches/generate-qr', [BranchController::class, 'generateQr'])->name('branches.generate-qr');
        Route::post('v1/branches/attendance-method', [BranchController::class, 'updateAttendanceMethod'])
            ->name('branches.attendance-method');

        Route::post('v1/branches/networks/capture', [BranchNetworkController::class, 'capture'])
            ->name('branches.networks.capture');
        Route::post('v1/branches/networks/approve', [BranchNetworkController::class, 'approve'])
            ->name('branches.networks.approve');
        Route::post('v1/branches/networks/sightings', [BranchNetworkController::class, 'sightings'])
            ->name('branches.networks.sightings');

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

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_assets'])->group(function (): void {
        Route::get('v1/assets', [AssetController::class, 'index'])->name('assets.list');
        Route::post('v1/assets', [AssetController::class, 'create'])->name('assets.create');
        Route::patch('v1/assets/{id}', [AssetController::class, 'update'])->name('assets.update');
        Route::delete('v1/assets/{id}', [AssetController::class, 'delete'])->name('assets.delete');
        Route::post('v1/assets/approve-return', [AssetController::class, 'approveReturn'])
            ->name('assets.approve-return');
        Route::post('v1/assets/reject-return', [AssetController::class, 'rejectReturn'])
            ->name('assets.reject-return');

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

        Route::get('v1/categories', [CategoryController::class, 'index'])
            ->middleware('can.do:manage_employees|view_reports|manage_company_settings')
            ->name('categories.list');

        // The browser-attendance exception is the company switch at a finer
        // grain, so it costs the same permission the switch does — not the one
        // that merely renames a category.
        Route::post('v1/categories/web-access', [CategoryController::class, 'updateWebAccess'])
            ->middleware('can.do:manage_company_settings')->name('categories.web-access');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_company_settings'])->group(function (): void {
        Route::post('v1/shifts', [ShiftController::class, 'create'])->name('shifts.create');
        Route::patch('v1/shifts/{id}', [ShiftController::class, 'update'])->name('shifts.update');
        Route::delete('v1/shifts/{id}', [ShiftController::class, 'delete'])->name('shifts.delete');
        Route::post('v1/shifts/assign', [ShiftController::class, 'assign'])->name('shifts.assign');
        Route::post('v1/shifts/unassign', [ShiftController::class, 'unassign'])->name('shifts.unassign');

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_employees'])->group(function (): void {
        Route::post('v1/categories', [CategoryController::class, 'create'])->name('categories.create');
        Route::patch('v1/categories/{id}', [CategoryController::class, 'update'])->name('categories.update');
        Route::delete('v1/categories/{id}', [CategoryController::class, 'delete'])->name('categories.delete');
        Route::post('v1/categories/assign', [CategoryController::class, 'assign'])->name('categories.assign');

    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:view_reports'])->group(function (): void {
        Route::get('v1/reports/attendance', [ReportController::class, 'attendance'])->name('reports.attendance');
        Route::get('v1/reports/employees', [ReportController::class, 'employees'])->name('reports.employees');
        Route::get('v1/reports/leaves', [ReportController::class, 'leaves'])->name('reports.leaves');
        Route::get('v1/reports/overtime-late', [ReportController::class, 'overtimeAndLate'])
            ->name('reports.overtime-late');
        Route::get('v1/reports/payroll', [ReportController::class, 'payroll'])->name('reports.payroll');

        // POST because the client sends the finished table it already has on
        // screen, rather than the server re-deriving figures that could then
        // disagree with it.
        Route::post('v1/reports/export.docx', WordExportController::class)->name('reports.export-word');
    });

    Route::middleware(['auth.admin', 'tenant', 'can.do:manage_support'])->group(function (): void {
        Route::get('v1/support/tickets', [SupportController::class, 'index'])->name('support.list');
        Route::post('v1/support/tickets', [SupportController::class, 'create'])->name('support.create');
        Route::get('v1/support/messages', [SupportController::class, 'messages'])->name('support.messages');
        Route::post('v1/support/reply', [SupportController::class, 'reply'])->name('support.reply');
        Route::post('v1/support/close', [SupportController::class, 'close'])->name('support.close');
        Route::get('v1/support/attachment', [SupportController::class, 'attachment'])->name('support.attachment');

    });

});

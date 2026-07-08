<?php

if (defined('MEDJAT_BOOTSTRAPPED')) {
    return;
}

require_once __DIR__ . '/env.php';
require_once __DIR__ . '/database.php';
require_once __DIR__ . '/cors.php';
require_once __DIR__ . '/firebase.php';

require_once __DIR__ . '/../core/Response.php';
require_once __DIR__ . '/../core/Background.php';
require_once __DIR__ . '/../core/Auth.php';
require_once __DIR__ . '/../core/AdminAuth.php';
require_once __DIR__ . '/../core/BaseApi.php';
require_once __DIR__ . '/../core/AdminBaseApi.php';
require_once __DIR__ . '/../core/RateLimiter.php';
require_once __DIR__ . '/../core/Cache.php';
require_once __DIR__ . '/../core/Validator.php';
require_once __DIR__ . '/../core/TenantMiddleware.php';
require_once __DIR__ . '/../core/PermissionMiddleware.php';
require_once __DIR__ . '/../core/PayrollCalculator.php';
require_once __DIR__ . '/../core/PayrollCache.php';
require_once __DIR__ . '/../core/PayslipPdfService.php';
require_once __DIR__ . '/../core/GpsService.php';
require_once __DIR__ . '/../core/I18n.php';
require_once __DIR__ . '/../core/NotificationService.php';
require_once __DIR__ . '/../core/RemoteConfigService.php';
require_once __DIR__ . '/../core/SmartAlertService.php';
require_once __DIR__ . '/../core/EmailService.php';
require_once __DIR__ . '/../core/AuthEmail.php';
require_once __DIR__ . '/../core/LoginAlertService.php';
require_once __DIR__ . '/../core/EmployeeActivationAlert.php';
require_once __DIR__ . '/../core/ManagerAlert.php';
require_once __DIR__ . '/../core/ApprovalEngine.php';
require_once __DIR__ . '/../core/ApprovalDispatcher.php';

require_once __DIR__ . '/../models/TenantModel.php';
require_once __DIR__ . '/../models/AdminModel.php';
require_once __DIR__ . '/../models/BranchModel.php';
require_once __DIR__ . '/../models/EmployeeModel.php';
require_once __DIR__ . '/../models/AttendanceModel.php';
require_once __DIR__ . '/../models/DeductionRuleModel.php';
require_once __DIR__ . '/../models/BonusRuleModel.php';
require_once __DIR__ . '/../models/BulkAdjustmentModel.php';
require_once __DIR__ . '/../models/LeaveModel.php';
require_once __DIR__ . '/../models/LeaveCarryoverPolicyModel.php';
require_once __DIR__ . '/../models/LeaveEncashmentModel.php';
require_once __DIR__ . '/../models/BreakRequestModel.php';
require_once __DIR__ . '/../models/PayrollModel.php';
require_once __DIR__ . '/../models/DocumentModel.php';
require_once __DIR__ . '/../models/WarningModel.php';
require_once __DIR__ . '/../models/PerformanceModel.php';
require_once __DIR__ . '/../models/RoleModel.php';
require_once __DIR__ . '/../models/AuditLogModel.php';
require_once __DIR__ . '/../models/ShiftModel.php';
require_once __DIR__ . '/../models/EmployeeShiftScheduleModel.php';
require_once __DIR__ . '/../models/ActivationCodeModel.php';
require_once __DIR__ . '/../models/EmployeeAuthTokenModel.php';
require_once __DIR__ . '/../models/ManagerInvitationModel.php';
require_once __DIR__ . '/../models/BiometricModel.php';
require_once __DIR__ . '/../models/EmployeeCategoryModel.php';
require_once __DIR__ . '/../models/PayrollStatutoryModel.php';
require_once __DIR__ . '/../models/LoanModel.php';
require_once __DIR__ . '/../models/AllowanceModel.php';
require_once __DIR__ . '/../models/AssetModel.php';
require_once __DIR__ . '/../models/EmployeeSuspensionModel.php';
require_once __DIR__ . '/../models/PayrollLineOverrideModel.php';
require_once __DIR__ . '/../models/AttendanceSecurityModel.php';
require_once __DIR__ . '/../models/SupportModel.php';
require_once __DIR__ . '/../models/OnboardingModel.php';
require_once __DIR__ . '/../models/PerformanceCycleModel.php';
require_once __DIR__ . '/../models/ApprovalChainModel.php';
require_once __DIR__ . '/../models/ApprovalRequestModel.php';

require_once __DIR__ . '/../core/payroll_export/PayrollExportContext.php';
require_once __DIR__ . '/../core/payroll_export/PayrollExporter.php';
require_once __DIR__ . '/../core/payroll_export/PayrollFieldCatalog.php';
require_once __DIR__ . '/../core/payroll_export/exporters/EgyptGenericBankExporter.php';
require_once __DIR__ . '/../core/payroll_export/PayrollExporterRegistry.php';
require_once __DIR__ . '/../models/EmployeeSettlementModel.php';
require_once __DIR__ . '/../core/SettlementCalculator.php';
require_once __DIR__ . '/../core/AttendanceMethodResolver.php';

setCorsHeaders();

// API access gate: every request from the mobile apps carries an HTTP Basic
// credential (SECURITY_USER:SECURITY_KEY). When both are configured we require
// a match, so the API can't be called directly without the shared app secret.
// Disabled automatically when unset (local dev), and never applies to CLI cron
// scripts or a caller presenting the valid CRON_SECRET.
(static function (): void {
    $user = (string) getenv('SECURITY_USER');
    $key  = (string) getenv('SECURITY_KEY');
    if ($user === '' || $key === '' || PHP_SAPI === 'cli') {
        return;
    }

    $cronSecret = (string) getenv('CRON_SECRET');
    $providedCron = (string) ($_SERVER['HTTP_X_CRON_SECRET'] ?? $_GET['cron_secret'] ?? '');
    if ($cronSecret !== '' && hash_equals($cronSecret, $providedCron)) {
        return;
    }

    // Apache/LiteSpeed populates PHP_AUTH_* for Basic auth; fall back to the raw
    // Authorization header (needs CGIPassAuth/rewrite to be forwarded to PHP).
    $u = $_SERVER['PHP_AUTH_USER'] ?? null;
    $k = $_SERVER['PHP_AUTH_PW'] ?? null;
    if ($u === null) {
        $header = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
        if (stripos($header, 'Basic ') === 0) {
            $decoded = base64_decode(substr($header, 6), true);
            if ($decoded !== false && strpos($decoded, ':') !== false) {
                [$u, $k] = explode(':', $decoded, 2);
            }
        }
    }

    $ok = $u !== null && hash_equals($user, (string) $u) && hash_equals($key, (string) $k);
    if (!$ok) {
        http_response_code(401);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode([
            'status' => 'error',
            'code' => 401,
            'message' => 'Unauthorized',
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }
})();

define('MEDJAT_BOOTSTRAPPED', true);

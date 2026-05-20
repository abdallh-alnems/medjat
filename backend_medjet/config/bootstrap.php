<?php

if (defined('MEDJAT_BOOTSTRAPPED')) {
    return;
}

require_once __DIR__ . '/env.php';
require_once __DIR__ . '/database.php';
require_once __DIR__ . '/cors.php';
require_once __DIR__ . '/firebase.php';

require_once __DIR__ . '/../core/Response.php';
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
require_once __DIR__ . '/../core/GpsService.php';
require_once __DIR__ . '/../core/I18n.php';
require_once __DIR__ . '/../core/NotificationService.php';

require_once __DIR__ . '/../models/TenantModel.php';
require_once __DIR__ . '/../models/AdminModel.php';
require_once __DIR__ . '/../models/BranchModel.php';
require_once __DIR__ . '/../models/EmployeeModel.php';
require_once __DIR__ . '/../models/AttendanceModel.php';
require_once __DIR__ . '/../models/DeductionRuleModel.php';
require_once __DIR__ . '/../models/BonusRuleModel.php';
require_once __DIR__ . '/../models/LeaveModel.php';
require_once __DIR__ . '/../models/PayrollModel.php';
require_once __DIR__ . '/../models/DocumentModel.php';
require_once __DIR__ . '/../models/WarningModel.php';
require_once __DIR__ . '/../models/PerformanceModel.php';
require_once __DIR__ . '/../models/RoleModel.php';
require_once __DIR__ . '/../models/SubscriptionModel.php';
require_once __DIR__ . '/../models/AuditLogModel.php';
require_once __DIR__ . '/../models/ShiftModel.php';
require_once __DIR__ . '/../models/ActivationCodeModel.php';
require_once __DIR__ . '/../models/EmployeeAuthTokenModel.php';
require_once __DIR__ . '/../models/ManagerInvitationModel.php';
require_once __DIR__ . '/../models/BiometricModel.php';
require_once __DIR__ . '/../models/AttendanceStationModel.php';
require_once __DIR__ . '/../models/StationRecognitionLogModel.php';

setCorsHeaders();

define('MEDJAT_BOOTSTRAPPED', true);

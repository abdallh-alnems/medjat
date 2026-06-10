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
require_once __DIR__ . '/../core/PayrollCache.php';
require_once __DIR__ . '/../core/LetterPdfService.php';
require_once __DIR__ . '/../core/PayslipPdfService.php';
require_once __DIR__ . '/../core/GpsService.php';
require_once __DIR__ . '/../core/I18n.php';
require_once __DIR__ . '/../core/NotificationService.php';
require_once __DIR__ . '/../core/SmartAlertService.php';
require_once __DIR__ . '/../core/EmailService.php';
require_once __DIR__ . '/../core/AuthEmail.php';
require_once __DIR__ . '/../core/LoginAlertService.php';
require_once __DIR__ . '/../core/EmployeeActivationAlert.php';
require_once __DIR__ . '/../core/ManagerAlert.php';
require_once __DIR__ . '/../core/ApprovalEngine.php';
require_once __DIR__ . '/../core/ApprovalDispatcher.php';
require_once __DIR__ . '/../core/SignedPdfService.php';
require_once __DIR__ . '/../core/SignatureService.php';

require_once __DIR__ . '/../models/TenantModel.php';
require_once __DIR__ . '/../models/AdminModel.php';
require_once __DIR__ . '/../models/BranchModel.php';
require_once __DIR__ . '/../models/EmployeeModel.php';
require_once __DIR__ . '/../models/AttendanceModel.php';
require_once __DIR__ . '/../models/DeductionRuleModel.php';
require_once __DIR__ . '/../models/BonusRuleModel.php';
require_once __DIR__ . '/../models/LeaveModel.php';
require_once __DIR__ . '/../models/BreakRequestModel.php';
require_once __DIR__ . '/../models/PayrollModel.php';
require_once __DIR__ . '/../models/DocumentModel.php';
require_once __DIR__ . '/../models/WarningModel.php';
require_once __DIR__ . '/../models/PerformanceModel.php';
require_once __DIR__ . '/../models/RoleModel.php';
require_once __DIR__ . '/../models/SubscriptionModel.php';
require_once __DIR__ . '/../models/AuditLogModel.php';
require_once __DIR__ . '/../models/ShiftModel.php';
require_once __DIR__ . '/../models/EmployeeShiftScheduleModel.php';
require_once __DIR__ . '/../models/ActivationCodeModel.php';
require_once __DIR__ . '/../models/EmployeeAuthTokenModel.php';
require_once __DIR__ . '/../models/ManagerInvitationModel.php';
require_once __DIR__ . '/../models/BiometricModel.php';
require_once __DIR__ . '/../models/AttendanceStationModel.php';
require_once __DIR__ . '/../models/StationRecognitionLogModel.php';
require_once __DIR__ . '/../models/EmployeeCategoryModel.php';
require_once __DIR__ . '/../models/PayrollStatutoryModel.php';
require_once __DIR__ . '/../models/ExpenseModel.php';
require_once __DIR__ . '/../models/LoanModel.php';
require_once __DIR__ . '/../models/AllowanceModel.php';
require_once __DIR__ . '/../models/DocumentTemplateModel.php';
require_once __DIR__ . '/../models/DocumentRequestModel.php';
require_once __DIR__ . '/../models/SignatureRequestModel.php';
require_once __DIR__ . '/../models/SignaturePartyModel.php';
require_once __DIR__ . '/../models/AssetModel.php';
require_once __DIR__ . '/../models/EmployeeSuspensionModel.php';
require_once __DIR__ . '/../models/PayrollLineOverrideModel.php';
require_once __DIR__ . '/../models/KioskPinModel.php';
require_once __DIR__ . '/../models/AttendanceSecurityModel.php';
require_once __DIR__ . '/../core/StationQrTokenService.php';
require_once __DIR__ . '/../models/SupportModel.php';
require_once __DIR__ . '/../models/JobOpeningModel.php';
require_once __DIR__ . '/../models/CandidateModel.php';
require_once __DIR__ . '/../models/OnboardingModel.php';
require_once __DIR__ . '/../models/PerformanceCycleModel.php';
require_once __DIR__ . '/../models/PerformanceGoalModel.php';
require_once __DIR__ . '/../models/AnnouncementModel.php';
require_once __DIR__ . '/../models/KudosModel.php';
require_once __DIR__ . '/../models/SurveyModel.php';
require_once __DIR__ . '/../models/EmployeeAvailabilityModel.php';
require_once __DIR__ . '/../models/OpenShiftModel.php';
require_once __DIR__ . '/../models/ShiftSwapModel.php';
require_once __DIR__ . '/../models/ApprovalChainModel.php';
require_once __DIR__ . '/../models/ApprovalRequestModel.php';
require_once __DIR__ . '/../models/AnalyticsModel.php';
require_once __DIR__ . '/../models/AnalyticsDashboardModel.php';

require_once __DIR__ . '/../models/PayrollExportTemplateModel.php';
require_once __DIR__ . '/../core/payroll_export/PayrollExportContext.php';
require_once __DIR__ . '/../core/payroll_export/PayrollExporter.php';
require_once __DIR__ . '/../core/payroll_export/PayrollFieldCatalog.php';
require_once __DIR__ . '/../core/payroll_export/exporters/EgyptGenericBankExporter.php';
require_once __DIR__ . '/../core/payroll_export/exporters/CustomTemplateExporter.php';
require_once __DIR__ . '/../core/payroll_export/PayrollExporterRegistry.php';
require_once __DIR__ . '/../models/EmployeeSettlementModel.php';
require_once __DIR__ . '/../core/SettlementCalculator.php';

setCorsHeaders();

define('MEDJAT_BOOTSTRAPPED', true);

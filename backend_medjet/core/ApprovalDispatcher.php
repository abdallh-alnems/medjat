<?php

final class ApprovalDispatcher {
    public static function apply(int $tenantId, string $entityType, int $entityId,
                                 string $decision, int $adminId, ?string $note): void {
        switch ($entityType) {
            case 'leave':
                if ($decision === 'approved') {
                    LeaveModel::approve($entityId, $tenantId, $adminId);
                } else {
                    LeaveModel::reject($entityId, $tenantId, $adminId, $note);
                }
                return;
            default:
                error_log("ApprovalDispatcher: unmapped entity_type '{$entityType}' (request {$decision} but no entity action)");
        }
    }
}

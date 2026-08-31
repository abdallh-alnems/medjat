<?php

final class ApprovalEngine {
    public static function route(int $tenantId, string $entityType, int $entityId, array $ctx): array {
        if (!in_array($entityType, ApprovalChainModel::REQUEST_TYPES, true)) {
            return ['routed' => false];
        }

        $amount = $ctx['amount'] ?? null;
        $branchId = $ctx['branch_id'] ?? null;

        $chain = ApprovalChainModel::resolveChain(
            $tenantId,
            $entityType,
            $amount !== null ? (float) $amount : null,
            $branchId !== null ? (int) $branchId : null
        );

        if (!$chain) {
            return ['routed' => false];
        }

        $steps = $chain['steps'] ?? [];
        if (empty($steps)) {
            return ['routed' => false];
        }

        $requestId = ApprovalRequestModel::open(
            $tenantId,
            $chain,
            $steps,
            $entityType,
            $entityId,
            $ctx['by_admin_id'] ?? null,
            $ctx['by_employee_id'] ?? null,
            $amount !== null ? (float) $amount : null
        );

        return ['routed' => true, 'request_id' => $requestId];
    }

    public static function isPending(int $tenantId, string $entityType, int $entityId): bool {
        $req = ApprovalRequestModel::findOpenForEntity($tenantId, $entityType, $entityId);
        return $req !== null;
    }

    public static function cancelFor(int $tenantId, string $entityType, int $entityId): void {
        $req = ApprovalRequestModel::findOpenForEntity($tenantId, $entityType, $entityId);
        if ($req) {
            ApprovalRequestModel::cancel($tenantId, (int) $req['id']);
        }
    }
}

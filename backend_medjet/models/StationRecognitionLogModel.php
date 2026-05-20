<?php

final class StationRecognitionLogModel {
    public static function log(
        int $stationId,
        int $branchId,
        int $tenantId,
        ?int $employeeId,
        string $method,
        string $result,
        ?float $confidence = null,
        ?string $reason = null,
        ?string $capturedImage = null,
        ?float $lat = null,
        ?float $lng = null
    ): int {
        Database::execute(
            "INSERT INTO station_recognition_logs
                (tenant_id, branch_id, station_id, matched_employee_id, verification_method, confidence_score, result, failure_reason, captured_image_path, gps_lat, gps_lng)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            [$tenantId, $branchId, $stationId, $employeeId, $method, $confidence, $result, $reason, $capturedImage, $lat, $lng]
        );
        return (int) Database::lastInsertId();
    }

    public static function getLogs(int $tenantId, array $filters = [], int $page = 1, int $limit = 20): array {
        $sql = "SELECT l.*, e.name AS employee_name, s.device_name AS station_name
                FROM station_recognition_logs l
                LEFT JOIN employees e ON e.id = l.matched_employee_id
                LEFT JOIN attendance_stations s ON s.id = l.station_id
                WHERE l.tenant_id = ?";
        $params = [$tenantId];

        if (!empty($filters['branch_id'])) {
            $sql .= " AND l.branch_id = ?";
            $params[] = (int) $filters['branch_id'];
        }
        if (!empty($filters['station_id'])) {
            $sql .= " AND l.station_id = ?";
            $params[] = (int) $filters['station_id'];
        }
        if (!empty($filters['employee_id'])) {
            $sql .= " AND l.matched_employee_id = ?";
            $params[] = (int) $filters['employee_id'];
        }
        if (!empty($filters['result'])) {
            $sql .= " AND l.result = ?";
            $params[] = $filters['result'];
        }
        if (!empty($filters['from'])) {
            $sql .= " AND l.created_at >= ?";
            $params[] = $filters['from'];
        }
        if (!empty($filters['to'])) {
            $sql .= " AND l.created_at <= ?";
            $params[] = $filters['to'] . ' 23:59:59';
        }

        $countSql = str_replace(
            "l.*, e.name AS employee_name, s.device_name AS station_name",
            "COUNT(*) as total",
            $sql
        );
        $total = (int) (Database::fetchOne($countSql, $params)['total'] ?? 0);

        $offset = ($page - 1) * $limit;
        $sql .= " ORDER BY l.created_at DESC LIMIT ? OFFSET ?";
        $params[] = $limit;
        $params[] = $offset;

        $items = Database::fetchAll($sql, $params);

        return [
            'items' => $items,
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
        ];
    }
}

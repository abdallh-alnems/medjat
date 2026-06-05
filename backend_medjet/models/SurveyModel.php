<?php

final class SurveyModel {
    public const TYPES = ['enps', 'pulse', 'custom'];
    public const QTYPES = ['enps', 'rating', 'scale', 'text', 'single_choice', 'multi_choice'];
    public const STATUSES = ['draft', 'active', 'closed'];
    public const AUDIENCE_TYPES = ['all', 'branch', 'category'];

    public static function create(int $tenantId, array $data, int $adminId): int {
        Database::execute(
            "INSERT INTO surveys (tenant_id, title, title_ar, description, type, is_anonymous, audience_type, audience_id, status, start_date, end_date, created_by)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'draft', ?, ?, ?)",
            [
                $tenantId,
                $data['title'],
                $data['title_ar'] ?? null,
                $data['description'] ?? null,
                $data['type'] ?? 'custom',
                isset($data['is_anonymous']) ? (int) $data['is_anonymous'] : 1,
                $data['audience_type'] ?? 'all',
                $data['audience_id'] ?? null,
                $data['start_date'] ?? null,
                $data['end_date'] ?? null,
                $adminId,
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function findById(int $id, int $tenantId): ?array {
        return Database::fetchOne(
            "SELECT * FROM surveys WHERE id = ? AND tenant_id = ?",
            [$id, $tenantId]
        );
    }

    public static function listForAdmin(int $tenantId, ?string $status = null): array {
        $sql = "SELECT s.*,
                       (SELECT COUNT(*) FROM survey_responses sr WHERE sr.survey_id = s.id) AS response_count
                FROM surveys s
                WHERE s.tenant_id = ?";
        $params = [$tenantId];
        if ($status !== null) {
            $sql .= " AND s.status = ?";
            $params[] = $status;
        }
        $sql .= " ORDER BY s.created_at DESC";
        return Database::fetchAll($sql, $params);
    }

    public static function update(int $id, int $tenantId, array $data): void {
        $allowed = ['title', 'title_ar', 'description', 'type', 'is_anonymous', 'audience_type', 'audience_id', 'start_date', 'end_date'];
        $fields = [];
        $values = [];
        foreach ($allowed as $key) {
            if (array_key_exists($key, $data)) {
                $fields[] = "`{$key}` = ?";
                $values[] = $data[$key];
            }
        }
        if (empty($fields)) {
            return;
        }
        $values[] = $id;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE surveys SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function setStatus(int $id, int $tenantId, string $status): void {
        $params = [$status];
        $sql = "UPDATE surveys SET status = ?";
        if ($status === 'closed') {
            $sql .= ", closed_at = NOW()";
        }
        $sql .= " WHERE id = ? AND tenant_id = ?";
        $params[] = $id;
        $params[] = $tenantId;
        Database::execute($sql, $params);
    }

    public static function addQuestion(int $surveyId, int $tenantId, array $data): int {
        $survey = self::findById($surveyId, $tenantId);
        if (!$survey || $survey['status'] !== 'draft') {
            Response::fail('Questions can only be added to draft surveys', 422);
        }

        Database::execute(
            "INSERT INTO survey_questions (survey_id, tenant_id, question, question_ar, qtype, options, is_required, sort_order)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            [
                $surveyId,
                $tenantId,
                $data['question'],
                $data['question_ar'] ?? null,
                $data['qtype'] ?? 'rating',
                isset($data['options']) ? json_encode($data['options'], JSON_UNESCAPED_UNICODE) : null,
                isset($data['is_required']) ? (int) $data['is_required'] : 1,
                (int) ($data['sort_order'] ?? 0),
            ]
        );
        return (int) Database::lastInsertId();
    }

    public static function listQuestions(int $surveyId, int $tenantId): array {
        return Database::fetchAll(
            "SELECT * FROM survey_questions WHERE survey_id = ? AND tenant_id = ? ORDER BY sort_order ASC, id ASC",
            [$surveyId, $tenantId]
        );
    }

    public static function updateQuestion(int $questionId, int $tenantId, array $data): void {
        $question = Database::fetchOne(
            "SELECT sq.*, s.status AS survey_status FROM survey_questions sq JOIN surveys s ON s.id = sq.survey_id WHERE sq.id = ? AND sq.tenant_id = ?",
            [$questionId, $tenantId]
        );
        if (!$question) {
            Response::notFound('Question');
        }
        if ($question['survey_status'] !== 'draft') {
            Response::fail('Questions can only be updated in draft surveys', 422);
        }

        $allowed = ['question', 'question_ar', 'qtype', 'options', 'is_required', 'sort_order'];
        $fields = [];
        $values = [];
        foreach ($allowed as $key) {
            if (array_key_exists($key, $data)) {
                $val = $data[$key];
                if ($key === 'options') {
                    $val = json_encode($val, JSON_UNESCAPED_UNICODE);
                }
                $fields[] = "`{$key}` = ?";
                $values[] = $val;
            }
        }
        if (empty($fields)) {
            return;
        }
        $values[] = $questionId;
        $values[] = $tenantId;
        Database::execute(
            "UPDATE survey_questions SET " . implode(', ', $fields) . " WHERE id = ? AND tenant_id = ?",
            $values
        );
    }

    public static function deleteQuestion(int $questionId, int $tenantId): bool {
        $question = Database::fetchOne(
            "SELECT sq.*, s.status AS survey_status FROM survey_questions sq JOIN surveys s ON s.id = sq.survey_id WHERE sq.id = ? AND sq.tenant_id = ?",
            [$questionId, $tenantId]
        );
        if (!$question) {
            Response::notFound('Question');
        }
        if ($question['survey_status'] !== 'draft') {
            Response::fail('Questions can only be deleted from draft surveys', 422);
        }

        return Database::execute(
            "DELETE FROM survey_questions WHERE id = ? AND tenant_id = ?",
            [$questionId, $tenantId]
        ) > 0;
    }

    public static function resolveAudienceEmployeeIds(int $tenantId, string $audienceType, ?int $audienceId): array {
        switch ($audienceType) {
            case 'all':
                $rows = Database::fetchAll(
                    "SELECT id FROM employees WHERE tenant_id = ? AND status != 'terminated'",
                    [$tenantId]
                );
                return array_column($rows, 'id');

            case 'branch':
                $rows = Database::fetchAll(
                    "SELECT id FROM employees WHERE tenant_id = ? AND branch_id = ? AND status != 'terminated'",
                    [$tenantId, $audienceId]
                );
                return array_column($rows, 'id');

            case 'category':
                $rows = Database::fetchAll(
                    "SELECT e.id FROM employees e
                     JOIN employee_category_assignments eca ON eca.employee_id = e.id AND eca.category_id = ?
                     WHERE e.tenant_id = ? AND e.status != 'terminated'",
                    [$audienceId, $tenantId]
                );
                return array_column($rows, 'id');

            default:
                return [];
        }
    }

    public static function availableForEmployee(int $tenantId, int $employeeId, int $branchId, ?int $categoryId): array {
        $sql = "SELECT s.* FROM surveys s
                WHERE s.tenant_id = ?
                  AND s.status = 'active'
                  AND (
                      s.audience_type = 'all'
                      OR (s.audience_type = 'branch' AND s.audience_id = ?)
                      OR (s.audience_type = 'category' AND s.audience_id = ?)
                  )
                  AND NOT EXISTS (
                      SELECT 1 FROM survey_completions sc WHERE sc.survey_id = s.id AND sc.employee_id = ?
                  )
                ORDER BY s.created_at DESC";

        $surveys = Database::fetchAll($sql, [
            $tenantId,
            $branchId,
            $categoryId ?? 0,
            $employeeId,
        ]);

        foreach ($surveys as &$survey) {
            $survey['questions'] = self::listQuestions((int) $survey['id'], $tenantId);
        }
        unset($survey);

        return $surveys;
    }

    public static function hasResponded(int $surveyId, int $tenantId, int $employeeId): bool {
        $row = Database::fetchOne(
            "SELECT id FROM survey_completions WHERE survey_id = ? AND tenant_id = ? AND employee_id = ?",
            [$surveyId, $tenantId, $employeeId]
        );
        return $row !== null;
    }

    public static function submitResponse(int $surveyId, int $tenantId, ?int $employeeId, array $answers): int {
        $survey = self::findById($surveyId, $tenantId);
        if (!$survey) {
            Response::notFound('Survey');
        }
        if ($survey['status'] !== 'active') {
            Response::fail('Survey is not active', 422);
        }

        $isAnonymous = (int) $survey['is_anonymous'] === 1;
        // One submission per employee regardless of anonymity. For anonymous
        // surveys the employee link is kept only in survey_completions (not in
        // survey_responses), so duplicates are blocked without exposing identity.
        if ($employeeId !== null && self::hasResponded($surveyId, $tenantId, $employeeId)) {
            Response::fail('You have already responded to this survey', 422);
        }

        $questions = self::listQuestions($surveyId, $tenantId);
        $questionMap = [];
        foreach ($questions as $q) {
            $questionMap[(int) $q['id']] = $q;
        }

        $answerMap = [];
        foreach ($answers as $ans) {
            $qId = (int) ($ans['question_id'] ?? 0);
            if (!isset($questionMap[$qId])) {
                Response::fail("Question {$qId} does not belong to this survey", 422);
            }
            $answerMap[$qId] = $ans;
        }

        foreach ($questions as $q) {
            if ((int) $q['is_required'] === 1 && !isset($answerMap[(int) $q['id']])) {
                Response::fail("Question '{$q['question']}' is required", 422);
            }
        }

        foreach ($answerMap as $qId => $ans) {
            $q = $questionMap[$qId];
            $qtype = $q['qtype'];

            if (in_array($qtype, ['enps', 'rating', 'scale'], true)) {
                $value = $ans['value'] ?? null;
                if ($value === null && (int) $q['is_required'] === 1) {
                    Response::fail("Question '{$q['question']}' requires a numeric value", 422);
                }
                if ($value !== null) {
                    $value = (int) $value;
                    if ($qtype === 'enps' && ($value < 0 || $value > 10)) {
                        Response::fail('eNPS value must be between 0 and 10', 422);
                    }
                    if ($qtype === 'rating' && ($value < 1 || $value > 5)) {
                        Response::fail('Rating value must be between 1 and 5', 422);
                    }
                }
            }
        }

        $db = Database::getInstance();
        try {
            $db->beginTransaction();

            $stmt = $db->prepare(
                "INSERT INTO survey_responses (survey_id, tenant_id, employee_id) VALUES (?, ?, ?)"
            );
            $stmt->execute([$surveyId, $tenantId, $isAnonymous ? null : $employeeId]);
            $responseId = (int) $db->lastInsertId();

            foreach ($answerMap as $qId => $ans) {
                $q = $questionMap[$qId];
                $qtype = $q['qtype'];
                $answerValue = null;
                $answerText = null;

                if (in_array($qtype, ['enps', 'rating', 'scale'], true)) {
                    $answerValue = isset($ans['value']) ? (int) $ans['value'] : null;
                } else {
                    $answerText = $ans['text'] ?? null;
                }

                $stmtA = $db->prepare(
                    "INSERT INTO survey_answers (response_id, question_id, tenant_id, answer_value, answer_text) VALUES (?, ?, ?, ?, ?)"
                );
                $stmtA->execute([$responseId, $qId, $tenantId, $answerValue, $answerText]);
            }

            if ($employeeId !== null) {
                $stmtC = $db->prepare(
                    "INSERT IGNORE INTO survey_completions (survey_id, tenant_id, employee_id) VALUES (?, ?, ?)"
                );
                $stmtC->execute([$surveyId, $tenantId, $employeeId]);
            }

            $db->commit();
            return $responseId;
        } catch (Throwable $e) {
            $db->rollBack();
            error_log('Survey submit error: ' . $e->getMessage());
            Response::fail('Failed to submit response', 500);
        }
    }

    public static function results(int $surveyId, int $tenantId): array {
        $survey = self::findById($surveyId, $tenantId);
        if (!$survey) {
            return [];
        }

        $questions = self::listQuestions($surveyId, $tenantId);
        $totalResponses = (int) Database::fetchOne(
            "SELECT COUNT(*) AS cnt FROM survey_responses WHERE survey_id = ? AND tenant_id = ?",
            [$surveyId, $tenantId]
        )['cnt'] ?? 0;

        $results = [];
        foreach ($questions as $q) {
            $qId = (int) $q['id'];
            $qtype = $q['qtype'];
            $entry = [
                'question_id' => $qId,
                'question' => $q['question'],
                'qtype' => $qtype,
            ];

            if (in_array($qtype, ['enps', 'rating', 'scale'], true)) {
                $agg = Database::fetchOne(
                    "SELECT COUNT(*) AS cnt, AVG(answer_value) AS avg_value, MIN(answer_value) AS min_value, MAX(answer_value) AS max_value
                     FROM survey_answers WHERE question_id = ? AND tenant_id = ? AND answer_value IS NOT NULL",
                    [$qId, $tenantId]
                );
                $entry['responses'] = (int) ($agg['cnt'] ?? 0);
                $entry['average'] = $agg['avg_value'] !== null ? round((float) $agg['avg_value'], 2) : null;
                $entry['min'] = $agg['min_value'] !== null ? (int) $agg['min_value'] : null;
                $entry['max'] = $agg['max_value'] !== null ? (int) $agg['max_value'] : null;

                if ($qtype === 'rating') {
                    $distribution = Database::fetchAll(
                        "SELECT answer_value, COUNT(*) AS cnt FROM survey_answers WHERE question_id = ? AND tenant_id = ? AND answer_value IS NOT NULL GROUP BY answer_value ORDER BY answer_value",
                        [$qId, $tenantId]
                    );
                    $entry['distribution'] = $distribution;
                }
            } else {
                $textAnswers = Database::fetchAll(
                    "SELECT answer_text FROM survey_answers WHERE question_id = ? AND tenant_id = ? AND answer_text IS NOT NULL",
                    [$qId, $tenantId]
                );
                $entry['responses'] = count($textAnswers);
                $entry['answers'] = array_column($textAnswers, 'answer_text');
            }

            $results[] = $entry;
        }

        $enps = null;
        foreach ($questions as $q) {
            if ($q['qtype'] === 'enps') {
                $enps = self::enpsScore((int) $q['id'], $tenantId);
                break;
            }
        }

        return [
            'survey' => $survey,
            'total_responses' => $totalResponses,
            'questions' => $results,
            'enps_score' => $enps,
        ];
    }

    public static function enpsScore(int $questionId, int $tenantId): ?array {
        $rows = Database::fetchAll(
            "SELECT answer_value FROM survey_answers WHERE question_id = ? AND tenant_id = ? AND answer_value IS NOT NULL",
            [$questionId, $tenantId]
        );

        if (empty($rows)) {
            return null;
        }

        $promoters = 0;
        $passives = 0;
        $detractors = 0;
        foreach ($rows as $row) {
            $v = (int) $row['answer_value'];
            if ($v >= 9) {
                $promoters++;
            } elseif ($v >= 7) {
                $passives++;
            } else {
                $detractors++;
            }
        }

        $n = count($rows);
        $score = $n > 0 ? round((($promoters - $detractors) / $n) * 100) : 0;

        return [
            'promoters' => $promoters,
            'passives' => $passives,
            'detractors' => $detractors,
            'score' => $score,
            'n' => $n,
        ];
    }

    public static function broadcastNotifications(
        int $tenantId,
        int $surveyId,
        string $title,
        ?string $titleAr,
        array $employeeIds
    ): void {
        if (empty($employeeIds)) {
            return;
        }

        $body = 'A new survey is available';
        $bodyAr = 'استبيان جديد متاح';
        $dataJson = json_encode(['kind' => 'survey', 'survey_id' => $surveyId], JSON_UNESCAPED_UNICODE);
        $batchSize = 500;
        $chunks = array_chunk($employeeIds, $batchSize);

        foreach ($chunks as $chunk) {
            $placeholders = [];
            $params = [];
            foreach ($chunk as $empId) {
                $placeholders[] = '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';
                $params[] = $tenantId;
                $params[] = null;
                $params[] = $empId;
                $params[] = 'general';
                $params[] = $title;
                $params[] = $titleAr;
                $params[] = $body;
                $params[] = $bodyAr;
                $params[] = $dataJson;
                $params[] = 'in_app';
            }
            Database::execute(
                "INSERT INTO notifications (tenant_id, admin_id, employee_id, type, title, title_ar, body, body_ar, data, sent_via) VALUES " . implode(', ', $placeholders),
                $params
            );
        }

        $employeesWithAdmin = Database::fetchAll(
            "SELECT DISTINCT e.admin_id FROM employees e WHERE e.id IN (" . implode(',', array_map('intval', $employeeIds)) . ") AND e.admin_id IS NOT NULL AND e.tenant_id = ?",
            [$tenantId]
        );
        foreach ($employeesWithAdmin as $row) {
            try {
                NotificationService::sendToUser((int) $row['admin_id'], $title, $body, ['kind' => 'survey', 'survey_id' => $surveyId]);
            } catch (Throwable $e) {
                error_log('Survey push error: ' . $e->getMessage());
            }
        }
    }
}

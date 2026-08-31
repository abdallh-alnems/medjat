<?php

declare(strict_types=1);

namespace App\Modules\Audit\Http\Controllers;

use App\Modules\Audit\Domain\AuditFeed;
use App\Shared\Http\ApiResponse;
use App\Support\Value;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Port of api/app/audit/list.php.
 *
 * Every management action across the company, so it is gated behind the same
 * permission as the settings hub: reading it tells you what everybody has been
 * doing.
 */
final class AuditFeedController
{
    public function __invoke(Request $request): JsonResponse
    {
        $tenantId = Value::int($request->attributes->get('tenant_id'));
        $page = max(1, Value::int($request->query('page'), 1));

        $adminId = Value::int($request->query('admin_id'));
        $category = Value::string($request->query('category'));

        $feed = AuditFeed::page(
            $tenantId,
            $page,
            $adminId > 0 ? $adminId : null,
            AuditFeed::CATEGORIES[$category] ?? null,
        );

        $response = [
            'items' => $feed['items'],
            'page' => $page,
            'has_more' => $feed['has_more'],
        ];

        // The actor list changes slowly, so it rides along with the first page
        // and the "filter by who" dropdown costs no extra round trip.
        if ($page === 1) {
            $response['actors'] = AuditFeed::actors($tenantId);
        }

        return ApiResponse::success($response);
    }
}

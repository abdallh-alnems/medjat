<?php

declare(strict_types=1);

namespace App\Http\Controllers\Landing;

use App\Support\Value;
use Illuminate\Contracts\View\View;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Config;

/**
 * Ports of the two deep-link landing pages at the old backend's root:
 * join.php and join_team.php.
 *
 * Neither is really a page — they are the fallback for an app link that landed
 * somewhere the app could not take it. On a phone with the app installed,
 * Android App Links and iOS Universal Links open it directly and nothing here
 * renders. What arrives instead is a desktop browser, or a phone that has not
 * installed the app yet, and the only useful thing to do is point them at it.
 *
 * No authentication, and nothing sensitive shown. The token or code stays in
 * the URL for the app to pick up after installing; it is already a secret the
 * visitor is holding, and neither page will tell them whether it is a real one
 * beyond whether it is well-formed.
 */
final class JoinLinkController
{
    /** An employee activation token: hex, as ActivationCode issues them. */
    private const TOKEN_PATTERN = '/^[a-f0-9]{16,64}$/i';

    /** An invitation code: eight hex characters, but stay tolerant. */
    private const CODE_PATTERN = '/^[A-Za-z0-9]{4,32}$/';

    /** The employee app's join link. */
    public function employee(Request $request): View
    {
        $token = trim(Value::string($request->query('token')));

        return view('landing.join-employee', [
            'title' => 'الانضمام إلى Medjat',
            'heading' => 'تطبيق Medjat للموظفين',
            'valid' => $token !== '' && preg_match(self::TOKEN_PATTERN, $token) === 1,
            'android' => Config::string('medjat.stores.employee_android'),
            'ios' => Config::string('medjat.stores.employee_ios'),
        ]);
    }

    /**
     * The management app's team-invitation link.
     *
     * Email clients only allow http(s), so the invitation email points here and
     * this page bridges into the app's custom scheme.
     */
    public function team(Request $request): View
    {
        $code = trim(Value::string($request->query('code')));
        $valid = $code !== '' && preg_match(self::CODE_PATTERN, $code) === 1;

        $webBase = rtrim(Config::string('medjat.web.base_url'), '/');

        return view('landing.join-team', [
            'title' => 'الانضمام إلى الفريق على Medjat',
            'heading' => 'دعوة للانضمام إلى الفريق',
            'valid' => $valid,
            'code' => $code,
            'appUrl' => $valid ? 'medjatcentral://join?code='.rawurlencode($code) : '',
            'webUrl' => $valid && $webBase !== '' ? $webBase.'/onboarding?code='.rawurlencode($code) : '',
            'android' => Config::string('medjat.stores.central_android'),
            'ios' => Config::string('medjat.stores.central_ios'),
        ]);
    }
}

{{--
    Branded transactional auth email, bilingual and RTL-first.

    Written as an inline-styled table on purpose: email clients strip <style>
    blocks and have no flexbox, so this is one of the few places where the 2005
    layout is the correct one rather than a legacy.

    The button links to Firebase's own action page; only the presentation around
    it belongs to us.
--}}
@php
    $isEnglish = $lang === 'en';
    $dir = $isEnglish ? 'ltr' : 'rtl';
    $align = $isEnglish ? 'left' : 'right';
    $brand = '#0E7C86'; // faience teal — the same brand token the apps and web use
    $fonts = "'IBM Plex Sans Arabic',-apple-system,Segoe UI,Tahoma,Arial,sans-serif";
@endphp
<div dir="{{ $dir }}" style="margin:0;padding:0;background:#f4f6f8;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f8;padding:32px 12px;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06);">

    <tr><td align="center" style="padding:32px 32px 8px;">
        @if ($logoUrl !== '')
            <img src="{{ $logoUrl }}" alt="{{ $appName }}" style="height:48px;width:auto;display:inline-block;" />
        @else
            <span style="font-size:24px;font-weight:700;color:{{ $brand }};">{{ $appName }}</span>
        @endif
    </td></tr>

    <tr><td style="padding:16px 32px 8px;direction:{{ $dir }};text-align:{{ $align }};font-family:{{ $fonts }};">
        <h1 style="margin:0 0 12px;font-size:20px;color:#1a1a1a;">{{ $title }}</h1>
        @if ($greeting !== '')
            <p style="margin:0 0 8px;font-size:15px;color:#444;line-height:1.7;">{{ $greeting }}</p>
        @endif
        <p style="margin:0 0 24px;font-size:15px;color:#444;line-height:1.7;">{{ $intro }}</p>
    </td></tr>

    <tr><td align="center" style="padding:0 32px 28px;">
        <a href="{{ $link }}" style="display:inline-block;background:{{ $brand }};color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 36px;border-radius:10px;font-family:{{ $fonts }};">{{ $button }}</a>
    </td></tr>

    <tr><td style="padding:20px 32px 32px;border-top:1px solid #eef0f2;direction:{{ $dir }};text-align:{{ $align }};font-family:{{ $fonts }};">
        <p style="margin:0 0 6px;font-size:12px;color:#aaa;line-height:1.6;">{{ $ignore }}</p>
        <p style="margin:0;font-size:12px;color:#bbb;">{{ $appName }}</p>
    </td></tr>

</table>
</td></tr>
</table>
</div>

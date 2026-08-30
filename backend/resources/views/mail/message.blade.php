{{--
    The shared chrome for transactional mail that is not the auth-action pair.

    An inline-styled table on purpose, for the same reason as auth-action.blade:
    email clients strip <style> blocks and have no flexbox, so the 2005 layout
    is the correct one here rather than a legacy.

    Everything below the title is optional, which is what lets one view serve
    both an invitation (a code and a button) and a security notice (a details
    table and no button at all). A third near-identical file is where these
    start drifting apart visually.
--}}
@php
    $dir = ($lang ?? 'ar') === 'en' ? 'ltr' : 'rtl';
    $align = $dir === 'ltr' ? 'left' : 'right';
    $brand = '#0E7C86'; // faience teal — the same brand token the apps and web use
    $fonts = "'IBM Plex Sans Arabic',-apple-system,Segoe UI,Tahoma,Arial,sans-serif";
@endphp
<div dir="{{ $dir }}" style="margin:0;padding:0;background:#f4f6f8;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f6f8;padding:32px 12px;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 2px 12px rgba(0,0,0,0.06);">

    <tr><td align="center" style="padding:32px 32px 8px;">
        @if (($logoUrl ?? '') !== '')
            <img src="{{ $logoUrl }}" alt="{{ $appName }}" style="height:48px;width:auto;display:inline-block;" />
        @else
            <span style="font-size:24px;font-weight:700;color:{{ $brand }};">{{ $appName }}</span>
        @endif
    </td></tr>

    <tr><td style="padding:16px 32px 8px;direction:{{ $dir }};text-align:{{ $align }};font-family:{{ $fonts }};">
        <h1 style="margin:0 0 12px;font-size:20px;color:#1a1a1a;">{{ $title }}</h1>
        <p style="margin:0 0 20px;font-size:15px;color:#444;line-height:1.7;">{{ $intro }}</p>
    </td></tr>

    @if (($code ?? '') !== '')
        {{-- Shown as well as the button: the link can be swallowed by a mail
             client or an app-less device, and the code can always be typed. --}}
        <tr><td align="center" style="padding:0 32px 20px;">
            <div style="display:inline-block;background:#f4f6f8;border:1px dashed #cbd3d8;border-radius:12px;padding:16px 28px;">
                <span style="font-family:'SF Mono',Menlo,Consolas,monospace;font-size:26px;font-weight:700;letter-spacing:4px;color:{{ $brand }};">{{ $code }}</span>
            </div>
        </td></tr>
    @endif

    @if (($rows ?? []) !== [])
        <tr><td style="padding:0 32px 20px;direction:{{ $dir }};text-align:{{ $align }};font-family:{{ $fonts }};">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-size:14px;color:#555;">
                @foreach ($rows as $label => $value)
                    <tr>
                        <td style="padding:6px 0;font-weight:600;white-space:nowrap;">{{ $label }}</td>
                        <td style="padding:6px 0;">{{ $value }}</td>
                    </tr>
                @endforeach
            </table>
        </td></tr>
    @endif

    @if (($link ?? '') !== '' && ($button ?? '') !== '')
        <tr><td align="center" style="padding:0 32px 28px;">
            <a href="{{ $link }}" style="display:inline-block;background:{{ $brand }};color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 36px;border-radius:10px;font-family:{{ $fonts }};">{{ $button }}</a>
        </td></tr>
    @endif

    <tr><td style="padding:20px 32px 32px;border-top:1px solid #eef0f2;direction:{{ $dir }};text-align:{{ $align }};font-family:{{ $fonts }};">
        @if (($footnote ?? '') !== '')
            <p style="margin:0 0 6px;font-size:12px;color:#aaa;line-height:1.6;">{{ $footnote }}</p>
        @endif
        <p style="margin:0;font-size:12px;color:#bbb;">{{ $appName }}</p>
    </td></tr>

</table>
</td></tr>
</table>
</div>

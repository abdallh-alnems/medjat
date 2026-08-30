{{-- Only listings that have been published: an empty URL is an app that has no
     store page yet, and a dead link is worse than none. --}}
<div class="stores">
    @if ($android !== '')
        <a href="{{ $android }}">تحميل من Google Play</a>
    @endif
    @if ($ios !== '')
        <a href="{{ $ios }}">تحميل من App Store</a>
    @endif
</div>

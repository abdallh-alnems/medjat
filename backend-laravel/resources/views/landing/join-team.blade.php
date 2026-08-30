@extends('landing.layout')

@section('body')
    @if ($valid)
        <p>اضغط الزر أدناه لفتح تطبيق Medjat للإدارة والانضمام إلى الشركة. إن لم يفتح التطبيق تلقائيًا، استخدم رمز الدعوة:</p>

        {{-- Shown as well as the button: a custom-scheme link is silently
             dropped by some in-app browsers, and the code can always be typed. --}}
        <div class="code">{{ $code }}</div>

        <a class="btn" href="{{ $appUrl }}">فتح التطبيق والانضمام</a>

        @if ($webUrl !== '')
            <a class="btn alt" href="{{ $webUrl }}">فتح من المتصفح</a>
        @endif

        @include('landing.stores', ['android' => $android, 'ios' => $ios])

        <p class="muted">إن لم يكن لديك حساب بعد، ثبّت التطبيق وأنشئ حسابًا بنفس بريدك الإلكتروني، وستظهر لك الدعوة تلقائيًا.</p>

        <script>
            // Hand off to the app straight away, which is what happens on most
            // mobile browsers. The button stays for the ones where it does not.
            (function () {
                var url = @json($appUrl);
                if (url) { setTimeout(function () { window.location.href = url; }, 300); }
            })();
        </script>
    @else
        <p>رابط الدعوة غير صالح أو منتهي. اطلب دعوة جديدة من إدارة الشركة.</p>
        @include('landing.stores', ['android' => $android, 'ios' => $ios])
    @endif
@endsection

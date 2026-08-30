@extends('landing.layout')

@section('body')
    @if ($valid)
        <p>لإكمال تسجيل الدخول، افتح هذا الرابط من على هاتفك بعد تثبيت التطبيق، وسيتم تسجيل دخولك تلقائياً.</p>
    @else
        <p>رابط التفعيل غير صالح أو منتهي. اطلب رابطاً جديداً من إدارة الشركة.</p>
    @endif

    @include('landing.stores', ['android' => $android, 'ios' => $ios])
@endsection

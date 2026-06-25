# Medjat Central Web — سجل الإصلاحات

كل الإصلاحات اللي اتعملت عشان الموقع (`medjat_central_web`) يشتغل على الـ backend الحي ويطابق التطبيق.

## 1) تسجيل الدخول ما كانش بيثبت
- **السبب:** الـ backend بيغلّف كل رد ناجح في `{ status:"success", data:{...} }`، بينما الـ frontend متوقّع رد مسطّح.
- **الإصلاح:** `src/lib/api/client.ts` — interceptor بيفك الغلاف ويرفع `data`.

## 2) شكل بيانات الـ Dashboard مختلف
- **السبب:** الـ backend بيرجّع `branch_stats` / `present_today` / `payroll_summary`، والـ frontend متوقّع `branch_comparison` / `present` / `payroll`.
- **الإصلاح:** adapter في `src/lib/api/dashboard.ts` يحوّل الرد لشكل `DashboardOverview`، وتوسعة النوع في `src/lib/types/dashboard.ts`.

## 3) خطأ 400 "Tenant ID required" بعد الـ refresh
- **السبب:** هيدر `X-Tenant-Id` ما كانش بيتبعت لما الـ tenant store فاضي.
- **الإصلاح:** `client.ts` بيرجع لـ `user.tenantId` من auth store. + `use-dashboard.ts` بيرمي خطأ على الرد غير الصالح فيعمل react-query retry.

## 4) خطأ Performance "'Home' negative time stamp"
- **السبب:** الصفحة الجذر `/` كانت component بيرمي `redirect()`.
- **الإصلاح:** نقل التحويل `/ → /login` لمستوى الـ routing في `next.config.ts`.

## 5) الصفحة بتظهر فاضية (Service Worker)
- **السبب:** SW بنظام cache-first بيخدم HTML قديم بيشاور على JS اختفى.
- **الإصلاح:** `src/lib/providers/pwa-provider.tsx` — ما يسجّلش SW في التطوير ويمسح القديم. + `public/sw.js` بقى network-first للصفحات (cache نسخة v3).
- **مرة واحدة في المتصفح:** DevTools → Application → Clear site data ثم Hard Reload.

## 6) الجلسة الواحدة النشطة (single active session)
- **المطلوب:** لما تدخل من جهاز تاني، الجهاز القديم يخرج تلقائيًا.
- **الإصلاح:** `client.ts` بيكتشف رد 401 + `error_code: session_superseded` → Firebase signOut + مسح stores + تحويل لـ `/login` + تنبيه.

## 7) زر تبديل اللغة + سبينر تسجيل الخروج
- زر اللغة بقى نص (عربي/English) بدل الأيقونة — `topbar.tsx`.
- زر تسجيل الخروج بيظهر سبينر أثناء العملية — `topbar.tsx`.

## 8) الصفحة الرئيسية بقت زي التطبيق
- `src/app/(app)/dashboard/page.tsx` اتعاد بناؤها: تحية + تاريخ، شبكة حضور بالنِسب، قسم "يحتاج انتباه" (إجازات/راحات/**سلف**/**عُهد**/مستندات) + حالة "كله تمام"، المالية، **أداء الفروع** (`src/components/dashboard/branch-performance.tsx`).
- **كل البطاقات بقت قابلة للضغط** وبتنقل لصفحتها (حضور→/attendance، إجازة→/leaves، سلف→/loans، عُهد→/settings/assets، مالية→/payroll، فرع→/branches).

## 9) تحصين صفحات القائمة الجانبية ضد الكراش
- `terminated` كان بيقع لو الرد مش مصفوفة → اتحصّن بـ `Array.isArray`.

## 10) تطابق شكل البيانات لكل صفحات الـ drawer (الـ adapters)
- **السبب الجذري:** الـ backend بيغلّف كل قائمة في مفتاح علوي داخل الـ envelope (`items` / `branches` / `breaks` / `records` / `tickets` / `categories` …)، فبعد فك الـ envelope بيوصل للصفحة **object مش array**، والصفحات بتعمل `Array.isArray(data) ? data : []` → القائمة بتظهر **فاضية** (مش بتقع، بس بدون بيانات).
- **الإصلاح:** helper موحّد `unwrapList()` في `src/lib/api/client.ts` بيطلّع الـ array من أي مفتاح معروف، وبيرجّع `[]` لأي رد خطأ/صلاحية مرفوضة عشان الصفحة ما تقعش أبدًا. اتطبّق على كل دوال الـ list في طبقة الـ api:
  - **الموظفين** (`employees.ts`): `listEmployees` (طُبّع لـ `{data}`)، `listTerminated`، `getExpiringCompliance`، و `getEmployeeProfile` (بيفك `employee`).
  - **الحضور** (`attendance.ts`): `getBranchAttendance` (مفتاح `records`).
  - **الإجازات** (`leaves.ts`): `listLeaves`، `listCarryoverPolicies`، `listEncashments`.
  - **الراحات** (`breaks.ts`): `listBreaks` (مفتاح `breaks`).
  - **الرواتب** (`payroll.ts`): `listSlips`، `getLivePayroll`، `getPayrollAudit`.
  - **السلف** (`loans.ts`): `listLoans`، `getLoan` (بيفك `loan`).
  - **الفروع/الورديات** (`branches.ts`): `listBranches` (مفتاح `branches`)، `getBranch`، `listShifts`.
  - **التقارير** (`reports.ts`): adapter `toReportData` بيحوّل `{items, summary}` لشكل `ReportData` (columns/rows) + التقارير المستندية (`document-reports.ts`).
  - **سجل النشاط** (`audit.ts`): `listAudit`.
  - **الفريق** (`managers.ts`): `listAdmins`، `listInvitations`.
  - **الدعم** (`support.ts`): `listTickets` (مفتاح `tickets`)، `listMessages` (مفتاح `messages`).
  - **الإعدادات**: `categories.ts` (`listCategories`/`listAssets`)، `settings.ts` + `deductions.ts` (`getDeductionRules` مفتاح `rules`)، `required-documents.ts`.
  - تفاصيل إضافية: `allowances.ts`، `documents.ts`، `performance.ts`، `notifications.ts`، `bulk-adjustments.ts` (`getBulkAdjustment` بيفرد `batch`+`members`)، `settlements.ts` (تسوية نهاية الخدمة).
- **الاختبارات:** عقود الـ contract (`tests/contract/*`) اتحدّثت عشان العقد الجديد = دوال الـ list دايمًا بترجّع array (مع رفض الصلاحية بترجّع `[]`). **كل الاختبارات (98) ناجحة + `tsc` و `eslint` نضاف.**

---

## ⏳ متبقّي — فجوات في الـ backend (مش مشكلة شكل بيانات)
1. **سجل الإنذارات (warnings):** الـ frontend بينده `app/employees/get_warnings.php` — **الـ endpoint ده مش موجود في الـ backend** (بيرجّع 404)، فالـ tab بيفضل فاضي. محتاج endpoint جديد في الـ backend (الإنذارات موجودة فعليًا داخل رد `get_profile.php` لو حبينا نعيد التوجيه له بدل endpoint جديد).
2. **تسوية نهاية الخدمة (settlement):** الـ backend بيرجّع تفاصيل (`gratuity_amount` / `leave_encashment` / `net_amount` …) بينما واجهة الصفحة بتعرض gratuity / leave_encashment / **dues** / total. عملنا mapping متّسق حسابيًا (`dues = total − gratuity − leave_encashment`)، **لكن محتاج تأكيد المعنى المقصود لـ "dues"** قبل الاعتماد عليه في أرقام مالية.

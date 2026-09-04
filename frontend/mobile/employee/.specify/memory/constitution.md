<!--
SYNC IMPACT REPORT
==================
Version change: (template placeholders) → 1.0.0
Change type: MAJOR (initial ratification — first concrete principles replacing template)

Modified principles: none (initial draft)
Added principles:
  - I. Arabic RTL First (NON-NEGOTIABLE)
  - II. MVVM with GetX (NON-NEGOTIABLE)
  - III. Unified API Layer
  - IV. Observable by Default
  - V. Responsive UI & Scoped Permissions
Added sections: Technology Constraints · Development Workflow · Governance
Removed sections: none

Templates sync status:
  ✅ .specify/templates/constitution-template.md — updated with Permedjat-style examples
  ✅ .specify/templates/plan-template.md — Constitution Check references the 5 principles; Technical Context pre-filled with Permedjat stack
  ✅ .specify/templates/spec-template.md — Arabic RTL + mobile context; no principle conflicts
  ✅ .specify/templates/tasks-template.md — MVVM phases and Farkha paths; no principle conflicts
  ✅ .specify/templates/checklist-template.md — RTL/theme/observability gates aligned
  ✅ .specify/templates/agent-file-template.md — references actual project layout

Runtime guidance sync:
  ✅ CLAUDE.md — already reflects MVVM + GetX + CRUD + Arabic conventions
  ✅ AGENTS.md — consistent (expanded version of CLAUDE.md)
  ⚠ README.md — not reviewed in this pass; update if it cites principles

Deferred TODOs: none
-->

# Permedjat App Constitution

تطبيق Flutter. تُوجّه هذه الوثيقة كل خطط المزايا، والـ reviews، وقرارات الهندسة داخل `frontend/mobile/employee/` ومشاريعها المصاحبة (`backend_permedjat/`). ما يُذكر هنا MUST يُحترم؛ أي انحراف يُوثَّق في `plan.md → Complexity Tracking`.

## Core Principles

### I. Arabic RTL First (NON-NEGOTIABLE)

الواجهة العربية RTL هي الأساس، لا خيار إضافي. كل شاشة/ويدجت/نص جديد MUST:

- يستخدم `EdgeInsetsDirectional` و `AlignmentDirectional` بدلاً من المتغيرات غير الاتجاهية.
- يحترم `TextDirection.rtl` افتراضياً (عبر `MaterialApp.locale` أو `Directionality`).
- يستخدم خط Cairo المعرَّف في `pubspec.yaml` لكل النصوص العربية.
- يُختبر بصرياً على RTL قبل أي merge — أي layout معكوس = bug.
- يحصر النصوص الإنجليزية في أسماء الكود والرموز التقنية؛ لا نصوص ظاهرة للمستخدم بالإنجليزية.

**Rationale**: جميع المستخدمين ناطقون بالعربية ويتعاملون مع الأجهزة بإعدادات RTL. أي تسرّب للإنجليزية أو layout معكوس يُفقد الثقة فوراً.

### II. MVVM with GetX (NON-NEGOTIABLE)

الفصل بين الطبقات صارم ولا يُتجاوز. الكود الجديد MUST يلتزم بالخريطة التالية:

- **Controllers** (`lib/logic/controller/`): تمتد `GetxController`؛ تحمل الحالة ومنطق العمل. لا HTTP مباشر ولا Widgets.
- **Views** (`lib/view/screen/`, `lib/view/widget/`): تستهلك الـ controllers عبر `GetBuilder` أو `Obx`. لا منطق عمل ولا استدعاءات API.
- **Data Sources** (`lib/data/data_source/remote/`): كل endpoint داخل class مستقل يستخدم `CRUD` من `core/class/crud.dart`.
- **Models** (`lib/data/model/`): POJOs لتحويل JSON ↔ Dart مع suffix `Model`.
- **Bindings** (`lib/logic/bindings/`): حقن التبعيات عبر `Get.put` / `Get.lazyPut`؛ كل route له Binding أو يستخدم `AppBindings`.
- ممنوع `setState` في widgets مرتبطة بـ controllers — الحالة تُدار عبر GetX.

**Rationale**: الفصل الصارم يُبقي الـ codebase قابل للتوسّع والاختبار، ويمنع انفجار النمط إلى "widgets فيها API calls".

### III. Unified API Layer

كل استدعاءات HTTP MUST تمر عبر `CRUD` (`core/class/crud.dart`):

- لا استخدام مباشر لـ `http.get` / `http.post` خارج `lib/data/data_source/remote/`.
- الاستجابات تُعالَج عبر `StatusRequest` enum و `HandlingData` widget.
- الـ endpoints تُعرَّف في `core/constant/` (routes/api)؛ لا hard-coded URLs داخل الـ controllers أو الـ views.
- الـ PHP backend في `backend_permedjat/app/` — كل endpoint في ملف منفصل، الـ queries في `backend_permedjat/core/queries/`.

**Rationale**: طبقة واحدة = مكان واحد لإضافة headers، معالجة أخطاء، retry، analytics. تغيير URL أو إضافة auth header يجب أن يلمس ملفاً واحداً لا عشرة.

### IV. Observable by Default

كل مسار حرج (auth, cycle mutation, payment, deep-link, remote config) MUST:

- يُسجَّل في Firebase Analytics عبر `AnalyticsService` (`core/services/analytics_service.dart`).
- يُبلَّغ عن أخطائه لـ Firebase Crashlytics داخل `try/catch` مع `FirebaseCrashlytics.instance.recordError(error, stack)`.
- يحترم حالة الاتصال عبر `InternetController` قبل العمليات الشبكية؛ بدون اتصال ⇒ رسالة واضحة بالعربية + لا exception صامت.
- القرارات التي تتطلب تحكماً عن بعد تستخدم Firebase Remote Config، لا ثوابت مطبوعة في الكود.

**Rationale**: التطبيق منشور لمستخدمين حقيقيين؛ بدون observability يستحيل الكشف عن regressions قبل مراجعات المتجر السلبية.

### V. Responsive UI & Scoped Permissions

الواجهات تعمل على أحجام شاشات متعددة، والأذونات تُطلب بمسؤولية:

- الأبعاد MUST تستخدم `flutter_screenutil` (`.w`, `.h`, `.sp`, `.r`). ممنوع hard-coded `double` للأبعاد.
- `ScreenUtilInit` يغلّف التطبيق في `main.dart`.
- الأذونات (Location, Notifications, Contacts, Camera) MUST تُطلب just-in-time عبر `core/services/permission.dart` مع تفسير عربي واضح.
- الميزات التي تتطلب إذناً MUST توفّر مسار fallback graceful عند الرفض — لا crash ولا شاشة بيضاء.
- الـ UI MUST يدعم light و dark mode عبر `DarkLightService`؛ ممنوع `Colors.black` / `Colors.white` hard-coded خارج theme tokens.

**Rationale**: جمهور التطبيق متنوع الأجهزة (من Android 23 الاقتصادية إلى أحدث iPhones). التطبيق لا يستحق ثقة المستخدم إذا ظهرت شاشة تالفة أو طلب إذن مبهم.

## Technology Constraints

**Stack مُحدَّد**: Flutter 3.7.2+ / Dart 3.7.2+ · GetX 4.7.2 · Firebase (Core/Auth/Analytics/Crashlytics/Messaging/Remote Config/App Check) · PHP REST backend. لا يُضاف state-management أو HTTP client بديل (Riverpod, Bloc, Provider, Dio, Chopper) دون تعديل هذا الدستور بـ PR منفصل.

**الاعتمادات**:

- إضافة أي package في `pubspec.yaml` MUST تُبرَّر في `plan.md → Complexity Tracking` لتلك الميزة.
- يُفضَّل استخدام الحزم المُصانة رسمياً من Flutter/Google/Firebase.
- تجنّب تكرار الوظائف — استخدم القائم (`CRUD`, `HandlingData`, `DarkLightService`, `AnalyticsService`, `permission.dart`) قبل كتابة بديل.
- الـ ads (Google Mobile Ads + Meta mediation) ثابتة في الـ stack؛ أي تغيير فيها يتطلب مراجعة monetization.

**Build & Release**:

- الأسرار في `.env` عبر `flutter_dotenv`؛ ممنوع طباعة secrets في الكود أو في logs.
- build الإنتاج: `flutter build apk --release` أو `flutter build appbundle --release`.
- CI في `.github/workflows/` يُشغّل `flutter analyze` و `flutter test` عند كل PR؛ PR لا يمر إذا فشلا.
- إصدارات جديدة تحدّث `version` في `pubspec.yaml` وفق MAJOR.MINOR.PATCH+BUILD.

## Development Workflow

**قبل البدء**:

- كل ميزة تبدأ بـ `/speckit.specify` → spec واضح بسيناريوهات مرقّمة بالأولوية (P1, P2, P3).
- `/speckit.plan` يُنتج Technical Context و research.md و data-model.md.
- `/speckit.tasks` يُنتج tasks.md مُنظّمة حسب user story.
- `/speckit.implement` ينفّذ المهام بالترتيب، مع احترام gates الدستور في plan.md.

**أثناء التنفيذ**:

- branch واحد لكل ميزة بصيغة `###-feature-name` (يُنشأ عبر hook `speckit.git.feature`).
- الكود يتبع `analysis_options.yaml`؛ `flutter analyze` يمر قبل كل commit.
- commits صغيرة ذات رسائل وصفية (نمط موجود: `feat(...)`, `fix(...)`, `refactor(...)` بالعربية أو الإنجليزية).

**قبل الـ merge**:

- `flutter analyze` و `flutter test` يمران دون تحذيرات حرجة.
- الميزة تُختبر يدوياً على Android (primary) و iOS (secondary) — جهاز واحد على الأقل لكل منصة.
- الـ UI يُتحقّق منه في light و dark mode وعلى إعداد RTL.
- النصوص العربية مراجَعة — لا نصوص إنجليزية متسربة.
- Analytics events + Crashlytics wiring مُختبرَين فعلياً (ظهور الحدث في console Firebase Analytics Debug View).

## Governance

يهيمن هذا الدستور على أي اجتهاد فردي. أي انحراف MUST يُوثَّق في `plan.md → Complexity Tracking` مع:

- السبب الملموس للانحراف (ما المشكلة التي لا تُحلّ بالمسار القياسي؟).
- البديل الأبسط المرفوض وسبب رفضه.

**التعديلات**:

- أي تعديل جوهري (حذف/استبدال مبدأ، تغيير stack, تخفيف gate) يتطلب PR منفصل يعدّل هذا الملف مع `CONSTITUTION_VERSION` بالـ bump المناسب:
  - **MAJOR**: حذف/إعادة تعريف مبدأ بشكل غير متوافق.
  - **MINOR**: إضافة مبدأ/قسم أو توسعة مادية.
  - **PATCH**: توضيح لغوي، تصحيح إملائي، تنقيح غير دلالي.
- الدستور يُراجَع كل release رئيسي (MAJOR في `pubspec.yaml`).

**في حالة التعارض**:

- Constitution > CLAUDE.md > AGENTS.md > اجتهاد لحظي.
- عند الشك، اسأل مالك المشروع (abdallhmoustafa295@gmail.com).

**Version**: 1.0.0 | **Ratified**: 2026-04-18 | **Last Amended**: 2026-04-18

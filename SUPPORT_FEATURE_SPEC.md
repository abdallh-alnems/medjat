# مواصفة ميزة: خدمة الدعم (Support / Tickets) — لوحة الإدارة `medjat_central`

> **الغرض من هذا الملف:** وصف دقيق وكامل لميزة الدعم ليقوم نموذج/مطوّر آخر بتنفيذها دون الحاجة لأي توضيح إضافي. اقرأ الملف بالكامل قبل البدء. التزم حرفياً بأنماط المشروع المذكورة هنا.

---

## 0) القرار المعماري (مقروء قبل أي شيء)

- **لا تُستخدم WebSocket.** الـ backend يعمل على استضافة **Hostinger مشتركة (shared hosting، بدون VPS)** لا تسمح بعمليات دائمة التشغيل ولا بفتح بورت للاستماع. WebSocket غير ممكن تقنياً هنا.
- **الحل المعتمد:** `REST (PHP) + FCM (إشعار فوري) + Polling خفيف داخل شاشة المحادثة فقط`.
  - كل البيانات في **MySQL** ضمن نفس نظام الـ multi-tenant والصلاحيات الحالي.
  - عند أي رسالة جديدة، الـ backend يطلق **FCM** للطرف الآخر (البنية موجودة عبر `NotificationService`).
  - شاشة المحادثة المفتوحة فقط تعمل polling كل **5 ثوانٍ** بطلب `?after_id=<lastId>` يجلب الجديد فقط.
- لا تُستخدم Firestore لهذه الميزة (نُبقي البيانات في MySQL ضمن الصلاحيات الحالية).

---

## 1) نطاق الميزة واتجاه المحادثة

**الطرفان:**
1. **مستخدم الإدارة (Admin / tenant user):** يفتح تذاكر دعم ويراسل فريق الدعم من تطبيق `medjat_central`. هذا هو **النطاق الأساسي للتنفيذ في هذا التسليم**.
2. **فريق دعم منصّة Medjat (Super Admin):** يستقبل التذاكر ويرد عليها من واجهة الـ super-admin (موجودة في الـ backend عبر جداول `super_admins` / `super_admin_sessions`).

> ⚠️ **افتراض يحتاج تأكيد المالك:** هذه الميزة مصمّمة على أن الدعم هو قناة **بين إدارة الشركة (العميل) وفريق منصّة Medjat**. إن كان المقصود دعماً *داخلياً* (موظف ↔ مدير داخل نفس الشركة) فالاتجاه يتغيّر — راجع القسم 12 «نقاط القرار» قبل البدء. باقي المواصفة تفترض الاتجاه الأول.

**ما يستطيع مستخدم الإدارة فعله:**
- فتح تذكرة دعم جديدة (موضوع + فئة + أول رسالة، مع إمكانية إرفاق ملف).
- عرض قائمة تذاكره (مع آخر رسالة + حالة + عدّاد غير مقروء).
- فتح تذكرة وقراءة/إرسال الرسائل.
- إغلاق التذكرة أو إعادة فتحها.
- استقبال إشعار FCM عند رد الدعم.

**ما يفعله فريق الدعم (Super Admin):** يُسرد في القسم 7 (Endpoints جانب الدعم). واجهة الـ super-admin قد تكون خارج نطاق هذا التسليم لكن **الـ endpoints الخلفية مطلوبة**.

---

## 2) المنصّة والأنماط الواجب اتباعها (مهم جداً)

### 2.1 Backend — `backend_medjet/`
- PHP REST. كل endpoint = ملف مستقل تحت `app/<module>/<action>.php`.
- **القالب الموحّد لأي endpoint خاص بالإدارة (tenant user):**
  ```php
  <?php
  require_once __DIR__ . '/../../config/bootstrap.php';

  RateLimiter::enforceIpLimit();
  $auth = Auth::authenticateUser(db());            // مستخدم الإدارة
  $tenantId = TenantMiddleware::requireTenant();    // عزل الـ tenant
  PermissionMiddleware::check($auth, 'manage_support'); // الصلاحية (انظر 9)

  $input = $auth['input'];        // body مُحلّل (JSON)
  // ... المنطق ...
  Response::success([...]);       // أو Response::fail('msg', 400) / Response::notFound('X')
  ```
  - مفاتيح `$auth` المتاحة: `$auth['admin_id']`, `$auth['input']` (راجع `app/leaves/create.php`, `app/expenses/create.php` كمرجع حيّ).
- **القالب لأي endpoint خاص بفريق الدعم (super admin):**
  ```php
  <?php
  require_once __DIR__ . '/../../config/bootstrap.php';
  RateLimiter::enforceIpLimit();
  $admin = AdminAuth::require('admin'); // أو 'superadmin' حسب الحاجة
  // $admin['admin_id'], $admin['role']
  ```
  (راجع `core/AdminAuth.php`.)
- التسجيل في التدقيق: `AuditLogModel::log($tenantId, $auth['admin_id'], 'support.x', 'support_ticket', $id, [...])` لجانب الإدارة، و`AdminAuth::logAction(...)` لجانب الدعم.
- استجابة موحّدة عبر `core/Response.php` (`Response::success($payload)` تُرجع `{ status: true, data: {...} }` — راجع التطبيق الفعلي).

### 2.2 Frontend — `front_end/medjat_central/` (Flutter + GetX)
طبقات ثابتة يجب اتباعها بالترتيب:
1. **روابط:** `lib/core/constant/id/app_links.dart` — أضف عناوين endpoints الجديدة.
2. **شبكة:** استخدم `CRUD` (موجود، `Get.find<CRUD>()`) عبر `getData/postData/postFile`. لا تكتب http يدوياً. الاستجابة تأتي `{'status': StatusRequest.x, 'data': {...}}`، ولاحظ التداخل `data['data']` (راجع `notification_controller.dart`).
3. **Data source:** `lib/data/data_source/remote/support_data/support_data.dart`.
4. **Model:** `lib/data/model/` (نموذج Ticket + Message).
5. **Controller (GetX):** `lib/logic/controller/support/support_controller.dart`.
6. **Routes:** أضف ثوابت في `lib/core/constant/routes/app_routes.dart`.
7. **Pages + Binding:** سجّل `GetPage` في `lib/core/constant/routes/app_pages.dart` مع `BindingsBuilder` و `middlewares: [AuthMiddleware()]` و `transition: Transition.fadeIn, transitionDuration: AppMotion.transition` (انظر مدخل `AppRoutes.notifications` كنموذج).
8. **Screens:** `lib/view/screen/support/`.
9. **i18n:** أضف مفاتيح الترجمة (ar/en) في ملفات اللغة تحت `lib/core/constant/locale/` و/أو `strings/`.

### 2.3 تفضيل تصميم الشاشات (إلزامي)
الشاشات المزدحمة تُبنى كـ **بطاقة ملخّص أعلى + أقسام قابلة للطي**، مع الإبقاء على كل الميزات. طبّق هذا على شاشة التذكرة إن احتوت بيانات وصفية كثيرة.

---

## 3) قاعدة البيانات

> ### بيئتان لقاعدة البيانات — أي تعديل يُطبَّق على الاثنتين (كلاهما MySQL 8)
> - **التطوير (محلي): MAMP يشغّل MySQL 8.0.44** — العميل `/Applications/MAMP/Library/bin/mysql80/bin/mysql`، الاتصال `127.0.0.1:8889`، root/root، قاعدة `medjat`. الـ Apache DocumentRoot هو نفسه المستودع: `/Users/nims/StudioProjects/Medjat/backend_medjet`. هذه بيئة التطوير الفعلية، **ويجب تطبيق أي migration عليها أولاً ومحلياً**.
> - **الإنتاج: Hostinger** — **MySQL 8** (استضافة مشتركة).
> - النتيجة: البيئتان MySQL 8، فلا حاجة للقلق من توافق 5.7.
>
> ⚠️ **القاعدة الوحيدة المهمة (صيغة MariaDB):**
> - ملف `migrations/schema.sql` يستخدم في أماكن صيغة `ADD COLUMN IF NOT EXISTS` الخاصة بـ **MariaDB فقط** — وهي **تفشل على MySQL 8**، فتبقى تلك التعديلات غير مطبّقة بصمت. **لا تستخدم هذه الصيغة في أي migration جديد** (استخدم `ADD COLUMN` عادي، و`CREATE TABLE IF NOT EXISTS` مقبول).
> - **آلية التعديل لأي تغيير في قاعدة البيانات (إلزامية):**
>   1. أضف التعريف الكامل إلى `migrations/schema.sql` (مرجع للبيئات الجديدة).
>   2. اكتب ملف **migration يدوي منفصل** بصيغة MySQL 8 قياسية (`CREATE TABLE IF NOT EXISTS`, `ALTER TABLE ... MODIFY/ADD COLUMN` بدون `IF NOT EXISTS`).
>   3. **شغّله أولاً على MAMP المحلي** عبر phpMyAdmin أو:
>      `/Applications/MAMP/Library/bin/mysql80/bin/mysql -u root -proot -h 127.0.0.1 -P 8889 medjat < migrations/2026_06_support.sql`
>      ثم على Hostinger في الإنتاج. تحقّق بـ `SHOW COLUMNS FROM <table>`. لا تعتبر التعديل مكتملاً قبل تطبيقه على MAMP.

### 3.1 جدول `support_tickets`
```sql
CREATE TABLE IF NOT EXISTS `support_tickets` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tenant_id` int unsigned NOT NULL,
  `opened_by_admin_id` int unsigned NOT NULL COMMENT 'admins.id who opened it',
  `subject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `category` enum('technical','billing','feature_request','account','other') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'other',
  `priority` enum('low','normal','high','urgent') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'normal',
  `status` enum('open','pending_support','pending_user','resolved','closed') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open',
  `assigned_super_admin_id` int unsigned DEFAULT NULL COMMENT 'super_admins.id handling it',
  `last_message_at` timestamp NULL DEFAULT NULL,
  `last_message_preview` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `unread_for_user` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1 = هناك رد دعم لم يقرأه المستخدم',
  `unread_for_support` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1 = هناك رسالة مستخدم لم يقرأها الدعم',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_support_tickets_tenant` (`tenant_id`,`status`),
  KEY `idx_support_tickets_opened_by` (`opened_by_admin_id`),
  KEY `idx_support_tickets_status` (`status`,`last_message_at`),
  CONSTRAINT `support_tickets_ibfk_1` FOREIGN KEY (`tenant_id`) REFERENCES `tenants` (`id`) ON DELETE CASCADE,
  CONSTRAINT `support_tickets_ibfk_2` FOREIGN KEY (`opened_by_admin_id`) REFERENCES `admins` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### 3.2 جدول `support_messages`
```sql
CREATE TABLE IF NOT EXISTS `support_messages` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `ticket_id` int unsigned NOT NULL,
  `sender_type` enum('user','support','system') COLLATE utf8mb4_unicode_ci NOT NULL,
  `sender_admin_id` int unsigned DEFAULT NULL COMMENT 'admins.id إذا sender_type=user',
  `sender_super_admin_id` int unsigned DEFAULT NULL COMMENT 'super_admins.id إذا sender_type=support',
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `attachment_url` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `attachment_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_support_messages_ticket` (`ticket_id`,`id`),
  CONSTRAINT `support_messages_ibfk_1` FOREIGN KEY (`ticket_id`) REFERENCES `support_tickets` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

> ملاحظة polling: مفتاح `(ticket_id, id)` يخدم استعلام `WHERE ticket_id=? AND id > ? ORDER BY id ASC`.

### 3.3 تعديل enum الإشعارات (اختياري لكن مفضّل)
في جدول `notifications` الحالي، أضف `'support'` إلى قيم العمود `type` ليظهر إشعار الدعم بنوع صحيح:
```sql
ALTER TABLE `notifications`
  MODIFY COLUMN `type` enum('general','attendance','payroll','leave','warning','system','subscription','invite','support')
  COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'general';
```

---

## 4) قواعد منطقية موحّدة (Backend)

- **عزل الـ tenant:** كل استعلام في جانب الإدارة يجب أن يحتوي `AND tenant_id = ?` (مأخوذ من `TenantMiddleware::requireTenant()`). لا تثق بأي `tenant_id` قادم من body.
- **ملكية التذكرة:** مستخدم الإدارة يصل فقط لتذاكر `tenant_id` الخاص به. (سياسة افتراضية: أي admin في نفس الـ tenant يرى تذاكر شركته — راجع نقطة القرار 12-ب إن أردت قصرها على `opened_by_admin_id`.)
- **تحديث ميتاداتا التذكرة عند كل رسالة** (داخل ترانزاكشن واحد مع الإدراج):
  - `last_message_at = NOW()`، `last_message_preview = LEFT(body,255)`.
  - رسالة من مستخدم → `status='pending_support'`, `unread_for_support=1`, `unread_for_user=0`.
  - رسالة من دعم → `status='pending_user'`, `unread_for_user=1`, `unread_for_support=0`.
- **FCM بعد الإدراج:** رسالة دعم → `NotificationService::sendToUser($opened_by_admin_id, title, body, data)` + سجل صف في `notifications`. رسالة مستخدم → إشعار فريق الدعم (انظر القسم 8).
- **التحقق من المدخلات** عبر `core/Validator.php` (موجود): `subject` 3..255، `body` 1..5000، `category`/`priority` ضمن القيم المسموحة.
- **Rate limiting:** `RateLimiter::enforceIpLimit()` في كل endpoint (موجود في القالب).

---

## 5) عقود الـ Endpoints — جانب الإدارة (tenant user)

كلها تحت `backend_medjet/app/support/`. المصادقة: `Auth::authenticateUser` + `TenantMiddleware` + `PermissionMiddleware::check($auth,'manage_support')`.

### 5.1 `GET app/support/list.php` — قائمة تذاكري
**Query:** `status?` (فلتر اختياري), `page?` (افتراضي 1), `limit?` (افتراضي 20، أقصى 50).
**Response:**
```json
{ "status": true, "data": {
  "tickets": [{
    "id": 12, "subject": "...", "category": "technical", "priority": "normal",
    "status": "pending_user", "last_message_at": "2026-06-03 12:00:00",
    "last_message_preview": "...", "unread_for_user": true, "created_at": "..."
  }],
  "total": 34, "page": 1, "unread_total": 2
}}
```

### 5.2 `POST app/support/create.php` — فتح تذكرة
**Body:** `{ "subject": "...", "category": "technical", "priority": "normal", "body": "نص أول رسالة" }`
**المنطق:** أنشئ التذكرة (`status='open'`, `unread_for_support=1`) + أدرج أول `support_messages` (`sender_type='user'`) داخل ترانزاكشن. ثم أشعر الدعم (القسم 8). سجّل audit.
**Response:** `{ "status": true, "data": { "ticket_id": 12 } }`

### 5.3 `GET app/support/messages.php` — رسائل تذكرة (+ polling)
**Query:** `ticket_id` (مطلوب), `after_id?` (اختياري — يجلب فقط `id > after_id` لأجل polling).
**المنطق:** تحقّق أن التذكرة ضمن `tenant_id`. أرجع الرسائل مرتبة `id ASC`. **عند الطلب الكامل (بدون after_id):** علّم `unread_for_user=0` للتذكرة (المستخدم قرأ). عند after_id لا تغيّر شيئاً (مجرد استطلاع).
**Response:**
```json
{ "status": true, "data": {
  "ticket": { "id": 12, "subject": "...", "status": "pending_user", ... },
  "messages": [{
    "id": 101, "sender_type": "support", "body": "...",
    "attachment_url": null, "created_at": "2026-06-03 12:00:00"
  }],
  "last_id": 101
}}
```

### 5.4 `POST app/support/reply.php` — إرسال رسالة من المستخدم
**Body:** `{ "ticket_id": 12, "body": "..." }`
**المنطق:** تحقّق الملكية + أن الحالة ليست `closed` (إن مغلقة: إمّا ارفض أو أعِد الفتح تلقائياً — القرار في 12-ج، الافتراضي: أعِد الفتح إلى `pending_support`). أدرج رسالة + حدّث ميتاداتا + أشعر الدعم.
**Response:** `{ "status": true, "data": { "message_id": 102, "status": "pending_support" } }`

### 5.5 `POST app/support/close.php` — إغلاق/إعادة فتح
**Body:** `{ "ticket_id": 12, "action": "close" | "reopen" }`
**Response:** `{ "status": true, "data": { "status": "closed" } }`

### 5.6 `POST app/support/upload_attachment.php` — رفع مرفق (اختياري ضمن MVP)
رفع متعدد الأجزاء (راجع `core/` و endpoints الرفع الموجودة مثل `app/employees/upload_document.php` و `CRUD.postFile`). يُرجع `{ "url": "...", "name": "..." }` لاستخدامه في `reply/create`. **يمكن تأجيله — انظر القسم 13 (MVP).**

---

## 6) النموذج (Model) في الـ Backend (اختياري لكن مفضّل)
أنشئ `backend_medjet/models/SupportModel.php` يجمع منطق الوصول (create ticket, add message + تحديث الميتاداتا في ترانزاكشن, list, fetch messages, mark read, close) على غرار الموديلات الموجودة (`LeaveModel`, `ExpenseModel`), ثم سجّله في `config/bootstrap.php` ضمن قائمة `require_once` للموديلات. هذا يقلّل التكرار بين endpoints الإدارة والدعم.

---

## 7) عقود الـ Endpoints — جانب فريق الدعم (super admin)
تحت `backend_medjet/app/admin_support/` (أو ما يناسب تنظيم الـ super-admin الحالي). المصادقة: `AdminAuth::require('admin')`.
- `GET list.php` — كل التذاكر عبر كل الـ tenants، فلترة بـ `status`/`tenant_id`/`assigned`, ترتيب بـ `last_message_at DESC`. (لا قيد tenant.)
- `GET messages.php` — رسائل أي تذكرة + يعلّم `unread_for_support=0`.
- `POST reply.php` — `sender_type='support'`, `sender_super_admin_id=$admin['admin_id']`، يحدّث الحالة إلى `pending_user`, `unread_for_user=1`، ويطلق FCM للمستخدم + صف `notifications`.
- `POST assign.php` / `POST set_status.php` — تعيين مسؤول/تغيير الحالة والأولوية.
> إن كانت واجهة الـ super-admin خارج نطاق هذا التسليم، نفّذ على الأقل `reply.php` و `list.php` و `messages.php` حتى تعمل الدورة كاملة.

---

## 8) إشعار فريق الدعم برسائل المستخدم
لا يملك فريق الدعم بالضرورة أجهزة في `admin_devices`. اعتمد إحدى الطريقتين (الافتراضي: **أ + ج**):
- **(أ) صف في `notifications`** بـ `tenant_id=NULL`, `type='support'` (إشعار على مستوى المنصّة يظهر في لوحة الـ super-admin).
- **(ب) FCM** فقط إن كان لدى super admins أجهزة مسجّلة (غالباً لا — لا تعتمد عليه وحده).
- **(ج) بريد إلكتروني** عبر `core/EmailService.php` إلى عنوان دعم ثابت (مثل `support@medjatapp.com`) — موثوق على الاستضافة الحالية.
> راجع `core/NotificationService.php`: الدوال `sendToUser(adminId,...)`, `sendToTenant(tenantId,...)`. لا توجد دالة لإشعار super admins عبر FCM، لذا استخدم (أ)/(ج) لجانب الدعم.

---

## 9) الصلاحيات والأدوار
- أضف صلاحية جديدة **`manage_support`** إلى نظام الصلاحيات (راجع `core/PermissionMiddleware.php` و `app/roles/list_permissions.php` و `models/RoleModel.php`). يجب أن تظهر في قائمة الصلاحيات القابلة للمنح ضمن إدارة الفريق في `medjat_central`.
- نموذج الأدوار: لا يوجد «مالك»؛ `general_manager` أعلى دور ويُمنح لأي شخص، والصلاحية تُطبَّق عبر `PermissionMiddleware` (مبدأ مساوٍ-أو-أقل). افتراضياً امنح `manage_support` لـ `general_manager` تلقائياً.
- جانب الدعم محكوم بـ `AdminAuth` (أدوار `readonly`/`admin`/`superadmin`).

---

## 10) الواجهة الأمامية — تفصيل `medjat_central`

### 10.1 `app_links.dart` — أضف:
```dart
// ── Support ────────────────────────────────────────────
static String get supportTickets => '$base/app/support/list.php';
static String get supportCreate => '$base/app/support/create.php';
static String supportMessages(int ticketId, {int? afterId}) =>
    afterId != null
      ? '$base/app/support/messages.php?ticket_id=$ticketId&after_id=$afterId'
      : '$base/app/support/messages.php?ticket_id=$ticketId';
static String get supportReply => '$base/app/support/reply.php';
static String get supportClose => '$base/app/support/close.php';
```

### 10.2 `support_data.dart` (Data source)
دوال: `listTickets({status, page})`, `createTicket({subject, category, priority, body})`, `getMessages(ticketId, {afterId})`, `reply(ticketId, body)`, `closeTicket(ticketId, action)`. استخدم `Get.find<CRUD>()` تماماً كـ `notification_data.dart`.

### 10.3 `support_controller.dart` (GetX)
- حالة: `tickets`, `messages`, `currentTicket`, `isLoading`, `isSending`, `unreadTotal` (كلها `.obs`).
- `loadTickets()` / `openTicket(id)` (تحميل كامل) / `sendReply(text)` / `createTicket(...)` / `closeTicket(...)`.
- **Polling:** عند فتح شاشة المحادثة شغّل `Timer.periodic(Duration(seconds: 5))` يستدعي `getMessages(ticketId, afterId: lastId)` ويضيف الجديد فقط؛ **أوقف الـ Timer في `onClose()` أو عند مغادرة الشاشة** (تجنّب تسريب الموارد). أوقف الـ polling عندما يكون التطبيق في الخلفية إن أمكن.
- تعامل مع تداخل الاستجابة `data['data']` كما في `notification_controller.dart`، وحالات `StatusRequest.offline/failure`.

### 10.4 الشاشات (`lib/view/screen/support/`)
- `support_tickets_screen.dart` — قائمة التذاكر (الموضوع، آخر رسالة، الحالة كـ chip ملوّن، نقطة «غير مقروء»، زر «تذكرة جديدة» FAB).
- `support_chat_screen.dart` — فقاعات محادثة (يمين/يسار حسب `sender_type`)، حقل إدخال + إرسال، شريط علوي يظهر الموضوع/الحالة، (اختياري: قسم تفاصيل قابل للطي حسب تفضيل التصميم). مؤشّر إرسال.
- `new_ticket_screen.dart` (أو bottom sheet) — موضوع + فئة (dropdown) + أولوية + نص أول رسالة.
- ادعم RTL والترجمة عبر `.tr`. التزم بثيم التطبيق الحالي (`core/constant/theme/`).

### 10.5 Routes + Pages
في `app_routes.dart`:
```dart
static const String support = '/support';
static const String supportChat = '/support/chat';
static const String supportNew = '/support/new';
```
في `app_pages.dart` أضف `GetPage` لكل شاشة مع `BindingsBuilder` يضع `SupportController`, و `middlewares: [AuthMiddleware()]`, و `transition: Transition.fadeIn, transitionDuration: AppMotion.transition` (انظر مدخل `notifications`).

### 10.6 نقطة الدخول
أضف زر «الدعم والمساعدة» في شاشة الإعدادات/الحساب (راجع `view/screen/settings/`) ينتقل إلى `AppRoutes.support`، مع شارة عدد غير المقروء إن وُجد.

### 10.7 ربط FCM بالتنقّل
عند وصول إشعار `type=support` مع `data: { ticket_id }`، يفتح التطبيق `supportChat` للتذكرة المعنية. راجع خدمة الإشعارات الموجودة في `lib/core/services/` (push_notification_service) لربط الـ deep handling.

---

## 11) خطوات النشر اليدوي (إلزامية)
الـ migration يجب أن يعمل على **بيئتين كلاهما MySQL 8**: MAMP محلياً (MySQL 8.0.44) وHostinger إنتاجاً. تجنّب فقط صيغة MariaDB (راجع القسم 3).
1. أنشئ ملف migration يدوي (مثلاً `backend_medjet/migrations/2026_06_support.sql`) يحتوي **فقط** على `CREATE TABLE IF NOT EXISTS` للجدولين + `ALTER TABLE notifications ... MODIFY` (القسم 3.3)، بدون أي صيغة MariaDB.
2. **شغّله أولاً على MAMP المحلي** وتأكّد أنه يمر بلا أخطاء — هذه بيئة التطوير الفعلية:
   `/Applications/MAMP/Library/bin/mysql80/bin/mysql -u root -proot -h 127.0.0.1 -P 8889 medjat < migrations/2026_06_support.sql`
3. ثم شغّله على القاعدة الحيّة عبر phpMyAdmin/CLI في Hostinger.
4. حدّث أيضاً `migrations/schema.sql` (للمرجع وللبيئات الجديدة).
5. تأكّد أن FCM service account مفعّل (موجود — `config/firebase.php`).
6. (إن استُخدم البريد) تأكّد من ضبط عنوان دعم في إعدادات `EmailService`.

---

## 12) نقاط قرار يجب تأكيدها مع المالك قبل البدء
- **(أ) اتجاه الدعم:** عميل ↔ منصّة Medjat (الافتراضي في هذه المواصفة) أم دعم داخلي داخل الشركة؟ يغيّر هوية الطرف الثاني وجداول/مصادقة الردود.
- **(ب) رؤية التذاكر:** هل يرى كل admins نفس الشركة كل تذاكر الشركة، أم كل admin يرى تذاكره فقط (`opened_by_admin_id`)؟ الافتراضي: على مستوى الشركة.
- **(ج) الرسالة على تذكرة مغلقة:** إعادة فتح تلقائي (الافتراضي) أم رفض؟
- **(د) المرفقات:** ضمن MVP أم مرحلة لاحقة؟ الافتراضي: مرحلة لاحقة.

---

## 13) نطاق MVP مقابل لاحقاً
**MVP (سلّم أولاً):** الجداول + endpoints الإدارة (5.1–5.5) + FCM للمستخدم + إشعار الدعم بالبريد/`notifications` + شاشات الإدارة الثلاث + polling. صلاحية `manage_support`.
**لاحقاً:** المرفقات (5.6)، واجهة super-admin كاملة (7)، الأولوية/التعيين، مؤشّر «يكتب الآن»، تقييم رضا بعد الإغلاق.

---

## 14) معايير القبول (Acceptance)
1. مستخدم إدارة يفتح تذكرة → تظهر في `list` بحالة `open` و `unread_for_support=1`.
2. رد الدعم → يصل المستخدم إشعار FCM + صف `notifications`، والتذكرة تصبح `pending_user` مع نقطة غير مقروء.
3. فتح المحادثة يصفّر `unread_for_user`.
4. أثناء فتح المحادثة، رسالة جديدة من الطرف الآخر تظهر خلال ≤ 5 ثوانٍ بدون إعادة تحميل (polling بـ `after_id`).
5. الـ polling يتوقف فور مغادرة الشاشة (لا Timer معلّق).
6. مستخدم من tenant آخر لا يستطيع الوصول لتذكرة ليست لشركته (يرجع 404/403).
7. كل الاستعلامات مقيّدة بـ `tenant_id`؛ لا تسرّب بين الشركات.
8. الإغلاق/إعادة الفتح يعملان ويُسجّلان في audit log.
9. الواجهة تدعم العربية وRTL، وتتبع ثيم التطبيق.

---

## 15) ملفات مرجعية حيّة (انسخ النمط منها)
- Backend endpoint بسيط: `backend_medjet/app/notifications/list.php`, `read.php`
- Backend endpoint مع tenant+permission: `backend_medjet/app/leaves/list.php`, `app/leaves/create.php`, `app/expenses/create.php`
- مصادقة الإدارة: `core/Auth.php`؛ مصادقة الدعم: `core/AdminAuth.php`
- FCM: `core/NotificationService.php`؛ تهيئة: `config/firebase.php`
- استجابة/تحقق/تدقيق: `core/Response.php`, `core/Validator.php`, `core/PermissionMiddleware.php`, `models/AuditLogModel.php`
- Frontend data source: `lib/data/data_source/remote/notification_data/notification_data.dart`
- Frontend controller: `lib/logic/controller/notification/notification_controller.dart`
- شبكة: `lib/core/class/crud.dart`؛ روابط: `lib/core/constant/id/app_links.dart`
- تسجيل route+binding: مدخل `AppRoutes.notifications` في `lib/core/constant/routes/app_pages.dart`

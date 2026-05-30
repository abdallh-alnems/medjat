# تبويب المالية — تحليل الفجوات وخريطة الطريق

تقييم صريح لما ينقص تبويب المالية في شاشة الموظف، مرتّب حسب الأهمية ومستفيداً من ميزات موجودة بالفعل في الباك إند لكن **لم تُعرَض** بعد.

---

## ✅ P0 — مكتملة

كل مهام P0 الأربع تم تنفيذها (الخصومات القانونية، تعديل/حذف البنود اليدوية، القروض والسلف، قسيمة الراتب PDF).

---

## ✅ P1 — مكتملة

كل مهام P1 الأربع تم تنفيذها (EOSB، خطابات وشهادات، إجراءات الموافقة، البدلات الثابتة).

---

## ✅ P2 — مكتملة

كل مهام P2 الأربع تم تنفيذها (معلومات الدفع البنكية، ملخّص الدخل السنوي YTD، رسم اتجاه الراتب، سجل التدقيق لكل بند).

---

## ✅ P3 — مكتملة

كل مهام P3 الأربع تم تنفيذها (بحث/فلترة البنود، تاريخ تعديلات الراتب الأساسي، إشعارات Push للموظف، شفافية قواعد الخصم/المكافأة).

---

## مرجع سريع: ما هو موجود بالفعل في الباك إند

| الميزة | موجود في الباك إند؟ | الحالة |
|---|---|---|
| Statutory breakdown | ✅ يُرجَع في `current.statutory` | ✅ **مكتمل** |
| Loans/Advances | ✅ `LoanModel` + خصم تلقائي | ✅ **مكتمل** |
| Edit/delete adjustment | ✅ endpoints جديدة | ✅ **مكتمل** |
| Payslip PDF | ✅ `PayslipPdfService` + endpoint | ✅ **مكتمل** |
| EOSB | ✅ `app/payroll/eosb_calculate.php` | ✅ **مكتمل** |
| Payroll approve/revert | ✅ `approve.php` + `revert.php` | ✅ **مكتمل** |
| Letters templates | ✅ `templates/letters` module | ✅ **مكتمل** |
| Fixed allowances | ✅ `employee_allowances` + AllowanceModel | ✅ **مكتمل** |
| Bank info | ✅ حقول الموظف | ✅ **مكتمل** |
| YTD totals | ✅ `get_year_to_date.php` | ✅ **مكتمل** |
| Trend chart | ✅ بيانات `financialHistory` | ✅ **مكتمل** |
| Audit display (creator/approver) | ✅ joined names في الـ summary | ✅ **مكتمل** |
| Salary edit history | ✅ من `audit_log` | ✅ **مكتمل** |
| Search/filter بنود | — | ✅ **مكتمل** |
| Push notifications للموظف | ✅ `NotificationService::sendToUser` | ✅ **مكتمل** |
| Rule transparency | ✅ rules object في الـ summary | ✅ **مكتمل** |

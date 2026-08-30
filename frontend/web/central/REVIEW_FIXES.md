# تعليمات إصلاح — مراجعة CodeRabbit لمشروع medjat_central_web

_تاريخ المراجعة: 2026-06-20 · الفرع: 003-medjat-central-web · الأساس: main_

## للنموذج المنفِّذ — اقرأ هذا أولاً

- جذر العمل: `frontend/web/central/`. كل المسارات أدناه نسبية لهذا الجذر.
- الكود **غير متتبَّع في git بعد** (untracked). أنشئ commit أولاً قبل أي تعديل لتحمي العمل.
- لكل ملاحظة: تحقّق أولاً أنها ما زالت صالحة مقابل الكود الحالي، أصلح الصالح فقط، تجاهل ما لم يعد منطبقاً مع ذكر سبب مختصر، وأبقِ التغييرات أصغرية.
- بعد كل مجموعة إصلاحات: شغّل `npm run lint` و `npx tsc --noEmit` للتأكد من عدم كسر الأنواع.
- **ترتيب التنفيذ المقترح:** الحرجة 🔴 ← المهمة 🟠 ← الثانوية 🟡.

### ⚠️ ملاحظة ترابط مهمة
تغيير شكل إرجاع `apiGet`/`apiPost` في `src/lib/api/client.ts` (إرجاع status بدل data فقط) **يكسر كل مستدعِيات الدالة** عبر التطبيق. إن نفّذتها، عدّل كل call sites في نفس الـ commit، أو تجاهلها إن كانت ستتطلب تغييراً واسعاً غير مرغوب الآن.

## ملخّص

**الإجمالي: 114 ملاحظة** — 🔴 21 حرجة · 🟠 56 مهمة · 🟡 37 ثانوية

| المجلد | 🔴 حرجة | 🟠 مهمة | 🟡 ثانوية | المجموع |
|--------|:------:|:------:|:--------:|:-------:|
| `src/lib` | 5 | 16 | 1 | 22 |
| `src/app` | 6 | 19 | 21 | 46 |
| `src/components` | 6 | 9 | 13 | 28 |
| `tests` | 4 | 12 | 2 | 18 |

> لم تُراجَع ملفات الإعداد الجذرية (next.config، tsconfig، إلخ) لأن الحدّ المجاني 150 ملفاً والتطبيق 238 ملفاً؛ قُسّمت المراجعة على المجلدات.

---

# 🔴 حرجة (Critical) — 21 ملاحظة

### 1. `src/app/(app)/attendance/page.tsx`  ·  _src/app_

In src/app/(app)/attendance/page.tsx around lines 55 - 63, The comparator function `cmp` inside the `useMemo` hook is missing a case to handle `sort === "name"`. Add a condition before the default return statement that checks if `sort === "name"` and returns a comparison of the employee_name field using localeCompare, similar to how "status" and "check_in" are handled. This will ensure that when users select "name" from the sort select, the records are properly sorted by employee name instead of falling through to the default employee_id numeric sort.

### 2. `src/app/(app)/employees/new/page.tsx`  ·  _src/app_

In src/app/(app)/employees/new/page.tsx at line 76, The unsafe `as never` type assertion in the mutation.mutateAsync call completely bypasses TypeScript's type safety. Verify that the FormData Zod schema type matches the expected input shape for the createEmployee API function. If there's a mismatch between the form schema and the API signature, fix it by adjusting the FormData schema definition to match createEmployee's expected type, or create a proper transformation function that maps the form data to the correct shape. Then remove the `as never` cast entirely and let TypeScript enforce the correct type contract.

  ```suggested
      const payload = {
        ...data,
        // Add any necessary transformations here
      };
      await mutation.mutateAsync(payload);
  ```

### 3. `src/app/(app)/loans/page.tsx`  ·  _src/app_

In src/app/(app)/loans/page.tsx around lines 129 - 134, The submit button in the loans form is missing validation for the installment field. In the Button component with onClick={submit}, update the disabled property to include a check for !installment alongside the existing !employeeId and !principal checks. This will prevent users from submitting the form without entering an installment amount, which currently allows invalid data (NaN or 0) to be sent to the backend.

  ```suggested
              <Button
                onClick={submit}
                disabled={create.isPending || !employeeId || !principal || !installment}
              >
                {create.isPending ? t("saving") : t("create")}
              </Button>
  ```

### 4. `src/app/(app)/onboarding/page.tsx`  ·  _src/app_

In src/app/(app)/onboarding/page.tsx around lines 64 - 66, The redirect using router.replace("/dashboard") is executed unconditionally while the setTenant call is conditional on res.tenant_id being truthy. This means if res.tenant_id is falsy, setTenant will not execute but the user will still be redirected to dashboard without tenant context. Make the router.replace("/dashboard") call conditional by moving it inside the if block so it only executes after setTenant has successfully been called with a valid tenant_id.

  ```suggested
      if (res.tenant_id) {
        setTenant(res.tenant_id, res.company?.name);
        toast.success(t("success"));
        router.replace("/dashboard");
      } else {
        toast.error(t("error_generic"));
      }
  ```

### 5. `src/app/(app)/onboarding/page.tsx`  ·  _src/app_

In src/app/(app)/onboarding/page.tsx around lines 50 - 52, The redirect to `/dashboard` using `router.replace` is unconditional while the `setTenant` call with `res.tenant_id` is conditional, meaning users could be redirected without proper tenant context set. Move the `router.replace("/dashboard")` call inside the `if (res.tenant_id)` conditional block so the redirect only occurs after `setTenant` has been successfully called with a valid tenant_id, ensuring users always land on the dashboard with proper tenant context established.

  ```suggested
      if (res.tenant_id) {
        setTenant(res.tenant_id, data.name);
        toast.success(t("success"));
        router.replace("/dashboard");
      } else {
        toast.error(t("error_generic"));
      }
  ```

### 6. `src/app/(app)/shifts/assign/page.tsx`  ·  _src/app_

In src/app/(app)/shifts/assign/page.tsx around lines 25 - 31, The AssignShiftPage component currently only displays employees who are already assigned to the shift (those in the members Set created on line 31), which prevents users from selecting unassigned employees for assignment. Fetch all available employees using an appropriate hook (such as useEmployees or similar), and modify the table rendering logic at lines 90-104 to display all employees instead of filtering by the current members Set. For each employee row, show their current assignment status by checking if they exist in the members Set, allowing users to both assign new members and unassign existing ones from the interface.

### 7. `src/components/layout/topbar.tsx`  ·  _src/components_

In src/components/layout/topbar.tsx around lines 28 - 34, The SheetTrigger component in the topbar.tsx file uses an incorrect `render` prop which is not supported by the shadcn/ui Sheet component. Replace the `render` prop with the `asChild` prop on SheetTrigger, then restructure the JSX to make the Button a direct child element of SheetTrigger instead of being passed through the render prop, keeping the Menu icon as a child of the Button. This follows the proper shadcn/ui composition pattern based on Radix UI primitives.

  ```suggested
          <SheetTrigger asChild>
            <Button variant="ghost" size="icon" className="md:hidden">
              <Menu className="h-5 w-5" />
            </Button>
          </SheetTrigger>
  ```

### 8. `src/components/leave/add-leave-sheet.tsx`  ·  _src/components_

In src/components/leave/add-leave-sheet.tsx around lines 53 - 56, Replace the unsupported render prop on the SheetTrigger component with the asChild prop. Remove the render={<Button size="sm" />} attribute from SheetTrigger and instead wrap the Button component as a direct child element of SheetTrigger. Move the Plus icon and the new_leave text translation inside the Button component, ensuring Button becomes a direct child of SheetTrigger with the asChild prop set.

### 9. `src/components/team/permissions-editor.tsx`  ·  _src/components_

In src/components/team/permissions-editor.tsx around lines 64 - 68, The toggle function can cause permission data loss if called while perms.isLoading is true and perms.data is undefined, because spreading an empty object and setting a single permission creates an incomplete payload that wipes other permissions on the backend. Prevent this by disabling all permission checkboxes during the loading state. Add a disabled attribute to the checkbox inputs/controls that call the toggle function, setting the disabled state based on perms.isLoading so users cannot modify permissions until the data has fully loaded.

### 10. `src/components/ui/badge.tsx`  ·  _src/components_

In src/components/ui/badge.tsx at line 8, The Tailwind !important syntax in the badge component's className is incorrect. The exclamation mark must precede the utility class name, not follow it. In the arbitrary variant selector [&>svg]:size-3!, move the ! to come before size-3 so it reads [&>svg]:!size-3 to properly apply the !important modifier in Tailwind CSS.

  ```suggested
  "group/badge inline-flex h-5 w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-4xl border border-transparent px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-all focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 has-data-[icon=inline-end]:pe-1.5 has-data-[icon=inline-start]:ps-1.5 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:!size-3",
  ```

### 11. `src/components/ui/table.tsx`  ·  _src/components_

In src/components/ui/table.tsx around lines 42 - 53, The TableFooter function's className contains an invalid CSS pseudo-class `:last` in the selector `[&>tr]:last:border-b-0`, which is not a valid CSS selector. Replace `:last` with `:last-child` to properly target the last row in the footer, so the selector becomes `[&>tr]:last-child:border-b-0` in the cn() call within the tfoot element's className prop. This will match the correct pattern already used in the TableBody component.

  ```suggested
function TableFooter({ className, ...props }: React.ComponentProps<"tfoot">) {
  return (
    <tfoot
      data-slot="table-footer"
      className={cn(
        "border-t bg-muted/50 font-medium [&>tr:last-child]:border-b-0",
        className
      )}
      {...props}
    />
  )
}
  ```

### 12. `src/components/ui/tabs.tsx`  ·  _src/components_

In src/components/ui/tabs.tsx around lines 8 - 24, The Tabs function sets a data-orientation attribute with values like "horizontal" or "vertical", but the className selector references data-horizontal which expects a different attribute name entirely. Fix this mismatch by either updating the CSS selectors in the cn() call to use Tailwind's attribute selector syntax to match the data-orientation attribute values (e.g., targeting data-orientation="horizontal"), or alternatively, conditionally set separate boolean data attributes (data-horizontal or data-vertical) based on the orientation value instead of using the data-orientation attribute. Apply the same pattern consistently throughout the component and in related variants like tabsListVariants and TabsTrigger.

### 13. `src/lib/export/pdf.ts`  ·  _src/lib_

In src/lib/export/pdf.ts around lines 6-26, The exportReportToPDF function will fail to render Arabic text correctly because jsPDF lacks built-in support for Arabic glyphs, causing text to display as boxes when locale='ar'. Add Arabic font support to the jsPDF document instance before any text rendering by using jsPDF's addFileToVFS and addFont methods to register an Arabic-compatible font (such as Amiri or Cairo), then call setFont to activate that font before invoking doc.text and the autoTable function, so the title, period, and table content render with proper Arabic glyphs.

### 14. `src/lib/hooks/use-managers.ts`  ·  _src/lib_

In src/lib/hooks/use-managers.ts around lines 75-86, The useUpdateAdminPermissions hook contains an unsafe `as never` type cast on the permissions argument passed to updateAdminPermissions, which disables type checking and may cause runtime errors. Remove the `as never` cast and instead check the actual type signature of updateAdminPermissions in the @/lib/api/managers module, then align the permissions parameter type in the hook's args object to match the expected type from the API function exactly, ensuring proper type safety without unsafe casts.

### 15. `src/lib/types/attendance.ts`  ·  _src/lib_

In src/lib/types/attendance.ts around lines 22-28, The AttendanceOverride interface has a design flaw where all three ID fields are optional with no constraints, allowing invalid state combinations like no scope set or multiple scopes simultaneously. Refactor the AttendanceOverride interface to use a discriminated union pattern by creating separate type variants (e.g., BranchOverride, CategoryOverride, EmployeeOverride) where each variant has a required type field to discriminate between them and exactly one required ID field (branch_id, category_id, or employee_id respectively, not optional). Then define AttendanceOverride as a union of these three variants, ensuring exactly one scope ID is present at any time and the API contract is unambiguous.

### 16. `src/lib/utils.ts`  ·  _src/lib_

In src/lib/utils.ts around lines 58-60, The todayISO() function currently uses toISOString() which returns UTC time instead of local time, causing dates to be off by a day for users in timezones ahead of UTC. Replace the UTC-based approach with local date components by using getFullYear(), getMonth(), and getDate() methods on the Date object, then format these values as a string in YYYY-MM-DD format using padded month and day values (ensure single-digit months and days are zero-padded). SUGGESTED: export function todayISO(): string { const d = new Date(); const year = d.getFullYear(); const month = String(d.getMonth() + 1).padStart(2, '0'); const day = String(d.getDate()).padStart(2, '0'); return `${year}-${month}-${day}`; }

### 17. `src/lib/utils.ts`  ·  _src/lib_

In src/lib/utils.ts around lines 63-65, The currentMonth() function uses toISOString() which returns UTC time instead of the user's local time, causing incorrect month values near month boundaries. Fix this by extracting the local year and month from the Date object using getFullYear() and getMonth() methods, then format them as a YYYY-MM string with proper zero-padding for the month (since getMonth() returns 0-11, add 1 and pad to two digits). SUGGESTED: export function currentMonth(): string { const d = new Date(); const year = d.getFullYear(); const month = String(d.getMonth() + 1).padStart(2, '0'); return `${year}-${month}`; }

### 18. `tests/contract/managers.test.ts`  ·  _tests_

In tests/contract/managers.test.ts at line 77, The `as never` type assertion in the call to updateAdminPermissions on line 77 disables TypeScript type checking and defeats the purpose of static typing. Remove the `as never` assertion entirely and replace it with the correct type for the permissions parameter based on what updateAdminPermissions expects. If TypeScript still reports a type error after removing the assertion, then investigate and fix the type definition of the updateAdminPermissions function itself rather than suppressing the error with a type cast.

  ```suggested
    const res = await updateAdminPermissions(1, { manage_employees: true });
  ```

### 19. `tests/e2e/us10-support-account.spec.ts`  ·  _tests_

In tests/e2e/us10-support-account.spec.ts around lines 13 - 21, The tests in the test.describe block for "US10 — support, notifications, audit & account" navigate to authenticated routes like /support without performing any login step, which will cause authorization failures. Add a beforeEach hook inside the test.describe block that authenticates the user before each test runs. This can be done either by performing a login flow using process.env.E2E_EMAIL and process.env.E2E_PASSWORD credentials, or by using Playwright's storageState to reuse a previously authenticated session. This authentication setup is required for all tests in this suite to access the protected routes properly.

### 20. `tests/e2e/us10-support-account.spec.ts`  ·  _tests_

In tests/e2e/us10-support-account.spec.ts around lines 28 - 31, Remove the `.catch(() => {})` block that silently swallows the assertion failure in the expect statement for the table locator. The assertion on the page.locator("table").toBeVisible() call should fail visibly if the table is not found within the 10000ms timeout, rather than having the error caught and ignored, which defeats the purpose of the test validation.

  ```suggested
  test.skip("audit log lists actions", async ({ page }) => {
    await page.goto("/activity-log");
    await expect(page.locator("table")).toBeVisible({ timeout: 10000 });
  });
  ```

### 21. `tests/e2e/us9-permissions.spec.ts`  ·  _tests_

In tests/e2e/us9-permissions.spec.ts around lines 12 - 26, The test cases in the "US9 — settings, team & permissions" describe block navigate directly to authenticated routes without logging in first, which will cause authorization failures when tests are unskipped. Add a test.beforeEach hook inside the test.describe block that authenticates the user before each test runs. The hook should either perform login using the E2E_EMAIL and E2E_PASSWORD environment variables, or use Playwright's storageState feature to reuse a previously authenticated session. This will ensure the page context is properly authenticated before tests navigate to protected routes like "/settings/company" and "/team".

# 🟠 مهمة (Major) — 56 ملاحظة

### 22. `src/app/(app)/branches/[id]/qr/page.tsx`  ·  _src/app_

In src/app/(app)/branches/[id]/qr/page.tsx around lines 25 - 47, The QR generation logic has a flaw where the query auto-fetches on mount because `enabled: !!token === false` triggers when token is null, and the button onClick just assigns the already-fetched token instead of generating a new QR code. To fix this using the "generate on click" approach, change the `enabled` property in the useQuery call to `false` to prevent auto-fetching, then modify the button's onClick handler to call `qr.refetch()` instead of calling `setToken(resolvedToken)`, and consider removing the token state entirely if it's only used for this button logic since the QR token will be available directly from `qr.data?.qr_token`.

### 23. `src/app/(app)/employees/[id]/documents/page.tsx`  ·  _src/app_

In src/app/(app)/employees/[id]/documents/page.tsx around lines 49 - 50, The route parameter `id` extracted from `use(params)` is being converted to a number using `Number(id)` without validation, which will result in `NaN` if the `id` is malformed (like "/employees/abc/documents"). Add validation to check if the `id` parameter is a valid numeric string before performing the conversion to `employeeId`, and handle the invalid case appropriately by either returning a not found error or redirecting to an error page.

### 24. `src/app/(app)/employees/[id]/page.tsx`  ·  _src/app_

In src/app/(app)/employees/[id]/page.tsx around lines 53 - 54, Add validation for the route parameter `id` before converting it to a number. After destructuring `id` from `use(params)`, check that `id` is a valid numeric string and that the resulting `employeeId` is not `NaN`. If the validation fails, handle the error appropriately by either redirecting to the employees list page or displaying an error message to the user. This ensures that invalid route parameters like `/employees/abc` do not propagate `NaN` values into downstream API calls and queries.

### 25. `src/app/(app)/employees/[id]/settlement/page.tsx`  ·  _src/app_

In src/app/(app)/employees/[id]/settlement/page.tsx around lines 34 - 35, The route parameter id is being converted to a number without validation, which can cause unexpected behavior if id is undefined, null, or not a valid numeric string. Add validation logic after extracting id from use(params) to ensure it exists and is a valid numeric value before converting it to employeeId with Number(id). If the id is invalid, handle it appropriately by either redirecting or throwing an error to prevent the component from processing with an invalid employeeId.

### 26. `src/app/(app)/loans/page.tsx`  ·  _src/app_

In src/app/(app)/loans/page.tsx around lines 71 - 88, The submit function performs Number() conversions on employeeId, principal, and installment input fields without first validating that they contain valid numeric values, which can result in NaN being passed to the create.mutate call. Add validation logic at the beginning of the submit function to check that employeeId, principal, and installment are all non-empty and valid numbers before proceeding with the conversion. If any field fails validation, return early from the function without calling create.mutate. This ensures that only valid numeric values are sent to the mutation.

  ```suggested
  const submit = () => {
    const empId = Number(employeeId);
    const princ = Number(principal);
    const inst = Number(installment);
    if (!empId || !princ || !inst || princ <= 0 || inst <= 0) {
      // show error toast or return early
      return;
    }
    create.mutate(
      {
        employee_id: empId,
        principal: princ,
        installment: inst,
        remaining: princ,
      },
      {
        onSuccess: () => {
          setOpen(false);
          setEmployeeId("");
          setPrincipal("");
          setInstallment("");
        },
      },
    );
  };
  ```

### 27. `src/app/(app)/onboarding/page.tsx`  ·  _src/app_

In src/app/(app)/onboarding/page.tsx around lines 67 - 68, The catch block in the onboarding page only displays a generic toast error message without logging the actual error details for debugging purposes. Add error logging before the toast.error call in the catch block to capture and log the error object, which will help with troubleshooting while still showing the generic error message to the user via the toast notification.

  ```suggested
    } catch (err) {
      console.error("Failed to join company:", err);
      toast.error(t("error_generic"));
    } finally {
  ```

### 28. `src/app/(app)/onboarding/page.tsx`  ·  _src/app_

In src/app/(app)/onboarding/page.tsx around lines 53 - 54, The catch block at lines 53-54 is not logging the error details before displaying the generic toast message to the user. Add error logging (using an appropriate logger or console.error) to capture the actual error information within the catch block before the toast.error call that shows the generic error message. This will allow production failures to be properly diagnosed while still displaying a user-friendly error message via the toast.

  ```suggested
    } catch (err) {
      console.error("Failed to create company:", err);
      toast.error(t("error_generic"));
    } finally {
  ```

### 29. `src/app/(app)/reports/documents/page.tsx`  ·  _src/app_

In src/app/(app)/reports/documents/page.tsx around lines 69 - 81, The ComplianceTable component currently only handles loading and empty states but does not handle error states from the underlying query hooks, causing fetch failures to display as "no_report_data" which misleads users. Add an error parameter to the ComplianceTable function signature alongside title, rows, and loading, then add a conditional check for the error state before the loading and empty state checks to display an appropriate error message when queries fail. Additionally, update all call sites where ComplianceTable is instantiated (the three locations that render tables for expiring, expired, and missing data) to pass the corresponding error information from their respective query hooks to the component.

### 30. `src/app/(app)/reports/documents/page.tsx`  ·  _src/app_

In src/app/(app)/reports/documents/page.tsx at line 100, The Badge component's t function call uses an `as never` type assertion that bypasses TypeScript's type safety for translation keys. Instead of using the assertion on r.status, create a type-safe status mapping or validation function that ensures only valid status values are passed to the translation function. Define a union type for valid status values and either validate the status against this type before passing it to t, or create a mapping object that safely converts backend status values to valid translation keys with appropriate fallbacks.

### 31. `src/app/(app)/settings/deductions/page.tsx`  ·  _src/app_

In src/app/(app)/settings/deductions/page.tsx around lines 33 - 37, The `add` function uses `Date.now()` to generate IDs for new deduction rules, which can cause collisions if multiple rules are added within the same millisecond. Replace the `Date.now()` call with `crypto.randomUUID()` to generate unique identifiers. Additionally, check the `DeductionRule` type definition and update the `id` field type from `number` to `string` to accommodate the UUID format.

### 32. `src/app/(app)/settings/leave/page.tsx`  ·  _src/app_

In src/app/(app)/settings/leave/page.tsx around lines 28 - 29, The fields with keys max_carryover and carryover_enabled both use the same translation key t("carryover"), which creates confusing duplicate labels for distinct form inputs. Update each field to use a unique and descriptive translation key: change the label for max_carryover to use a translation key like t("max_carryover_days") to indicate it expects a numeric value for days, and change the label for carryover_enabled to use a translation key like t("enable_carryover") to clarify it is a toggle checkbox. Ensure the corresponding translation strings are also added to your i18n configuration files.

  ```suggested
          { key: "max_carryover", label: t("max_carryover_days"), type: "number" },
          { key: "carryover_enabled", label: t("enable_carryover"), type: "checkbox" },
  ```

### 33. `src/app/(app)/settings/leave/page.tsx`  ·  _src/app_

In src/app/(app)/settings/leave/page.tsx around lines 26 - 27, The `annual_entitlement` and `sick_entitlement` fields both use the same label translation key `t("leave_balance")`, making it impossible to distinguish between them. Update the label for `annual_entitlement` to use a unique translation key such as `t("annual_leave_entitlement")` and update the label for `sick_entitlement` to use a different unique translation key such as `t("sick_leave_entitlement")`. This ensures each field has a distinct, descriptive label that clearly identifies its purpose.

  ```suggested
          { key: "annual_entitlement", label: t("annual_leave_entitlement"), type: "number" },
          { key: "sick_entitlement", label: t("sick_leave_entitlement"), type: "number" },
  ```

### 34. `src/app/(app)/settings/statutory/page.tsx`  ·  _src/app_

In src/app/(app)/settings/statutory/page.tsx around lines 23 - 25, The three statutory rate configuration objects for social_insurance_rate, tax_rate, and health_insurance_rate all use the same label t("deductions"), making it impossible for users to distinguish between them. Update each field to have a unique, descriptive label by changing the label property for the social_insurance_rate field to t("social_insurance_rate"), the tax_rate field to t("tax_rate"), and the health_insurance_rate field to t("health_insurance_rate").

  ```suggested
        { key: "social_insurance_rate", label: t("social_insurance_rate"), type: "number" },
        { key: "tax_rate", label: t("tax_rate"), type: "number" },
        { key: "health_insurance_rate", label: t("health_insurance_rate"), type: "number" },
  ```

### 35. `src/app/(app)/shifts/schedule/page.tsx`  ·  _src/app_

In src/app/(app)/shifts/schedule/page.tsx around lines 53 - 56, The copy mutation function copies the current week to a target week specified by the toWeek parameter, but on line 82 it's being called with copy.mutate(week), passing the same week as both source and target. This creates a meaningless operation. Add a UI element (such as a dialog, dropdown, or input field) that allows users to select a different target week, and only then call the copy.mutate method with that selected week instead of the current week variable. This ensures the copy operation is performed between two different weeks as intended.

### 36. `src/app/(app)/shifts/schedule/page.tsx`  ·  _src/app_

In src/app/(app)/shifts/schedule/page.tsx around lines 168 - 183, The assign.mutate call in the onClick handler converts empId and shiftId to numbers without validating that these IDs correspond to actual employees or shifts in the database. Add validation logic to verify the selected IDs are valid before executing the mutation. Either add explicit validation checks within the onClick handler before calling assign.mutate, or conditionally disable the Button component based on whether the IDs pass validation checks, ensuring invalid assignments are not sent to the API.

### 37. `src/app/api/[...path]/route.ts`  ·  _src/app_

In src/app/api/[...path]/route.ts at line 74, The body variable assignment uses a conditional that only reads the request body for POST requests. When PUT, PATCH, and DELETE handlers are added, they will also require access to the request body. Update the condition in the ternary operator where body is assigned to include PUT, PATCH, and DELETE methods alongside POST so that the request body is properly captured for all methods that require it.

  ```suggested
  const body = ["POST", "PUT", "PATCH"].includes(request.method)
    ? await request.text()
    : undefined;
  ```

### 38. `src/app/api/[...path]/route.ts`  ·  _src/app_

In src/app/api/[...path]/route.ts around lines 76 - 81, The fetch request in the route handler lacks a timeout configuration, which can cause requests to hang indefinitely if the backend is unresponsive. Add an AbortController with a configured timeout duration to the fetch call. Create the AbortController before the fetch, set up a timeout that aborts the controller after a reasonable duration (e.g., 30 seconds), and pass the signal property of the AbortController in the fetch options object alongside method, headers, and body. This ensures that slow or unresponsive backend requests will be automatically terminated rather than hanging indefinitely.

  ```suggested
  try {
    const res = await fetch(fullUrl, {
      method: request.method,
      headers,
      body,
      signal: AbortSignal.timeout(30000), // 30 second timeout
    });
  ```

### 39. `src/app/api/[...path]/route.ts`  ·  _src/app_

In src/app/api/[...path]/route.ts around lines 91 - 96, In the catch block of the route handler, the error response currently exposes the full error details by including String(error) in the response body, which could leak sensitive backend information to clients. Remove the details field from the NextResponse.json response object in the catch block (around line 93) so that only a generic "Proxy error" message is returned to the client without exposing actual error information or stack traces.

  ```suggested
  } catch (error) {
    console.error("[BFF proxy error]", error);
    return NextResponse.json(
      {
        error: "Service temporarily unavailable",
        ...(process.env.NODE_ENV === "development" && {
          details: String(error),
        }),
      },
      { status: 500 },
    );
  }
  ```

### 40. `src/app/api/[...path]/route.ts`  ·  _src/app_

In src/app/api/[...path]/route.ts around lines 63 - 66, The Content-Type header in the headers object is hardcoded to "application/json", which breaks requests requiring different content types like multipart/form-data or URL-encoded forms. Instead of hardcoding this value, forward the Content-Type header from the incoming request. Access the Content-Type from the incoming request's headers and conditionally add it to the headers object being constructed, or use a fallback value if the incoming request doesn't specify one.

  ```suggested
  const headers: Record<string, string> = {
    Authorization: `Basic ${btoa(`${SECURITY_USER}:${SECURITY_KEY}`)}`,
  };

  // Forward Content-Type if present, otherwise default to JSON
  const contentType = request.headers.get("content-type");
  if (contentType) {
    headers["Content-Type"] = contentType;
  } else {
    headers["Content-Type"] = "application/json";
  }
  ```

### 41. `src/components/attendance/attendance-table.tsx`  ·  _src/components_

In src/components/attendance/attendance-table.tsx around lines 59 - 60, The allSelected calculation uses a nested .includes() check inside .every() which creates O(n·m) complexity and causes performance lag on large lists. Convert the selected array to a Set data structure before the .every() call, then replace the .includes(r.id) check with the Set's .has(r.id) method to achieve O(n) lookup time. This will maintain the same logic while significantly improving performance.

### 42. `src/components/attendance/live-board.tsx`  ·  _src/components_

In src/components/attendance/live-board.tsx around lines 15 - 21, The TONE mapping constant in live-board.tsx is duplicated from STATUS_TONE in attendance-table.tsx. Create a new shared constants file at src/lib/constants/attendance.ts and define the ATTENDANCE_STATUS_TONE constant with the attendance status tone mappings (present, late, leave, holiday, absent). Then update both live-board.tsx and attendance-table.tsx to import and use this shared ATTENDANCE_STATUS_TONE constant instead of maintaining duplicate local definitions.

### 43. `src/components/branch/branch-location-sheet.tsx`  ·  _src/components_

In src/components/branch/branch-location-sheet.tsx around lines 58 - 59, The coordinate conversion logic in the branch-location-sheet.tsx file uses the pattern `Number(lat) || null` which treats the valid coordinate value 0 as falsy and incorrectly converts it to null. Replace this falsy coercion pattern with an explicit null check that preserves zero values. Instead of relying on the OR operator's truthiness evaluation, check if the converted number is NaN using Number.isNaN() or similar, and return null only when the conversion actually fails (NaN case), allowing valid zero coordinates for latitude and longitude to be preserved.

  ```suggested
     onSave({
       lat: lat === "" ? null : (isNaN(Number(lat)) ? null : Number(lat)),
       lng: lng === "" ? null : (isNaN(Number(lng)) ? null : Number(lng)),
       radius: Number(radius) || 100,
     });
  ```

### 44. `src/components/layout/mobile-bottom-nav.tsx`  ·  _src/components_

In src/components/layout/mobile-bottom-nav.tsx around lines 16 - 22, The ITEMS array in mobile-bottom-nav.tsx displays all navigation items without permission checks, while the desktop SidebarNav conditionally renders items based on user permissions using the Can component. Add permission gating to the mobile navigation by filtering or conditionally rendering items that require specific permissions (employees, attendance, and payroll), matching the pattern used in the desktop sidebar to ensure users only see navigation items they have access to.

### 45. `src/components/layout/sidebar-nav.tsx`  ·  _src/components_

In src/components/layout/sidebar-nav.tsx around lines 137 - 138, The active state calculation in the sidebar-nav.tsx component uses a startsWith check that causes parent routes to be marked active when viewing nested routes. For example, when viewing `/shifts/schedule`, both `/shifts` and `/shifts/schedule` become active because `/shifts/schedule` starts with `/shifts/`. Fix the active constant assignment at lines 137-138 to use exact matching instead, ensuring that only the most specific matching route is marked as active. If the current pathname exactly matches an item's href, that item should be active; only apply the nested route logic (startsWith check) when there is no other exact match available in the navigation items list.

### 46. `src/components/layout/topbar.tsx`  ·  _src/components_

In src/components/layout/topbar.tsx around lines 65 - 68, The logout action in the onClick handler is called without error handling, which means the success toast will display even if the logout fails. Wrap the logout() call with proper error handling: if logout is async/returns a promise, use try-catch with await to call logout and only show the success toast in the try block, catching any errors in a catch block; if logout is synchronous, wrap it in a try-catch block. Only display the success toast after logout succeeds, and handle the error case by either showing an error toast or logging the error appropriately.

### 47. `src/components/settings/settings-form.tsx`  ·  _src/components_

In src/components/settings/settings-form.tsx around lines 27 - 32, The useEffect hook in the SettingsForm component is unconditionally overwriting the values state whenever the initial dependency changes, causing user edits to be lost when the parent re-renders with a new initial reference. To fix this, use lazy initialization by passing a function to the useState declaration for values that returns the initial state only on first mount, removing the useEffect altogether. Alternatively, if initial values must update after mount, implement an explicit reset mechanism (such as a method called by the parent) rather than relying on dependency changes to overwrite user edits.

  ```suggested
  const [values, setValues] = useState<Record<string, unknown>>(() => initial ?? {});
  ```

### 48. `src/components/team/permissions-editor.tsx`  ·  _src/components_

In src/components/team/permissions-editor.tsx around lines 96 - 99, The Checkbox component in the permissions editor does not disable during mutation operations, allowing users to trigger concurrent updates. Add a disabled prop to the Checkbox component and set it to the isPending state from the update mutation hook (update.isPending) to prevent user interaction while a permission update is in progress. This will block further checkbox toggles until the current update completes, eliminating the race condition from concurrent mutations.

  ```suggested
                <Checkbox
                  checked={effective?.[code] ?? false}
                  onCheckedChange={(v) => toggle(code, Boolean(v))}
                  disabled={update.isPending}
                />
  ```

### 49. `src/components/team/permissions-editor.tsx`  ·  _src/components_

In src/components/team/permissions-editor.tsx around lines 54 - 62, The component does not handle the case where an adminId is provided but the corresponding admin is not found in the admins list, which can occur due to race conditions or stale data. After the admin lookup assignment (where admin is determined from the admins list using adminId), add a guard condition to check if adminId was provided but admin is null, and return early from the component or render an appropriate fallback (such as an error state or empty state) to prevent rendering the permissions editor with incorrect state for a non-existent admin.

### 50. `src/lib/api/attendance.ts`  ·  _src/lib_

In src/lib/api/attendance.ts around lines 9-14, The getBranchAttendance function unnecessarily casts the params argument to Record<string, unknown> when calling apiGet, which bypasses type safety. Remove the type cast `as Record<string, unknown>` from the params parameter in the apiGet call, and pass params directly since apiGet should already accept the AttendanceParams type.

### 51. `src/lib/api/branches.ts`  ·  _src/lib_

In src/lib/api/branches.ts around lines 34-44, The setMethodOverride function is currently located in the branches.ts module but should be moved to the attendance API module since it calls the app/attendance/set_method_override.php endpoint. Remove the entire setMethodOverride function (including its type definition) from branches.ts and add it to the appropriate attendance API module file to maintain better semantic cohesion.

### 52. `src/lib/api/client.ts`  ·  _src/lib_

In src/lib/api/client.ts around lines 11-12, The SECURITY_USER and SECURITY_KEY variables are defaulting to empty strings when environment variables are missing, which results in invalid Base64 encoded Basic authentication headers that will fail silently. Add validation logic after the variable declarations to check if either SECURITY_USER or SECURITY_KEY is empty, and throw an error immediately if credentials are missing, so the app fails fast at startup. SUGGESTED: const SECURITY_USER = process.env.SECURITY_USER ?? ''; const SECURITY_KEY = process.env.SECURITY_KEY ?? ''; if (!SECURITY_USER || !SECURITY_KEY) { throw new Error('SECURITY_USER and SECURITY_KEY must be set for server-side API calls'); }

### 53. `src/lib/api/client.ts`  ·  _src/lib_

In src/lib/api/client.ts around lines 88-95, The apiPost function returns only res.data, which discards the HTTP status code and response metadata that callers need for proper error handling. Modify apiPost to return the full Axios response object (or a structured response including both data and status) instead of just res.data.

### 54. `src/lib/api/client.ts`  ·  _src/lib_

In src/lib/api/client.ts around lines 80-86, The apiGet function discards status information by returning only res.data, which prevents callers from distinguishing successful responses from error responses when the response interceptor resolves non-2xx responses. Modify apiGet to return either the full response object or an object containing both status and data (such as { status: res.status, data: res.data }). NOTE: apiGet/apiPost return-shape changes are interdependent — update ALL call sites accordingly to avoid breaking the app.

### 55. `src/lib/api/documents.ts`  ·  _src/lib_

In src/lib/api/documents.ts around lines 53-62, Remove the duplicate function exports getRequiredDocuments and getRequiredSubmissions from documents.ts since they are already exported from required-documents.ts with identical implementations. Update any imports throughout the codebase that currently import these two functions from documents.ts to import them from required-documents.ts instead.

### 56. `src/lib/api/employees.ts`  ·  _src/lib_

In src/lib/api/employees.ts around lines 30-35, The listEmployees function unnecessarily casts the params argument to Record<string, unknown> when calling apiGet, which bypasses TypeScript type checking. Remove this type cast and pass params directly to apiGet without the 'as Record<string, unknown>' assertion.

### 57. `src/lib/api/payroll.ts`  ·  _src/lib_

In src/lib/api/payroll.ts around lines 9-11, The listSlips function contains an unnecessary double type cast (as unknown as Record<string, unknown>) that bypasses TypeScript's type safety. Remove this double cast entirely and instead ensure that PayrollPeriodParams properly satisfies the expected type for the params argument in the apiGet call. If PayrollPeriodParams does not extend Record<string, unknown>, update the PayrollPeriodParams type definition to properly align with what apiGet expects. SUGGESTED: export function listSlips(params: PayrollPeriodParams) { return apiGet<Payslip[]>('app/payroll/list_slips.php', params); }

### 58. `src/lib/api/reports.ts`  ·  _src/lib_

In src/lib/api/reports.ts around lines 13-39, The four report functions (getAttendanceReport, getPayrollReport, getEmployeesReport, and getLeavesReport) all use a double cast pattern through unknown (as unknown as Record<string, unknown>) which unnecessarily bypasses TypeScript type checking. Replace the double cast with a direct cast to Record<string, unknown> since ReportPeriod has a compatible structure and the intermediate unknown cast is not needed.

### 59. `src/lib/export/csv.ts`  ·  _src/lib_

In src/lib/export/csv.ts around lines 41-43, The slug function is duplicated identically in csv.ts, excel.ts, and pdf.ts files. Extract this function to a centralized location such as a new file at src/lib/export/helpers.ts (or add it to an existing shared utilities file). Create or export the slug function from this centralized location, then remove the duplicate slug function definitions from all three export modules (csv.ts, excel.ts, and pdf.ts) and update each file to import the slug function from the shared location instead.

### 60. `src/lib/export/pdf.ts`  ·  _src/lib_

In src/lib/export/pdf.ts around lines 12-15, The title and period text in the PDF export are not accounting for RTL display when the locale is Arabic. Modify the code where doc.text() is called for report.title and report.period to check if the locale is set to Arabic, and if so, set the text alignment to right-aligned and adjust the x-coordinate positioning to align from the right edge of the page instead of the left. Use the appropriate jsPDF method to set text alignment and calculate the x-position based on the page width to ensure proper RTL layout. SUGGESTED: const { locale = 'ar', filename } = opts; const doc = new jsPDF({ orientation: 'landscape' }); const pageWidth = doc.internal.pageSize.getWidth(); const xPos = locale === 'ar' ? pageWidth - 14 : 14; const align = locale === 'ar' ? 'right' : 'left'; doc.text(report.title, xPos, 16, { align }); doc.setFontSize(10); doc.setTextColor(120); doc.text(report.period, xPos, 22, { align });

### 61. `src/lib/hooks/use-debounced.ts`  ·  _src/lib_

In src/lib/hooks/use-debounced.ts around lines 6-20, The useDebouncedCallback function has performance issues due to storing the timer in state and not memoizing the returned function. Replace the useState call for timer management with useRef so the timer is stored without triggering re-renders. Wrap the returned function with useCallback to create a stable memoized reference across renders. Update the useEffect cleanup dependency array to be empty since you're now using a ref, and access the timer through the ref in the cleanup function and the returned debounced callback.

### 62. `src/lib/hooks/use-org.ts`  ·  _src/lib_

In src/lib/hooks/use-org.ts at line 44, The onError callback in the toast.error call at the useToastMutation function uses a hardcoded generic 'error' string that provides no actionable feedback and cannot be localized. Instead of this hardcoded string, extract the actual error message from the error object passed to the onError callback, or alternatively integrate with the useT hook from @/lib/i18n/use-t.ts to provide a properly localized error message. Consider making the error message customizable by accepting it as a parameter to useToastMutation so different mutations can display context-specific, user-friendly error messages.

### 63. `src/lib/types/payroll.ts`  ·  _src/lib_

In src/lib/types/payroll.ts around lines 92-100, The Settlement interface is missing the id field that is present in all other persisted domain entities like Loan, Payslip, and Document. Determine whether Settlement is a persisted database record or a computed transient summary. If persisted, add an id field of type number as the primary key at the beginning of the Settlement interface. If it is a computed/transient summary not persisted to the database, mark the entire Settlement interface as readonly and add a JSDoc comment documenting that this is not a persistent entity.

### 64. `src/lib/types/tenant.ts`  ·  _src/lib_

In src/lib/types/tenant.ts at line 23, The permissions field in the Admin interface weakens type safety by including Record<string, boolean> in its union type, allowing arbitrary permission codes beyond those defined in PermissionCode. Remove the Record<string, boolean> alternative from the permissions field type definition and keep only Record<PermissionCode, boolean> to enforce strict type-safe permission checking. If there is a legitimate business requirement for dynamic/plugin-based permissions, add a code comment explaining why the escape hatch is necessary.

### 65. `src/lib/utils.ts`  ·  _src/lib_

In src/lib/utils.ts around lines 25-38, The formatDate function has a timezone bug where YYYY-MM-DD strings are parsed as UTC midnight but then displayed in the user's local timezone, causing the date to shift backwards for users in timezones behind UTC. When the date parameter is a string matching the YYYY-MM-DD format, parse it as local midnight instead of UTC by manually constructing the Date object using local time components (split the string on hyphens and use the Date constructor with year, month, and day values). Alternatively, add timeZone: 'UTC' to the options object passed to Intl.DateTimeFormat to ensure consistent UTC display regardless of the user's local timezone.

### 66. `tests/contract/warnings-performance.test.ts`  ·  _tests_

In tests/contract/warnings-performance.test.ts around lines 13 - 66, The warnings-performance.test.ts contract test file currently only covers happy-path scenarios, but similar contract test files for employees, attendance, leaves, and loans include error scenario coverage (403 permission denied, offline failures, error payloads). Add new test cases within the describe block for each warning and performance operation (addWarning, deleteWarning, listPerformanceReviews, createPerformanceReview, deletePerformanceReview) that test error conditions including permission denied responses with 403 status codes and offline/network failures, ensuring the test suite is comprehensive and consistent with other contract test patterns.

### 67. `tests/e2e/us1-auth.spec.ts`  ·  _tests_

In tests/e2e/us1-auth.spec.ts around lines 18 - 21, The test file contains hardcoded fallback credentials in the authentication setup that expose test account credentials in version control. In the fill method calls for email and password input (where getByLabel is used with /email/i and /password/i patterns), remove the hardcoded fallback values ("test@medjat.com" and "password") from the nullish coalescing operators. Either remove the ?? operator and its fallback entirely to require the environment variables be set, or replace the fallbacks with clearly fake placeholders like "REQUIRED_SET_E2E_EMAIL" and "REQUIRED_SET_E2E_PASSWORD" that will fail loudly during test execution if the environment variables are not properly configured.

  ```suggested
    await page.getByLabel(/email/i).fill(process.env.E2E_EMAIL ?? "");
    await page
      .getByLabel(/password/i)
      .fill(process.env.E2E_PASSWORD ?? "");
  ```

### 68. `tests/e2e/us10-support-account.spec.ts`  ·  _tests_

In tests/e2e/us10-support-account.spec.ts around lines 39 - 43, The test "delete account shows last-GM warning for GM" assumes the authenticated user has a General Manager role but does not explicitly set up this state, making the test flaky depending on the credentials in E2E_EMAIL and E2E_PASSWORD. Either use dedicated GM-specific credentials (such as E2E_GM_EMAIL and E2E_GM_PASSWORD) to log in for this test, or add programmatic setup before the test steps to ensure the user is promoted to the GM role, or document clearly in the test setup that the E2E_EMAIL must belong to a GM user.

### 69. `tests/e2e/us10-support-account.spec.ts`  ·  _tests_

In tests/e2e/us10-support-account.spec.ts around lines 33 - 37, In the "change language and appearance" test, add assertions to verify that the language and theme changes actually occurred. After clicking the English button, add an assertion to confirm the language setting changed (you might check for a specific language indicator or UI element that reflects the language change). Similarly, after clicking the Dark button, add an assertion to confirm the theme changed to dark mode (such as verifying a dark mode class is applied or checking for specific dark theme styling). This ensures the test fails if the buttons do not actually update the language or theme as expected.

### 70. `tests/e2e/us2-dashboard.spec.ts`  ·  _tests_

In tests/e2e/us2-dashboard.spec.ts around lines 12 - 15, Remove the hardcoded credential fallback values from the email and password input fields in the test. The fill calls for getByLabel(/email/i) and getByLabel(/password/i) are using the null coalescing operator with hardcoded defaults ("test@medjat.com" and "password" respectively). Remove these fallback values and rely only on the E2E_EMAIL and E2E_PASSWORD environment variables, so that the test fails fast if credentials are not properly configured rather than exposing test credentials in the codebase.

  ```suggested
    await page.getByLabel(/email/i).fill(process.env.E2E_EMAIL ?? "");
    await page
      .getByLabel(/password/i)
      .fill(process.env.E2E_PASSWORD ?? "");
  ```

### 71. `tests/e2e/us3-employees.spec.ts`  ·  _tests_

In tests/e2e/us3-employees.spec.ts around lines 10 - 13, The email and password fill calls in the test contain hardcoded fallback credentials that expose test credentials in version control. Remove the default fallback values from both the email fill statement (getByLabel(/email/i).fill(...)) and the password fill statement (getByLabel(/password/i).fill(...)) so that only the environment variables E2E_EMAIL and E2E_PASSWORD are used directly without any ?? "test@medjat.com" or ?? "password" defaults. If needed, add validation to ensure these required environment variables are set before the test runs, rather than providing hardcoded alternatives.

  ```suggested
    await page.getByLabel(/email/i).fill(process.env.E2E_EMAIL ?? "");
    await page
      .getByLabel(/password/i)
      .fill(process.env.E2E_PASSWORD ?? "");
  ```

### 72. `tests/e2e/us5-payroll.spec.ts`  ·  _tests_

In tests/e2e/us5-payroll.spec.ts at line 14, Add authentication setup before navigating to protected routes in the us5-payroll.spec.ts test suite. Before any page.goto() calls that navigate to protected routes like "/payroll" and "/loans", ensure proper authentication is configured (similar to the pattern used in us4-attendance.spec.ts). This should be done in a beforeEach hook or at the start of each test that accesses these protected routes to prevent navigation failures.

### 73. `tests/e2e/us6-leave.spec.ts`  ·  _tests_

In tests/e2e/us6-leave.spec.ts at line 13, The test is navigating to the protected route "/leaves" without establishing authentication first. Before the page.goto("/leaves") call in the test, add explicit authentication setup to show how the user is authenticated when accessing this protected route. This should follow the same pattern used in the us4-attendance.spec.ts and us5-payroll.spec.ts test files to ensure consistency and clarity about authentication requirements for protected routes.

### 74. `tests/e2e/us7-branches-shifts.spec.ts`  ·  _tests_

In tests/e2e/us7-branches-shifts.spec.ts at line 13, The test file navigates directly to protected routes like /branches, /shifts, and /shifts/schedule without establishing authentication first. Add authentication setup before each page.goto() call that navigates to a protected route. Look at the us4-us6 test files to see the authentication pattern that should be applied here, and ensure all protected route navigation calls (page.goto("/branches"), and any similar calls to /shifts or /shifts/schedule routes) are preceded by the appropriate authentication setup.

### 75. `tests/e2e/us8-reports.spec.ts`  ·  _tests_

In tests/e2e/us8-reports.spec.ts at line 12, The test navigates to the protected route `/reports/attendance` using `page.goto("/reports/attendance")` without any authentication setup, which will cause the test to fail or behave unexpectedly since the route is protected. Add authentication steps before this navigation call, using the same authentication pattern established in the us4-us7 test files, to ensure the user is properly authenticated before accessing the protected reports route.

### 76. `tests/e2e/us9-permissions.spec.ts`  ·  _tests_

In tests/e2e/us9-permissions.spec.ts around lines 28 - 33, The test "restricted admin is blocked from a direct URL (SC-008)" assumes the authenticated user has restricted admin permissions, but there is no explicit setup to ensure this state before the test runs, making it flaky. Either configure the test to use separate environment variables for restricted admin credentials (e.g., E2E_RESTRICTED_EMAIL and E2E_RESTRICTED_PASSWORD) and update the test setup to authenticate with these credentials before navigating to "/settings/company", or programmatically create a restricted admin user with appropriate permissions before the page navigation and expectation checks occur. Document the required test data setup approach in the test or in a seed script README to clarify the expected state.

### 77. `tests/mocks/handlers.ts`  ·  _tests_

In tests/mocks/handlers.ts around lines 6 - 10, The helper functions `ok` and `noData` are identical in implementation, creating unnecessary duplication. Remove the unsafe type assertion `as Record<string, unknown> | unknown[]` from both functions since `HttpResponse.json()` accepts any JSON-serializable value, including `null`. Delete the `noData` function entirely and replace all calls to `noData(...)` throughout the file with `ok(...)` instead, consolidating to a single, properly-typed helper.

# 🟡 ثانوية (Minor) — 37 ملاحظة

### 78. `src/app/(app)/branches/page.tsx`  ·  _src/app_

In src/app/(app)/branches/page.tsx around lines 45 - 48, The Label component in the branch name input field is using the incorrect i18n key. In the code block where the Input field uses setName for the branch name, change the t("company_name") key to the appropriate branch name key (such as t("branch_name")) to ensure the label correctly identifies the field to users.

### 79. `src/app/(app)/branches/page.tsx`  ·  _src/app_

In src/app/(app)/branches/page.tsx around lines 28 - 31, The hardcoded Arabic string "فرع" used as a fallback branch name in the createBranch function call needs to be replaced with an i18n translation key. Update the fallback value within the createBranch call to use the translation function t() with an appropriate key (such as a default branch name translation key) instead of the hardcoded string, following the same i18n pattern already used for the successMessage parameter.

  ```suggested
  const create = useToastMutation(
    (data: Partial<Branch>) => createBranch({ name: name || t("branch"), ...data }),
    { successMessage: t("success"), invalidate: [["org", "branches"] as const] },
  );
  ```

### 80. `src/app/(app)/dashboard/expiring-compliance/page.tsx`  ·  _src/app_

In src/app/(app)/dashboard/expiring-compliance/page.tsx around lines 24 - 27, The back navigation link to the dashboard is using the ArrowRight icon, which points in the wrong direction for a back button. Replace the ArrowRight component with ArrowLeft in the JSX where the Link component with href="/dashboard" is defined. This ensures the icon semantically matches the navigation direction (going back/left instead of forward/right).

### 81. `src/app/(app)/dashboard/status-employees/page.tsx`  ·  _src/app_

In src/app/(app)/dashboard/status-employees/page.tsx around lines 44 - 46, Replace the ArrowRight icon with ArrowLeft in the Link component that navigates back to "/dashboard". The ArrowRight icon is semantically incorrect for back navigation since it points in the wrong direction. Change the ArrowRight import and usage to ArrowLeft to properly indicate the backward navigation direction.

  ```suggested
        <Link href="/dashboard" className="text-brand hover:underline">
          <ArrowLeft className="h-4 w-4" />
        </Link>
  ```

### 82. `src/app/(app)/employees/[id]/page.tsx`  ·  _src/app_

In src/app/(app)/employees/[id]/page.tsx around lines 312 - 319, The Number conversion applied to fd.get("base_salary") lacks validation and can produce NaN if the input is empty or malformed. Before calling onSave with the form data, validate the base_salary value to ensure it is a non-empty string that can be safely converted to a number. You can either add explicit validation checks for the base_salary field before the Number conversion, or consider using a schema validator like Zod to parse and validate all the FormData values at once before passing them to onSave.

  ```suggested
        const fd = new FormData(e.currentTarget);
        onSave({
          name: fd.get("name"),
          phone: fd.get("phone"),
          email: fd.get("email"),
          job_title: fd.get("job_title"),
          base_salary: Number(fd.get("base_salary")) || 0,
        });
  ```

### 83. `src/app/(app)/employees/[id]/settlement/page.tsx`  ·  _src/app_

In src/app/(app)/employees/[id]/settlement/page.tsx around lines 109 - 114, The "Approve" and "Mark Paid" buttons lack protection against double-submission. Add a `disabled` prop to the first Button component (variant="outline" with approveMut.mutate) that is tied to approveMut's pending state, and add a `disabled` prop to the second Button component (variant="secondary" with paidMut.mutate) that is tied to paidMut's pending state. This ensures the buttons become disabled while the respective mutations are in flight, preventing accidental duplicate requests.

  ```suggested
                  <Button variant="outline" onClick={() => approveMut.mutate()} disabled={approveMut.isPending}>
                    {t("approve_settlement")}
                  </Button>
                  <Button variant="secondary" onClick={() => paidMut.mutate()} disabled={paidMut.isPending}>
                    {t("mark_settlement_paid")}
                  </Button>
  ```

### 84. `src/app/(app)/onboarding/page.tsx`  ·  _src/app_

In src/app/(app)/onboarding/page.tsx at line 81, The CardDescription component on the onboarding page is using the i18n key "welcome_back" which semantically suggests a returning user scenario, but this is an onboarding page for new users creating or joining a company. Replace the "welcome_back" key with a more semantically appropriate key such as "onboarding_subtitle" or "choose_setup_method" to better reflect the context of first-time setup. Update the translation key passed to the t() function in the CardDescription to use the new, more appropriate key.

### 85. `src/app/(app)/onboarding/page.tsx`  ·  _src/app_

In src/app/(app)/onboarding/page.tsx around lines 107 - 111, The error message for the name field validation is hardcoded to always display "required" regardless of the actual validation failure type. Instead of displaying a generic "required" message, access the actual error message property from createForm.formState.errors.name.message and display that value. This will ensure that when validation fails due to minimum length requirements or other constraints, the user sees the specific error message appropriate to their input rather than a generic required message.

  ```suggested
                  {createForm.formState.errors.name && (
                    <p className="text-label-sm text-destructive">
                      {createForm.formState.errors.name.message || t("required")}
                    </p>
                  )}
  ```

### 86. `src/app/(app)/onboarding/page.tsx`  ·  _src/app_

In src/app/(app)/onboarding/page.tsx around lines 139 - 143, The error message for the code field is hardcoded to display t("required") instead of showing the actual validation error from the form state. Modify the error display logic in the block that checks joinForm.formState.errors.code to use joinForm.formState.errors.code.message instead of the hardcoded "required" translation key. This will correctly display different error messages based on the actual validation failure type, such as minimum-length violations or other constraint violations.

  ```suggested
                  {joinForm.formState.errors.code && (
                    <p className="text-label-sm text-destructive">
                      {joinForm.formState.errors.code.message || t("required")}
                    </p>
                  )}
  ```

### 87. `src/app/(app)/reports/documents/page.tsx`  ·  _src/app_

In src/app/(app)/reports/documents/page.tsx at line 96, The TableRow component is currently using the array index `i` as the React key, which can cause reconciliation issues when the list changes. Replace the `key={i}` prop in the TableRow element with the unique `id` field from the row object to ensure proper React reconciliation. This will provide a stable, unique identifier for each row regardless of its position in the array.

  ```suggested
{rows.map((r) => (
  <TableRow key={r.id}>
  ```

### 88. `src/app/(app)/settings/assets/page.tsx`  ·  _src/app_

In src/app/(app)/settings/assets/page.tsx at line 92, The onClick handler for the create.mutate call uses Number(value) || 0 which silently converts empty strings to 0, hiding the user's intent when they leave the field blank. Add validation logic in the onClick handler to check that the value field is non-empty before calling create.mutate, and prevent the submission if validation fails. This ensures that empty values are rejected rather than defaulting to 0.

  ```suggested
           <Button
            onClick={() => create.mutate({ name, value: Number(value) })}
            disabled={!name || !value || create.isPending}
           >
  ```

### 89. `src/app/(app)/settings/attendance-method/page.tsx`  ·  _src/app_

In src/app/(app)/settings/attendance-method/page.tsx at line 29, The checkbox field with key "geofence_strict" has a generic label "attendance_method" that does not accurately describe what the field controls, making it unclear to users what they are toggling. Replace the label value with a more descriptive translation key such as "strict_geofence" or "enforce_geofence" that clearly indicates this checkbox controls strict geofence enforcement mode.

### 90. `src/app/(app)/settings/categories/page.tsx`  ·  _src/app_

In src/app/(app)/settings/categories/page.tsx at line 40, The Button component with onClick={() => create.mutate(name)} only checks the !name condition in its disabled prop, allowing users to trigger multiple creation requests by clicking repeatedly. Update the disabled prop to also include create.isPending so the button is disabled both when the name is empty and while the creation mutation is in progress.

  ```suggested
          <Button onClick={() => create.mutate(name)} disabled={!name || create.isPending}>
  ```

### 91. `src/app/(app)/settings/company/page.tsx`  ·  _src/app_

In src/app/(app)/settings/company/page.tsx at line 27, The currency field configuration uses the incorrect translation key `t("amount")` for its label. Locate the object with `key: "currency"` in the settings company page and change its label property from `t("amount")` to `t("currency")` to semantically match the field's purpose and provide the correct label for currency settings.

  ```suggested
        { key: "currency", label: t("currency") },
  ```

### 92. `src/app/(app)/settings/deductions/page.tsx`  ·  _src/app_

In src/app/(app)/settings/deductions/page.tsx at line 24, The ESLint disable comment references a non-existent rule named "react-hooks/set-state-in-effect". Locate this comment in the settings/deductions/page.tsx file and either remove it entirely if the code is not triggering any actual ESLint warnings, or if there is a legitimate exhaustive-deps warning from the react-hooks rules, replace the incorrect rule name with "react-hooks/exhaustive-deps" to properly suppress the actual warning.

  ```suggested
   useEffect(() => {
     if (Array.isArray(data)) setRules(data);
   }, [data]);
  ```

### 93. `src/app/(app)/settings/required-documents/page.tsx`  ·  _src/app_

In src/app/(app)/settings/required-documents/page.tsx around lines 40 - 45, The add function contains a hardcoded Arabic fallback value "وثيقة" for the name field, which breaks internationalization by displaying Arabic text regardless of the user's locale. Replace this hardcoded Arabic text with an appropriate i18n translation key, or alternatively validate that the name field is non-empty and either disable the Add button when name is empty or require the user to enter a name before allowing the create.mutate call to execute.

### 94. `src/app/(app)/team/page.tsx`  ·  _src/app_

In src/app/(app)/team/page.tsx around lines 197 - 203, The Button component displaying t("set_active") uses a static label that doesn't reflect whether the admin is currently active or inactive. Replace the static label with a conditional expression that dynamically displays different translations based on the a.is_active property. Use a ternary operator to show one translation key when a.is_active is true (e.g., t("deactivate") or t("suspend")) and another translation key when a.is_active is false (e.g., t("activate")), so users understand what action will occur when they click the button.

  ```suggested
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => setActive.mutate({ id: a.id, active: !a.is_active })}
                      >
                        {a.is_active ? t("suspend") : t("activate")}
                      </Button>
  ```

### 95. `src/app/(auth)/login/page.tsx`  ·  _src/app_

In src/app/(auth)/login/page.tsx around lines 52 - 64, The catch block in the onEmailSubmit function treats all errors from signInEmail identically, showing the "invalid_credentials" message for authentication failures, network errors, and service errors alike, which can mislead users. Modify the catch block to check the error type or error message to differentiate between authentication-related errors and other failures. For authentication errors (such as invalid credentials), keep the current "invalid_credentials" message, but for other types of errors (network failures, service errors, account disabled), display a more generic error message that accurately reflects the actual problem without suggesting it was a credential issue.

### 96. `src/app/(auth)/signup/page.tsx`  ·  _src/app_

In src/app/(auth)/signup/page.tsx around lines 124 - 126, The confirm password validation error block currently always displays the "required" message regardless of the actual error type. The schema validation can produce both "required" and "mismatch" errors (from the refine function), but only one message is shown. Modify the error display logic in the conditional block where errors.confirm is checked to inspect the actual error message or type and conditionally render either t("required") or t("mismatch") based on which validation failed. This ensures users see the correct error feedback for their specific validation failure.

  ```suggested
            {errors.confirm && (
              <p className="text-label-sm text-destructive">
                {errors.confirm.message === "mismatch" 
                  ? t("passwords_must_match") 
                  : t("required")}
              </p>
            )}
  ```

### 97. `src/app/(auth)/signup/page.tsx`  ·  _src/app_

In src/app/(auth)/signup/page.tsx around lines 75 - 77, The CardDescription in the signup page is using the incorrect i18n key `t("welcome_back")` which conveys a message for returning users rather than new account creation. Replace this key with a more contextually appropriate one such as `t("create_account")` or `t("get_started")` to properly communicate the intended action of signing up for a new account to first-time users.

### 98. `src/app/(auth)/verify-email/page.tsx`  ·  _src/app_

In src/app/(auth)/verify-email/page.tsx around lines 42 - 55, The checkAndContinue function is missing a null check for auth.currentUser at the beginning, which could leave unauthenticated users stuck on the page without an error message. Add a null check at the start of the checkAndContinue function similar to the pattern used in the resend function. If auth.currentUser is null, redirect the user to the login page using router.replace("/login") or similar, ensuring that unauthenticated users cannot proceed further on the verify-email page.

  ```suggested
  async function checkAndContinue() {
    const user = auth.currentUser;
    if (!user) {
      router.replace("/login");
      return;
    }
    setBusy(true);
    try {
      await user.reload();
      if (user.emailVerified) {
        await completeLogin();
        router.replace("/dashboard");
      } else {
        toast.error(t("email_not_verified"));
      }
    } finally {
      setBusy(false);
    }
  }
  ```

### 99. `src/components/attendance/manual-record-sheet.tsx`  ·  _src/components_

In src/components/attendance/manual-record-sheet.tsx at line 27, Remove the unused import statement for `toast` from the "sonner" library in the manual-record-sheet.tsx file. Since the component uses `useToastMutation` for handling notifications instead, the `toast` import is not needed and can be safely deleted to clean up the imports.

### 100. `src/components/attendance/note-dialog.tsx`  ·  _src/components_

In src/components/attendance/note-dialog.tsx around lines 32 - 35, The useEffect hook that syncs record.note to the form field via setValue unconditionally updates the value whenever record.note changes, which overwrites any unsaved edits the user is actively making in the dialog. Add a guard condition in the useEffect that checks the dialog's open state (likely an open or isOpen prop) and only call setValue when the dialog is closed or not actively being edited, preventing external updates from overwriting in-progress edits. Adjust the dependency array accordingly to include the dialog state.

  ```suggested
  useEffect(() => {
    if (open) return;
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setValue(record.note ?? "");
  }, [record.note, open]);
  ```

### 101. `src/components/branch/qr-poster.tsx`  ·  _src/components_

In src/components/branch/qr-poster.tsx around lines 18 - 20, The catch block in the useEffect hook for QRCode.toDataURL silently swallows errors without logging or notifying the user, leaving the loading skeleton visible indefinitely when generation fails. Add proper error handling by logging the error to the console in the catch block and consider introducing an error state variable to surface the failure to the user in the UI. Ensure that when the promise rejects, users receive clear feedback that QR code generation failed rather than experiencing an indefinite loading state.

### 102. `src/components/dashboard/attendance-payroll-summary.tsx`  ·  _src/components_

In src/components/dashboard/attendance-payroll-summary.tsx around lines 84 - 104, The strokeDasharray calculation in the second circle element uses a hardcoded value of 100 as the denominator, but the actual circle circumference with radius 15.5 is approximately 97.39 (calculated as 2π × 15.5). To fix the visual inaccuracy, calculate the actual circumference value and use it in the strokeDasharray formula instead of the hardcoded 100. Replace the strokeDasharray prop with a calculation that uses the proper circumference: multiply the percentage by the actual circumference and divide by 100 for the first value, and use the full circumference as the second value.

### 103. `src/components/employee/employee-card.tsx`  ·  _src/components_

In src/components/employee/employee-card.tsx at line 29, The type assertion `as never` in the `t(employee.status as never)` call defeats TypeScript's type checking by allowing any type to be passed to the translation function. Remove the `as never` cast entirely and instead ensure that the employee.status value is properly typed to match the exact translation keys expected by the i18n function. If the Employee.status is a union type (e.g., "active" | "suspended" | "terminated"), verify that these exact values exist as translation keys in your i18n configuration. If stricter typing is needed, define a type alias for EmployeeStatusKey that represents the valid status values and use that type to annotate the employee object or cast appropriately.

  ```suggested
        {t(employee.status)}
  ```

### 104. `src/components/employee/filters-sheet.tsx`  ·  _src/components_

In src/components/employee/filters-sheet.tsx around lines 120 - 128, The reset button in the filters-sheet component uses the incorrect translation key "reset_permissions" when it should use a translation key that describes resetting filters. Replace the t("reset_permissions") call with the appropriate translation key that semantically matches the button's actual functionality of resetting employee filters, such as t("reset_filters") or equivalent key that exists in your translation files.

  ```suggested
        <Button
          variant="ghost"
          className="w-full"
          onClick={() =>
            onChange({ search: filters.search, page: 1, per_page: filters.per_page })
          }
        >
          {t("reset_filters")}
        </Button>
  ```

### 105. `src/components/layout/app-shell.tsx`  ·  _src/components_

In src/components/layout/app-shell.tsx at line 11, In the aside element that contains the sidebar (with className containing "hidden w-64 shrink-0 border-l bg-sidebar"), change the Tailwind class from border-l to border-r. The sidebar is positioned on the left side as the first child in the flex container, so the border should be on the right edge of the sidebar to properly separate it from the main content area, not on the left edge against the viewport.

  ```suggested
      <aside className="hidden w-64 shrink-0 border-r bg-sidebar md:block">
  ```

### 106. `src/components/layout/mobile-bottom-nav.tsx`  ·  _src/components_

In src/components/layout/mobile-bottom-nav.tsx at line 21, The navigation item in the mobile-bottom-nav.tsx has a semantic mismatch where labelKey is set to "more" but href points to "/support", creating inconsistency in intent. Resolve this by choosing one approach: either change the labelKey from "more" to "nav_support" to match the support href destination, or restructure this item to function as a "more" menu that opens a Sheet component with additional navigation options instead of linking directly to support. Ensure the label and functionality are aligned based on the intended user experience.

  ```suggested
  { href: "/support", labelKey: "nav_support", icon: LifeBuoy },
  ```

### 107. `src/components/payroll/payslip-detail.tsx`  ·  _src/components_

In src/components/payroll/payslip-detail.tsx around lines 101 - 110, The addLine function silently converts invalid numeric input to zero using Number(amount) || 0, which creates unintended zero-amount line items without alerting the user. Add validation logic before the mutate.mutate call to check if the amount input is a valid positive number. If the amount is invalid or missing, prevent the mutation from executing and either return early or display an error message to the user so they are aware their input is invalid rather than having it silently converted to zero.

  ```suggested
  const addLine = () => {
    const numAmount = Number(amount);
    if (isNaN(numAmount)) {
      // Show error toast or inline validation message
      return;
    }
    const lines: PayslipLine[] = [
      ...(slip.lines ?? []),
      { label: label || t("details"), amount: numAmount, type },
    ];
    mutate.mutate(
      { employeeId: slip.employee_id, month: slip.month, lines },
      { onSuccess: () => setOpen(false) },
    );
  };
  ```

### 108. `src/components/report/report-table.tsx`  ·  _src/components_

In src/components/report/report-table.tsx at line 39, The TableCell component in report-table.tsx is rendering null and undefined values as literal text strings ("null" and "undefined") which is confusing for users. Update the cell rendering logic to check if the cell value is null or undefined before converting it to a string. If the value is null or undefined, render an empty string instead, otherwise convert the cell value to a string as before.

  ```suggested
                <TableCell key={j}>{cell ?? "—"}</TableCell>
  ```

### 109. `src/components/settings/settings-form.tsx`  ·  _src/components_

In src/components/settings/settings-form.tsx around lines 66 - 68, In the settings-form.tsx file, the number field handling logic (around the line checking f.type === "number") converts empty strings to 0 using Number(e.target.value). This should be fixed by checking if the input value is empty first and returning null or undefined in that case, while only converting non-empty values to numbers. Modify the ternary expression to add a condition that checks if e.target.value is an empty string before applying the Number conversion.

### 110. `src/components/support/chat-thread.tsx`  ·  _src/components_

In src/components/support/chat-thread.tsx around lines 31 - 37, In the send function, the reply.mutate call's onSuccess callback currently only clears the input with setBody(""). Add a call to refetch() in the onSuccess callback after setBody("") to immediately fetch and display the new message in the chat thread instead of waiting for the next polling cycle. This ensures the user sees their message appear immediately after sending it.

### 111. `src/components/support/new-ticket-form.tsx`  ·  _src/components_

In src/components/support/new-ticket-form.tsx around lines 45 - 48, The SheetTrigger and SheetClose components are using an incorrect `render` prop instead of the correct `asChild` prop that shadcn/ui requires. Replace the `render={<Button size="sm" />}` prop on SheetTrigger with `asChild` and move the Button component to be a child element of SheetTrigger instead of a prop value. Apply the same pattern to the SheetClose component at line 66, replacing any `render` prop with `asChild` and making the target component a direct child element.

### 112. `src/lib/providers/pwa-provider.tsx`  ·  _src/lib_

In src/lib/providers/pwa-provider.tsx at line 12, The service worker registration in the catch block of navigator.serviceWorker.register('/sw.js') is silently swallowing all errors without logging them. Replace the empty catch handler with one that logs the error. SUGGESTED: navigator.serviceWorker.register('/sw.js').catch((err) => { console.error('Service worker registration failed:', err); });

### 113. `tests/e2e/us1-auth.spec.ts`  ·  _tests_

In tests/e2e/us1-auth.spec.ts around lines 40 - 41, The test file has an inconsistency in credential fallback handling: lines 40-41 use empty-string fallbacks with the `??` operator for E2E_EMAIL and E2E_PASSWORD, while lines 18 and 21 use hardcoded credentials. Standardize the credential fallback strategy across all three tests by updating lines 18 and 21 to use the same empty-string fallback pattern with `??` operator (matching the approach on lines 40-41), ensuring consistent behavior when environment variables are missing throughout the entire test suite.

### 114. `tests/e2e/us9-permissions.spec.ts`  ·  _tests_

In tests/e2e/us9-permissions.spec.ts around lines 35 - 40, The test function "customize then reset permissions" has a misleading name because it does not actually customize permissions before resetting them. Either rename the test.skip function to accurately reflect that it only tests resetting permissions (such as "reset permissions"), or add the necessary steps between navigating to the team page and clicking the reset button to actually customize some permissions first before performing the reset. Ensure the test implementation matches its descriptive name.

  ```suggested
  test.skip("customize then reset permissions", async ({ page }) => {
    await page.goto("/team");
    await page.getByRole("button", { name: /edit permissions|تعديل الصلاحيات/i }).first().click();
    // Customize: toggle a permission
    await page.getByRole("checkbox", { name: /view reports|عرض التقارير/i }).click();
    await page.getByRole("button", { name: /^(save|حفظ)$/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
    // Now reset
    await page.getByRole("button", { name: /edit permissions|تعديل الصلاحيات/i }).first().click();
    await page.getByRole("button", { name: /reset|إعادة الضبط/i }).click();
    await expect(page.getByText(/success|تم بنجاح/i)).toBeVisible();
  });
  ```

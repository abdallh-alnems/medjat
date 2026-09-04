# Tasks: Permedjat Central — Web Edition

**Input**: Design documents from `/specs/003-permedjat-central-web/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/api-catalog.md

**Tests**: Included — plan D14 commits to Vitest + RTL (unit/component), MSW (contract
mocks), and Playwright (the per-story Independent Tests from the spec).

**Organization**: Tasks are grouped by user story. v1 ships all stories (full parity),
but stories are still ordered/checkpointed so each is independently implementable and
testable. **MVP = Setup + Foundational + US1.**

**Base path**: all paths are under `frontend/web/manager/` unless noted.

## Path Conventions

- App routes: `src/app/(auth|app)/…`, proxy `src/app/api/[...path]/route.ts`
- Logic: `src/lib/{api,firebase,hooks,stores,providers,i18n,permissions,export,types}`
- UI: `src/components/{layout,ui,<domain>}`
- Tests: `tests/{unit,component,contract,e2e}` + MSW handlers in `tests/mocks`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, tooling, theme, fonts.

- [X] T001 Scaffold Next.js 16 App-Router TS app at `frontend/web/manager/` (src dir, ESLint) per quickstart.md
- [X] T002 Install runtime deps (react-query, zustand, axios, firebase, react-hook-form, zod, shadcn/@base-ui, tailwind v4, lucide, sonner, next-themes, recharts, date-fns, dayjs, jspdf, html2canvas, xlsx, react-day-picker, react-markdown, remark-gfm, qrcode, input-otp) in `package.json`
- [X] T003 [P] Install + configure dev tooling (Vitest, RTL, jsdom, MSW, Playwright, Prettier + tailwind plugin) in `package.json`, `vitest.config.ts`, `playwright.config.ts`, `.prettierrc`
- [X] T004 [P] Initialize shadcn and add base UI primitives (button, input, label, card, dialog, sheet, dropdown-menu, select, tabs, badge, avatar, skeleton, popover, calendar, separator, sonner, input-otp, textarea, table) in `src/components/ui/`
- [X] T005 [P] Port Permedjat theme tokens (brand #2563EB/#60A5FA, warm accent, canvas/surface, error/warning/success, radii) into `src/app/globals.css` with light/dark CSS variables
- [X] T006 [P] Add self-hosted web fonts (IBM Plex Sans Arabic primary, Geist) to `public/fonts/` and wire in `src/app/layout.tsx` (re-acquire real fonts — do NOT copy corrupted Flutter Geist .ttf)
- [X] T007 [P] Create `.env.local.example` (server-only SECURITY_USER/KEY, NEXT_PUBLIC_API_HOST, NEXT_PUBLIC_FIREBASE_*) and `README.md`
- [X] T008 [P] Add PWA assets: `public/manifest.json` (Permedjat papyrus icons, RTL, theme color), `public/icons/`, shell `public/sw.js` (offline only, no push)

**Checkpoint**: App builds and runs an empty themed shell.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The security boundary, auth/tenant/session, providers, shell, i18n,
permissions, shared utilities. **No user story can start until this is done.**

- [X] T009 Implement BFF proxy `src/app/api/[...path]/route.ts` — forward to `NEXT_PUBLIC_API_HOST`, inject Basic auth, pass through `X-Firebase-Token`/`X-Tenant-Id`/`X-Device-Id`, GET/POST/OPTIONS, error passthrough
- [X] T010 Implement `src/lib/api/client.ts` (browser axios baseURL `/api`, server client) with `apiGet`/`apiPost` and response interceptor (per research D2)
- [X] T011 Add axios request interceptor attaching current Firebase ID token + tenant id + device id headers in `src/lib/api/client.ts`
- [X] T012 [P] Implement `src/lib/firebase/config.ts` (app, auth, remote-config, analytics — no messaging)
- [X] T013 [P] Implement `src/lib/firebase/auth.ts` (email/password, Google popup, Apple OAuth popup, signOut, getIdToken, onAuthChange, email verification, password reset)
- [X] T014 [P] Implement device-id util (`src/lib/utils.ts` or `src/lib/hooks/use-device-id.ts`) — stable id in localStorage
- [X] T015 [P] Create `src/lib/stores/auth-store.ts` (persisted Zustand: user, isLoggedIn) and `src/lib/stores/tenant-store.ts` (tenant id/context)
- [X] T016 [P] Create providers: `src/lib/providers/query-provider.tsx` (staleTime 60s, retry 2), `theme-provider.tsx` (next-themes), `pwa-provider.tsx` (SW register only)
- [X] T017 [P] Implement maintenance gate `src/lib/providers/maintenance-gate.tsx` reading Firebase Remote Config flag (research D12) + `src/components/maintenance/maintenance-screen.tsx`
- [X] T018 [P] Port i18n dictionaries from `locale/ar.dart` + `locale/en.dart` to `src/lib/i18n/{ar,en}.ts`, add `useT()` + dir/locale store
- [X] T019 [P] Implement currency/date/number formatters (EGP, Arabic-Indic/Latin) in `src/lib/utils.ts`
- [X] T020 [P] Port permission/role model from `app/roles/list_permissions.php` to `src/lib/permissions/` + `use-permissions` hook + `<Can>` guard
- [X] T021 [P] Port shared entity types from `lib/data/model/*.dart` to `src/lib/types/*.ts` (per data-model.md)
- [X] T022 [P] Implement export utilities `src/lib/export/{pdf.ts,excel.ts,csv.ts}` (jsPDF/xlsx/CSV)
- [X] T023 Implement `src/lib/hooks/use-auth.ts` + `use-auth-token.ts` (Firebase login → `login.php`, set user/tenant, logout on superseded/expiry)
- [X] T024 Implement root layout `src/app/layout.tsx` (RTL/lang, fonts, providers, Toaster) and `(app)/layout.tsx` AppShell with auth+tenant route guard
- [X] T025 [P] Build app shell `src/components/layout/{app-shell,sidebar-nav,topbar,mobile-bottom-nav}.tsx` (nav items gated by permissions; topbar includes persisted language ar/en toggle + appearance light/dark/system toggle — FR-031)
- [X] T026 [P] Setup MSW base `tests/mocks/{server,handlers}.ts` + Vitest setup wiring the contract catalog

**Checkpoint**: An authenticated, tenant-scoped, themed shell with guarded empty routes.

---

## Phase 3: User Story 1 - Auth & onboarding (Priority: P1) 🎯 MVP

**Goal**: Sign in (email/pw, Google, Apple), verify email, reset password, onboarding
(create/join company), logout.
**Independent Test**: Log in known account → dashboard route reachable & tenant set;
no-tenant account → onboarding; logout clears session.

- [X] T027 [P] [US1] Auth API module `src/lib/api/auth.ts` (login, send_verification, send_password_reset, delete_account, notification_prefs) per contracts
- [X] T028 [P] [US1] Tenant API module `src/lib/api/tenant.ts` (create, join)
- [X] T029 [P] [US1] Contract tests (MSW) for auth + tenant in `tests/contract/auth.test.ts` (success/empty/4xx/offline/session-superseded)
- [X] T030 [US1] Auth route group + `(auth)/layout.tsx`; login page `src/app/(auth)/login/page.tsx` (email/pw + Google + Apple buttons, react-hook-form + zod)
- [X] T031 [P] [US1] Signup page `src/app/(auth)/signup/page.tsx` (name/email/password/confirm, validation)
- [X] T032 [P] [US1] Verify-email page `src/app/(auth)/verify-email/page.tsx` (resend, gate until verified)
- [X] T033 [P] [US1] Forgot-password page `src/app/(auth)/forgot-password/page.tsx` (request + confirm new password)
- [X] T034 [US1] Onboarding page `src/app/(app)/onboarding/page.tsx` (create company / join via invite code) wired to tenant API + tenant-store
- [X] T035 [US1] Wire session lifecycle: redirect rules (no-tenant→onboarding, unverified→verify), logout action, superseded/expiry sign-out
- [X] T036 [US1] Playwright e2e `tests/e2e/us1-auth.spec.ts` (login→dashboard, no-tenant→onboarding, logout)

**Checkpoint**: A user can authenticate and reach a tenant-scoped shell. MVP boundary.

---

## Phase 4: User Story 2 - Dashboard (Priority: P1)

**Goal**: Company at-a-glance — today's counts, attendance rate, branch comparison,
pending leave/break counts, payroll summary, category distribution, status & expiring
compliance drill-downs.
**Independent Test**: Dashboard renders correct seeded values; comparison ranks branches;
pending counts link to lists.

- [X] T037 [P] [US2] Dashboard API module `src/lib/api/dashboard.ts` (overview, live_attendance) + query hooks
- [X] T038 [P] [US2] Contract test `tests/contract/dashboard.test.ts`
- [X] T039 [P] [US2] Stat cards + summary components `src/components/dashboard/{stat-card,payroll-summary,attendance-summary}.tsx`
- [X] T040 [P] [US2] Branch comparison (recharts) `src/components/dashboard/branch-comparison.tsx` + category distribution chart
- [X] T041 [US2] Dashboard page `src/app/(app)/dashboard/page.tsx` assembling cards/charts/pending counts with loading/empty/error states
- [X] T042 [P] [US2] Status-employees + expiring-compliance drill-down pages `src/app/(app)/dashboard/{status-employees,expiring-compliance}/page.tsx`
- [X] T043 [US2] Playwright e2e `tests/e2e/us2-dashboard.spec.ts`

**Checkpoint**: Dashboard fully functional.

---

## Phase 5: User Story 3 - Employees (Priority: P1)

**Goal**: List/search/filter/sort/customize, add, view/edit detail, documents, biometric
view/delete, settlement → terminate, terminated list.
**Independent Test**: Add → find via filters → edit → attach/verify doc → settle/terminate
→ appears in terminated list.

- [X] T044 [P] [US3] Employees API module `src/lib/api/employees.ts` (list, get_profile, create, update, delete, terminated, reactivate, suspend, attendance_history, financial_summary, ytd, missing_documents, activation_code)
- [X] T044a [P] [US3] Warnings + performance-review API `src/lib/api/{warnings,performance}.ts` (`app/warnings/{add,delete}.php`, `app/performance/{review_list,review_create,review_delete}.php`) + contract test `tests/contract/warnings-performance.test.ts`
- [X] T045 [P] [US3] Documents API module `src/lib/api/documents.ts` (employee docs upload/update/verify/reject/request/delete, view) + biometric `src/lib/api/biometric.ts` (status, delete)
- [X] T046 [P] [US3] Contract tests `tests/contract/employees.test.ts`, `tests/contract/documents.test.ts`
- [X] T047 [P] [US3] Employee list components `src/components/employee/{employee-card,filters-sheet,sort-menu}.tsx` (branch/shift/category/status filters, sort, customize view)
- [X] T048 [US3] Employees list page `src/app/(app)/employees/page.tsx` (search, filters, sort, pagination, empty/permission states)
- [X] T049 [US3] Employee detail page `src/app/(app)/employees/[id]/page.tsx` (profile view/edit, tabs: financials, attendance history, warnings [add/delete], performance reviews [create/delete]) using T044/T044a APIs
- [X] T050 [P] [US3] Add-employee page `src/app/(app)/employees/new/page.tsx` (form + validation)
- [X] T051 [P] [US3] Employee documents page `src/app/(app)/employees/[id]/documents/page.tsx` (upload/verify/reject/request, biometric status + delete)
- [X] T052 [US3] Settlement page `src/app/(app)/employees/[id]/settlement/page.tsx` (preview/save/approve/mark-paid) using settlements API
- [X] T053 [P] [US3] Terminated employees page `src/app/(app)/terminated/page.tsx` (list + re-hire)
- [X] T054 [US3] Playwright e2e `tests/e2e/us3-employees.spec.ts`

**Checkpoint**: Employee lifecycle fully functional.

---

## Phase 6: User Story 4 - Attendance (Priority: P1)

**Goal**: Live/today board (25s poll), history, manual record (single + batch), set-day
status, notes, export. No self check-in.
**Independent Test**: Record manual attendance + note → persists; export day → file;
empty export → message.

- [X] T055 [P] [US4] Attendance API module `src/lib/api/attendance.ts` (get_branch_attendance, manual_check_in single+batch, set_day_status, update_note)
- [X] T056 [P] [US4] Contract test `tests/contract/attendance.test.ts`
- [X] T057 [P] [US4] Attendance table + components `src/components/attendance/{attendance-table,manual-record-sheet,note-dialog,live-board}.tsx`
- [X] T058 [US4] Attendance page `src/app/(app)/attendance/page.tsx` (live board with `refetchInterval: 25000`, day picker, batch select, export, sort by name/status/check-in)
- [X] T059 [US4] Wire attendance export (PDF/Excel) via `src/lib/export` + no-records message
- [X] T060 [US4] Playwright e2e `tests/e2e/us4-attendance.spec.ts` (incl. SC-004 assertion: record manual attendance completes in < 1 min)

**Checkpoint**: Attendance management fully functional.

---

## Phase 7: User Story 5 - Payroll, loans & adjustments (Priority: P2)

**Goal**: Payroll by month/year, per-employee net breakdown, approve/disburse, bulk
adjustments, loans, allowances/manual deductions/bonuses, payslip PDF/Excel, bank CSV.
**Independent Test**: Open period → bulk adjust selected → nets update; payslip export;
loan affects deductions.

- [X] T061 [P] [US5] Payroll API module `src/lib/api/payroll.ts` (list_slips, live, generate, approve[_bulk], revert, mark_paid, disburse[_all], override_line, get_slip_pdf, eosb_calculate, export_bank_file, bank_file_preview, audit_log)
- [X] T062 [P] [US5] Adjustments/allowances/deductions API `src/lib/api/{bulk-adjustments,allowances,deductions}.ts` + loans `src/lib/api/loans.ts`
- [X] T063 [P] [US5] Contract tests `tests/contract/payroll.test.ts`, `tests/contract/loans.test.ts`
- [X] T064 [P] [US5] Payroll components `src/components/payroll/{payslip-row,payslip-detail,bulk-adjust-sheet,period-selector}.tsx`
- [X] T065 [US5] Payroll page `src/app/(app)/payroll/page.tsx` (month/year period, totals rollup, approve/disburse, line override)
- [X] T066 [P] [US5] Bulk adjustments pages `src/app/(app)/payroll/bulk-adjustments/{page,new,[id]}/page.tsx` (create across scope, view detail, remove member)
- [X] T067 [P] [US5] Loans page `src/app/(app)/loans/page.tsx` (list, create, approve, cancel)
- [X] T068 [US5] Wire payslip PDF/Excel export + bank-file CSV via `src/lib/export`
- [X] T069 [US5] Playwright e2e `tests/e2e/us5-payroll.spec.ts` (incl. SC-004 assertion: view employee payroll completes in < 1 min)

**Checkpoint**: Payroll/loans/adjustments functional.

---

## Phase 8: User Story 6 - Leave & permission requests (Priority: P2)

**Goal**: Review/approve/reject leave, create leave (incl. recurring), balances; act on
break/permission requests (approve/reject/postpone).
**Independent Test**: Approve/reject leave → status + dashboard count update; create leave;
act on a break request.

- [X] T070 [P] [US6] Leaves API module `src/lib/api/leaves.ts` (list, create, create_recurring, approve, reject, convert_to_absence, get_balance, rollover) + breaks `src/lib/api/breaks.ts` (list, approve, reject, postpone, create_for)
- [X] T071 [P] [US6] Contract test `tests/contract/leaves.test.ts`
- [X] T072 [P] [US6] Leave/break components `src/components/leave/{leave-row,add-leave-sheet,break-row}.tsx`
- [X] T073 [US6] Leaves page `src/app/(app)/leaves/page.tsx` (pending queue, approve/reject, create)
- [X] T074 [P] [US6] Breaks page `src/app/(app)/breaks/page.tsx` (approve/reject/postpone)
- [X] T075 [US6] Playwright e2e `tests/e2e/us6-leave.spec.ts` (incl. SC-004 assertion: approve a leave request completes in < 1 min)

**Checkpoint**: Approvals functional.

---

## Phase 9: User Story 7 - Branches, shifts & schedule (Priority: P2)

**Goal**: Branches + geofence (browser geolocation + manual fallback) + QR poster; shifts
+ members + assignment; weekly schedule edit/publish.
**Independent Test**: Create branch + location → usable as filter; QR poster prints;
assign shift / edit weekly schedule persists.

- [X] T076 [P] [US7] Branches API `src/lib/api/branches.ts` (list, create, update, update_attendance_method, generate_qr, set_method_override) + shifts/schedule API `src/lib/api/{shifts,schedule}.ts`
- [X] T077 [P] [US7] Contract test `tests/contract/branches-shifts.test.ts`
- [X] T078 [P] [US7] Branch location capture `src/components/branch/branch-location-sheet.tsx` (Geolocation API + manual lat/lng) + QR poster `src/components/branch/qr-poster.tsx` (qrcode)
- [X] T079 [US7] Branches pages `src/app/(app)/branches/page.tsx` + `branches/[id]/qr/page.tsx`
- [X] T080 [P] [US7] Shifts pages `src/app/(app)/shifts/{page,assign,members}/page.tsx`
- [X] T081 [US7] Weekly schedule page `src/app/(app)/shifts/schedule/page.tsx` (grid assign/clear/copy-week/publish)
- [X] T082 [US7] Playwright e2e `tests/e2e/us7-branches-shifts.spec.ts`

**Checkpoint**: Org structure functional.

---

## Phase 10: User Story 8 - Reports & exports (Priority: P2)

**Goal**: Attendance, payroll, employees, leaves, documents reports for a period →
export PDF/Excel (CSV where tabular).
**Independent Test**: Select report + period → produced; export → correctly formatted file.

- [X] T083 [P] [US8] Reports API `src/lib/api/reports.ts` (attendance, payroll, employees, leaves) + document reports `src/lib/api/document-reports.ts` (expiring_soon, expired, missing, stats)
- [X] T084 [P] [US8] Contract test `tests/contract/reports.test.ts`
- [X] T085 [P] [US8] Report components `src/components/report/{report-period-selector,report-table,report-export}.tsx`
- [X] T086 [US8] Reports hub + pages `src/app/(app)/reports/{page,attendance,payroll,employees,leaves,documents}/page.tsx` with PDF/Excel export
- [X] T087 [US8] Playwright e2e `tests/e2e/us8-reports.spec.ts`

**Checkpoint**: Reporting functional.

---

## Phase 11: User Story 9 - Settings, team & permissions (Priority: P2)

**Goal**: Company settings (company, deductions, leave incl. carryover/encashments,
statutory payroll, attendance method, required documents + submissions, categories,
assets); team (invite admins, role+branch); per-admin permission overrides (GM locked).
**Independent Test**: Edit a setting → enforced; invite admin → pending+code; customize/
reset permissions; restricted admin blocked from action and direct URL.

- [X] T088 [P] [US9] Settings API `src/lib/api/settings.ts` (company, statutory_payroll, leave_settings, carryover policies, encashments) + required-docs `src/lib/api/required-documents.ts`
- [X] T089 [P] [US9] Managers/permissions API `src/lib/api/managers.ts` (invite, list_invitations, cancel/resend, list_admins, update_admin, set_active, remove, get/update/reset permissions) + categories `src/lib/api/categories.ts` + assets `src/lib/api/assets.ts`
- [X] T090 [P] [US9] Contract tests `tests/contract/settings.test.ts`, `tests/contract/managers.test.ts`
- [X] T091 [P] [US9] Settings hub + components `src/components/settings/*` and pages `src/app/(app)/settings/{company,deductions,leave,leave/carryover-policies,leave/encashments,statutory,attendance-method,required-documents,required-documents/submissions,categories,assets}/page.tsx`
- [X] T092 [US9] Team page `src/app/(app)/team/page.tsx` (admins list, invite admin w/ role+branch, invitation code, cancel/resend, set active/remove)
- [X] T093 [US9] Per-admin permissions editor (override + reset to role default, GM locked) in team page/components
- [X] T094 [US9] Enforce route + action guards for restricted admins (server-truth + `<Can>`); block direct-URL access
- [X] T095 [US9] Playwright e2e `tests/e2e/us9-permissions.spec.ts` (restricted admin blocked incl. direct URL — SC-008)

**Checkpoint**: Configuration + governance functional.

---

## Phase 12: User Story 10 - Support, notifications, audit & account (Priority: P3)

**Goal**: Support tickets + chat (poll new replies); notifications list + prefs; activity
log; account (language/appearance, delete account with last-GM warning).
**Independent Test**: Create ticket + send message → recorded; notifications list+prefs;
audit log lists actions; change language/appearance; delete account warning.

- [X] T096 [P] [US10] Support API `src/lib/api/support.ts` (list, create, messages w/ after_id, reply, close) + notifications `src/lib/api/notifications.ts` (list, read, prefs) + audit `src/lib/api/audit.ts`
- [X] T097 [P] [US10] Contract test `tests/contract/support-notifications.test.ts`
- [X] T098 [P] [US10] Support components `src/components/support/{ticket-row,chat-thread,new-ticket-form}.tsx` (react-markdown)
- [X] T099 [US10] Support pages `src/app/(app)/support/{page,[id]}/page.tsx` (list, chat with poll, new, close)
- [X] T100 [P] [US10] Notifications page `src/app/(app)/notifications/page.tsx` (list, mark read, preferences)
- [X] T101 [P] [US10] Activity log page `src/app/(app)/activity-log/page.tsx`
- [X] T102 [US10] Account page `src/app/(app)/account/page.tsx` (language, appearance, delete account w/ last-GM warning)
- [X] T103 [US10] Playwright e2e `tests/e2e/us10-support-account.spec.ts`

**Checkpoint**: All user stories complete — full parity.

---

## Phase 13: Polish & Cross-Cutting Concerns

**Purpose**: Quality, performance, accessibility, release readiness.

- [X] T104 [P] PWA finalization: manifest/icons/installability audit, offline shell behavior (SC-009)
- [X] T105 [P] RTL/LTR + i18n audit across all screens; EGP/date/number formatting (SC-007)
- [X] T106 [P] Loading/empty/error/retry state pass across all data views (FR-034)
- [X] T107 [P] Security verification: confirm SECURITY_USER/KEY never reach the browser; all data via `/api` (SC-006)
- [X] T108 [P] Permission-matrix review across roles incl. direct-URL guards (SC-008)
- [X] T109 [P] Performance: list/detail < 2s for 500 employees; pagination/virtualization where needed (SC-005)
- [X] T110 [P] Accessibility pass (focus, labels, keyboard nav, contrast)
- [X] T111 [P] Analytics (Firebase) + error boundaries/logging (research D14 observability)
- [X] T112 Deployment config (Vercel default): env split, Firebase authorized domains, Google/Apple web providers (research D13) + production smoke test against SC-002/SC-003

---

## Dependencies & Execution Order

- **Phase 1 (Setup)** → **Phase 2 (Foundational)** block everything.
- **US1 (Auth)** must precede all other stories (session + tenant required).
- After US1, **US2–US10 are largely independent** and can proceed in parallel by area;
  US3 (Employees) is a soft prerequisite for the richest flows in US4/US5/US6 (employee
  pickers), but each story stands up against mocked data for its Independent Test.
- **Phase 13 (Polish)** runs after the stories it audits.

## Story → independent test mapping

| Story | Independent test (e2e task) |
|-------|------------------------------|
| US1 | T036 — login→dashboard, no-tenant→onboarding, logout |
| US2 | T043 — dashboard cards/comparison/pending |
| US3 | T054 — employee add→filter→edit→doc→settle→terminated |
| US4 | T060 — manual record + note + export |
| US5 | T069 — period totals + bulk adjust + payslip export + loan |
| US6 | T075 — approve/reject leave + break action |
| US7 | T082 — branch+geo+QR, shift assign, schedule publish |
| US8 | T087 — generate + export reports |
| US9 | T095 — setting edit, invite admin, permission override + direct-URL block |
| US10 | T103 — ticket chat, notifications/prefs, audit, account/delete |

## Parallel execution examples

- **Setup**: T003, T004, T005, T006, T007, T008 in parallel after T001/T002.
- **Foundational**: T012–T022 (different files) in parallel after T009–T011.
- **Within a story**: API module + contract test + components (the `[P]` tasks) in
  parallel, then the page task that composes them, then the e2e task.

## Implementation strategy

1. **MVP** = Phase 1 + Phase 2 + Phase 3 (US1). Demonstrates auth + tenant + shell.
2. Then build P1 stories US2→US3→US4 for a usable daily-ops product.
3. Then P2 (US5–US9) and P3 (US10) — all required for the single-release full-parity v1.
4. Phase 13 polish, then deploy (T112).

**Totals**: 113 tasks — Setup 8, Foundational 18, US1 10, US2 7, US3 12, US4 6, US5 9,
US6 6, US7 7, US8 5, US9 8, US10 8, Polish 9.

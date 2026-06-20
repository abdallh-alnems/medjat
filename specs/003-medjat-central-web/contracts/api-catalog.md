# Phase 1 — Backend API Contract Catalog

The web client consumes the **existing** Medjat PHP backend through the Next.js proxy.
Browser calls target `/api/<path>`; the proxy forwards to `${API_HOST}/<path>` with:

- `Authorization: Basic base64(SECURITY_USER:SECURITY_KEY)` (server-injected, never in browser)
- `X-Firebase-Token: <Firebase ID token>` (forwarded from the request)
- `X-Tenant-Id: <company id>` (forwarded)
- `X-Device-Id: <stable browser id>` (forwarded)

Paths below are relative to `API_HOST` (ported verbatim from
`lib/core/constant/id/app_links.dart`). Method conventions: list/get = GET; create/update/
delete/action = POST (the PHP endpoints accept POST bodies). This catalog is the source of
truth for the per-domain `src/lib/api/*` modules and MSW mocks.

## Auth & account
| Path | Purpose |
|------|---------|
| `app/auth/login.php` | Exchange Firebase token → user + tenant context (also "me") |
| `app/auth/logout.php` | End backend session |
| `app/auth/send_verification.php` | Resend email verification |
| `app/auth/send_password_reset.php` | Send password reset |
| `app/auth/update_profile.php` | Update name/profile |
| `app/auth/update_fcm_token.php` | (omitted on web — no Web Push v1) |
| `app/auth/notification_prefs.php` | Get/set notification preferences |
| `app/auth/delete_account.php` | Delete own account (last-GM warning) |

## Tenant onboarding
| `app/tenant/create.php` | Create company |
| `app/tenant/join.php` | Join company via invite code |

## Dashboard
| `app/dashboard/overview.php` | Dashboard summary (counts, branch comparison, payroll, etc.) |
| `app/dashboard/live_attendance.php` | Live/today board (poll 25s) |

## Employees
| `app/employees/list.php` | List/search/filter employees |
| `app/employees/get_profile.php?id=` | Employee detail |
| `app/employees/create.php` · `update.php` · `delete.php` | CRUD |
| `app/employees/list_terminated.php` · `reactivate.php` | Terminated + re-hire |
| `app/employees/suspend.php` · `end_suspension.php` · `get_suspensions.php?employee_id=` | Suspensions |
| `app/employees/expiring_compliance.php` | Expiring compliance for dashboard |
| `app/employees/get_documents.php?employee_id=[&doc_id=]` | Employee documents |
| `app/employees/upload_document.php` · `update_document.php` · `delete_document.php` | Doc mgmt |
| `app/employees/verify_document.php` · `reject_document.php` · `request_document.php` | Doc workflow |
| `app/employees/get_missing_documents.php?employee_id=` | Missing required docs |
| `app/employees/activation_code.php?id=` | Employee app activation code |
| `app/employees/get_attendance_history.php?employee_id=&(month|from&to)=` | Attendance history |
| `app/employees/get_financial_summary.php?employee_id=&month=` | Monthly financials |
| `app/employees/get_year_to_date.php?employee_id=&year=` | YTD |

## Required documents (tenant-level) & document reports
| `app/documents/get_required.php` · `create_required.php` · `update_required.php` · `delete_required.php` · `toggle_required.php` · `mark_expired.php` | Required-doc types |
| `app/documents/get_required_submissions.php?required_document_id=` | Submissions |
| `app/documents/view.php?id=` | View a document file |
| `app/documents/reports_expiring_soon.php` · `reports_expired.php` · `reports_missing.php` · `reports_stats.php` | Documents report |

## Branches
| `app/branches/list.php[?id=]` | List/single branch |
| `app/branches/create.php` · `update.php` | CRUD |
| `app/branches/update_attendance_method.php` | Per-branch method |
| `app/branches/generate_qr.php` | Branch QR poster token |
| `app/attendance/set_method_override.php` | Branch/category/employee method override |

## Attendance
| `app/attendance/get_branch_attendance.php` | Day/branch attendance |
| `app/attendance/manual_check_in.php` | Manual record (single + batch) |
| `app/attendance/set_day_status.php` | Set a day's status |
| `app/attendance/update_note.php` | Add/edit/delete record note |

## Payroll, allowances, deductions, bulk adjustments
| `app/payroll/list_slips.php` · `live.php` · `generate.php` | Payroll period + slips |
| `app/payroll/approve.php[?id=]` · `approve_bulk.php` · `revert.php` | Approve/revert |
| `app/payroll/mark_paid.php` · `disburse.php` · `disburse_all.php` | Disbursement |
| `app/payroll/override_line.php` | Edit a payslip line |
| `app/payroll/get_slip_pdf.php?employee_id=&month=` | Backend payslip PDF |
| `app/payroll/eosb_calculate.php?employee_id=` | End-of-service calc |
| `app/payroll/export_bank_file.php` (CSV) · `bank_file_preview.php` | Bank file |
| `app/payroll/audit_log.php` | Payroll audit |
| `app/allowances/list.php?employee_id=` · `create.php` · `update.php` · `delete.php` | Allowances |
| `app/deductions/get_rules.php` · `save_config.php` | Deduction config |
| `app/deductions/add_manual.php` · `update_manual.php` · `delete_manual.php` | Manual deductions |
| `app/bonuses/add_manual.php` · `update_manual.php` · `delete_manual.php` | Manual bonuses |
| `app/payroll/bulk_adjust.php` | Quick bulk adjust |
| `app/bulk_adjustments/list.php` · `get.php` · `create.php` · `update.php` · `delete.php` · `remove_member.php` | Tracked batches |

## Loans & settlements
| `app/loans/list.php` · `get.php?id=` · `create.php` · `approve.php` · `cancel.php` | Loans |
| `app/settlements/get.php?employee_id=` · `preview.php?employee_id=&last_working_day=` | Settlement |
| `app/settlements/save.php` · `approve.php` · `mark_paid.php` | Settlement workflow |

## Leaves & breaks
| `app/leaves/list.php` · `create.php` · `create_recurring.php` | Leaves |
| `app/leaves/approve.php?id=` · `reject.php?id=` · `convert_to_absence.php?id=` | Workflow |
| `app/leaves/get_balance.php` · `rollover.php` | Balance |
| `app/leaves/carryover_policies_list.php` · `carryover_policy_save.php` · `carryover_policy_delete.php` | Carryover |
| `app/leaves/encashments_list.php` | Encashments |
| `app/settings/leave_settings.php` | Leave settings |
| `app/breaks/list.php` · `approve.php` · `reject.php` · `postpone.php` · `create_for.php` | Permission/break requests |

## Shifts & schedule
| `app/shifts/list.php` · `create.php` · `update.php?id=` · `delete.php?id=` | Shifts |
| `app/shifts/assign.php` · `unassign.php` | Membership |
| `app/schedule/week.php` · `assign.php` · `clear.php` · `copy_week.php` · `publish.php` | Weekly schedule |

## Categories
| `app/categories/list.php` · `create.php` · `update.php` · `delete.php` · `assign.php` | Categories |

## Managers / team / permissions
| `app/managers/invite.php` · `list_invitations.php` · `cancel_invitation.php?id=` · `resend_invitation.php?id=` | Invitations |
| `app/managers/list_admins.php` · `update_admin.php` · `set_admin_active.php` · `remove_admin.php` | Admins |
| `app/managers/get_admin_permissions.php?admin_id=` · `update_admin_permissions.php` · `reset_admin_permissions.php` | Permission overrides |
| `app/roles/list_permissions.php` | Role → default permissions |

## Biometric (view/delete only on web)
| `app/biometric/status.php?employee_id=` | Enrollment status |
| `app/biometric/enroll_face.php` · `enroll_fingerprint.php` | (mobile capture; web does not call) |
| `app/biometric/delete.php` | Delete enrollment |

## Assets, warnings, performance
| `app/assets/list.php` · `create.php` · `update.php` · `delete.php` · `approve_return.php` · `reject_return.php` | Assets/custody |
| `app/warnings/add.php` · `delete.php` | Warnings |
| `app/performance/review_list.php?employee_id=` · `review_create.php` · `review_delete.php` | Performance reviews |

## Reports
| `app/reports/attendance.php` · `payroll.php` · `employees.php` · `leaves.php` | Report data |
| `app/reports/export_word.php` | (mobile Word; web exports via PDF/Excel client-side instead) |

## Settings
| `app/settings/company.php` | Company settings |
| `app/settings/statutory_payroll.php` | Statutory payroll settings |

## Support, notifications, audit
| `app/support/list.php` · `create.php` · `messages.php?ticket_id=[&after_id=]` · `reply.php` · `close.php` | Support |
| `app/notifications/list.php` · `read.php?id=` | Notifications |
| `app/audit/list.php` | Activity/audit log |

## Contract test expectations (MSW)

For each domain module, mock: (1) a success payload matching the entity types in
`data-model.md`, (2) an empty/no-data response (drives empty states, FR-034), (3) a 4xx
permission-denied response (drives the no-permission UX, FR-007/SC-008), and (4) a
network/offline failure (drives retry). Auth flows additionally mock the
"session superseded" response that forces sign-out (FR-005).

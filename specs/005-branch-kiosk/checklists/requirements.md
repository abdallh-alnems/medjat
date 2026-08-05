# Specification Quality Checklist: Branch Kiosk — Shared Tablet Attendance

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-08-03
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

**Validation run 1 — 2026-08-03**

Two items required correction and were fixed:

- *No implementation details*: the first draft named the packaging mechanism
  (build flavor, entry-point file, Gradle configuration) in the Summary. Packaging
  as a **separate installable application** is a genuine product boundary and was
  kept as FR-033; the mechanism by which that binary is produced was removed and
  belongs in `plan.md`.
- *Success criteria are technology-agnostic*: an early criterion measured
  server-side identification latency. Replaced by SC-001, which measures the
  outcome the employee actually experiences.

**Validation run 2 — 2026-08-03 (after clarification)**

Both `[NEEDS CLARIFICATION]` markers resolved and recorded in the Clarifications
section. The answers changed the shape of the specification rather than just
filling blanks:

- **Enrollment happens at the kiosk**, gated by an access code generated in the
  management app. This added **User Story 2 at P1** — without it the original
  User Story 3 was unreachable for the exact population the feature exists for —
  plus FR-035 to FR-041, five edge cases, four assumptions, and SC-011/SC-012.
  Stories 2 through 6 were renumbered to 3 through 7.
- **Face identification is always available; personal codes are a per-employee
  fallback, never a company-wide substitute** (FR-042, FR-007 tightened).
- A **Kiosk Access Code** entity was added, distinct from the Pairing Code — one
  brings a device into service, the other opens a device already in service.
  FR-022 now releases kiosk mode through this code rather than a static PIN, and
  the surviving `branches.station_admin_pin_hash` column is therefore expected to
  go unused (recorded in Assumptions, not dropped).

**Clarification session — 2026-08-03 (`/speckit.clarify`)**

Five further questions asked and integrated. Two were defects rather than gaps:

- **One-to-many identification was implied but never specified.** Now explicit
  (FR-043) with the compounding false-accept risk it carries held down by a
  best-versus-second-best margin rule (FR-044), a stricter threshold than
  one-to-one selfie verification (FR-045), candidate-count logging (FR-046), and a
  roster-size warning (FR-047).
- **FR-008 and User Story 6 directly contradicted each other** — server-only
  evaluation cannot coexist with offline identification. Resolved in favour of
  server-only. User Story 6 was rewritten from "keeps working without internet" to
  "fails honestly without internet", SC-004 was replaced, FR-024 to FR-027 were
  rewritten, and three edge cases were replaced. **A kiosk that cannot reach the
  server now records nothing** — a real capability loss, accepted knowingly, in
  exchange for no biometric data at rest on a wall-mounted shared device.

The other three added coverage: fleet versioning through the existing remote
configuration mechanism (FR-051 to FR-054), capture retention as dispute evidence
with automatic deletion (FR-055 to FR-059), and three independently grantable
permissions instead of one (FR-060, FR-061).

Terminology was normalised in the same pass: User Story 5 said "administrator
code" where the rest of the spec says "kiosk access code", and one edge case still
referred to punches held on the device after the offline path was removed.

**Status**: all 16 items pass. 61 functional requirements, 16 success criteria,
8 recorded clarifications. Ready for `/speckit.plan`.

**Carry into planning** — points decided here that need design work:

0. One-to-many identification against `mobilefacenet` is the highest-risk element
   of this feature. The measured false-accept rate at a 0.45 threshold is 0.2%
   per comparison; across a branch roster that compounds, and SC-013 sets the
   target it has to be held to. Establishing the supported roster ceiling from
   real measurement — not from the LFW figures — is planning work, and it may
   force the margin rule in FR-044 to be tighter than it sounds.

1. Kiosk-side enrollment means the tablet handles biometric capture for people
   other than its operator. The existing rule that the **server**, never the
   device, decides a face match (FR-008) has to extend to enrollment quality
   scoring as well.
2. `branches.station_methods` survives in production as
   `enum('face_only','fingerprint_only','both_available')`. The fingerprint values
   assume hardware a tablet does not have and are explicitly out of scope
   (Assumptions); the enum needs revisiting during data-model design rather than
   being honoured as written.

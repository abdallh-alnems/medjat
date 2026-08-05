# Feature Specification: Branch Kiosk — Shared Tablet Attendance

**Feature Branch**: `005-branch-kiosk`
**Created**: 2026-08-03
**Status**: Draft
**Input**: User description: "عمل كيوسك — جهاز مشترك في الفرع لتسجيل الحضور، يتفعّل من تطبيق الإدارة، ويطلع كتطبيق منفصل"

## Summary

Put a **shared tablet at the branch door** so employees can record attendance
without a smartphone and without the Medjat employee app on a personal device.

Every attendance method Medjat supports today for self check-in — QR + GPS, GPS
only, WiFi + GPS, face selfie — assumes the same thing: **the employee owns a
working smartphone and has the app installed on it.** A company with forty
factory workers, cleaners, or drivers will not install forty apps on forty
personal phones, and many of those phones do not exist. Today those companies
have exactly two options in Medjat: buy a ZKTeco terminal, or have a supervisor
type every punch in by hand.

This is the single largest functional gap against every competitor
(`attendance-methods-vs-competitors.md` §3, gap 1). Jibble, Connecteam, Deputy,
Buddy Punch, and Homebase all ship a shared branch tablet; three of the four ship
it as a **separate application** from their employee app, and the fourth
(Jibble) gates it behind an administrator account. None of them expose it to
ordinary employees.

Medjat built this once and removed it. The removal was only half applied: the
tables (`attendance_stations`, `station_recognition_logs`, `kiosk_pins`) are gone
from production, but **the per-branch configuration columns and the attendance
columns are still live** — `branches.station_*`, `attendance.station_id`,
`attendance.recognition_confidence`, and the `station_*` values inside
`attendance.recognition_method`. This feature rebuilds on top of those survivors
rather than starting from nothing.

**Two boundaries define this release:**

1. **The kiosk is a separate application, not a mode inside the employee app.**
   The kiosk needs an always-on camera, a screen that never sleeps, launch on
   power-up, and screen lockdown. Shipping those permissions inside the binary
   that every employee installs on a personal phone charges 100% of employees
   for a capability that serves one tablet per branch, couples the two release
   trains together, and hides a feature that app-store reviewers cannot reach.
   It shares its codebase with the employee app; it does not share its binary.

2. **The kiosk is activated by management, never by an employee.** A tablet
   becomes a kiosk only after an administrator with the right permission pairs it
   to a specific branch from the management app. No employee can put a device
   into kiosk mode, and the server — not the device — is what enforces that.

**Why the trust model is different from every existing method:** every other
self-service method in Medjat carries a token that can only record attendance for
**one** employee. A kiosk carries a token that can record attendance for
**anyone in the branch**. That difference drives most of the requirements below:
the device is bound to one branch, its credential is revocable, every
identification attempt is logged whether it succeeded or not, and the tablet
cannot decide on its own whether a face matched.

## Clarifications

### Session 2026-08-03

- Q: Can an employee's face be enrolled at the kiosk itself, or must every employee be enrolled beforehand? → A: **At the kiosk.** An administrator opens the kiosk's administration area, adds an employee, captures their face, and that is the whole enrollment. This is what makes the feature self-contained for its target user — the employee with no smartphone, who has no other route to enrolling a face.
- Q: How is the kiosk's administration area protected? → A: **By an access code generated from the management app**, not by a code stored on the tablet or on the branch. Nobody reaches kiosk settings, enrollment, or kiosk-mode release without one.
- Q: May a company operate a kiosk on personal codes alone, with no face check? → A: **No.** Face identification is always available on a kiosk. A personal code is a per-employee fallback, never a company-wide substitute for face identification.
- Q: Which permission governs kiosk actions? → A: **Three separate permissions, not one.** `kiosk_devices` (pair and revoke tablets), `kiosk_access` (generate the access code that opens the administration area, and enroll faces there), and `kiosk_evidence` (view stored captures). The three actions carry different weight — pairing is infrastructure, access-code generation is a daily task, and evidence is other people's biometric data — and collapsing them into one permission would mean anyone who can enroll a face can also unpair the fleet and browse their colleagues' photographs.
- Q: What does the server do with the capture once it has matched it? → A: **Stores it with the punch as evidence, then deletes it automatically after a defined retention period** (defaulting to the close of the payroll cycle the punch belongs to). One-to-many identification makes a visual record the only way to settle "that was not me", and a bounded retention window keeps that evidence available for the period disputes actually arise in without accumulating a permanent biometric archive.
- Q: How is a fleet of directly-installed kiosk tablets kept in step with the server as the product changes? → A: **Through the same remote-configuration mechanism that already governs the other apps.** The kiosk is registered alongside the employee and management apps, carrying its own minimum-version and maintenance settings, and an outdated kiosk is refused rather than allowed to record attendance against an API it no longer matches. *Noted consequence: on the store-distributed apps a forced update tells the user to visit the store; a directly-installed kiosk has no store, so the mechanism can block an outdated tablet but cannot deliver its update — see Assumptions.*
- Q: Can the kiosk identify an employee while offline, or is server evaluation absolute? → A: **Server evaluation is absolute.** There is no offline identification. The tablet never holds a face template and never decides a match. The consequence is accepted and is now written into the specification rather than glossed: **a kiosk that cannot reach the server cannot record attendance at all.** User Story 6 was rewritten from "keeps working without internet" to "fails honestly without internet", and SC-004 was replaced. The security and privacy gain is that no biometric data exists at rest on a wall-mounted shared device.
- Q: Does the employee identify themselves first and the face verify them (one-to-one), or does the kiosk resolve who they are from the face alone (one-to-many)? → A: **One-to-many.** The employee presents themselves and the kiosk resolves their identity against the branch's enrolled roster with no prior selection. *Accepted with the compounding false-accept risk understood: unlike one-to-one verification, every additional enrolled employee at the branch adds another chance of a wrong match. FR-043 to FR-047 exist to hold that risk down — a stricter threshold than selfie verification, a margin rule between the best and second-best candidate, and a roster-size warning.*

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Administrator puts a tablet into service (Priority: P1)

A branch manager buys an inexpensive Android tablet and mounts it by the staff
entrance. In the management app they open their branch, choose to add a kiosk,
and are shown a short pairing code that expires. They install the kiosk
application on the tablet, type the code, and the tablet becomes that branch's
kiosk — it names the branch on screen and is ready to accept employees. The
tablet now appears in the management app in a list of paired devices, with the
time it was last seen, and it can be removed from there at any moment.

**Why this priority**: Nothing else in this specification can be reached without
it, and it is the security boundary of the whole feature. It is also the story
that decides whether a customer can put a kiosk into service alone or has to call
support.

**Independent Test**: Can be fully tested end to end by pairing a device,
confirming it identifies the correct branch, confirming a second attempt with the
same code is refused, and confirming that removing the device from the management
app stops it from recording attendance.

**Acceptance Scenarios**:

1. **Given** an administrator with permission to manage a branch, **When** they
   request a kiosk pairing code, **Then** a code is shown that is valid only for
   a short window and only for that branch.
2. **Given** a valid, unexpired pairing code, **When** it is entered on a tablet
   running the kiosk application, **Then** the tablet is bound to that branch and
   confirms the branch name on screen.
3. **Given** a pairing code that has already been used, **When** it is entered on
   a second tablet, **Then** pairing is refused and the second tablet is not
   bound to any branch.
4. **Given** a user without permission to manage the branch, **When** they attempt
   to generate a pairing code, **Then** the request is refused.
5. **Given** a paired kiosk, **When** an administrator removes it from the
   management app, **Then** the tablet stops accepting employees and any further
   attempt from it to record attendance is refused.
6. **Given** a paired kiosk, **When** an administrator views the branch, **Then**
   they can see the device, when it was last seen, and how many punches it has
   recorded.

---

### User Story 2 - Administrator enrolls employees at the kiosk (Priority: P1)

On the first morning, a supervisor gathers the branch's workers around the
tablet. In the management app they generate a kiosk access code and enter it on
the tablet, which opens the kiosk's administration area. They pick an employee
from the branch's list, the employee stands in front of the tablet, their face is
captured and enrolled, and the supervisor moves on to the next one. When the last
worker is done they close the administration area and the tablet returns to the
kiosk screen, ready for the shift.

**Why this priority**: User Story 3 is unreachable without it **for exactly the
people this feature exists for**. Every enrollment path in Medjat today assumes a
phone in the employee's hand; an employee with no smartphone currently has no way
to enroll a face at all. Without kiosk-side enrollment the feature ships as
something only already-enrolled smartphone owners can use, which is nobody's
problem worth solving.

**Independent Test**: Can be fully tested by enrolling a previously unenrolled
branch employee at the kiosk, confirming they can then be identified by face at
that kiosk, and confirming the enrollment is visible in the management app.

**Acceptance Scenarios**:

1. **Given** an administrator holding a valid kiosk access code, **When** the code
   is entered on the tablet, **Then** the kiosk's administration area opens.
2. **Given** the administration area is open, **When** an employee of that branch
   is selected and their face captured, **Then** that employee is enrolled and can
   subsequently be identified at the kiosk.
3. **Given** an access code that has already been used or has expired, **When** it
   is entered, **Then** the administration area does not open.
4. **Given** no access code, **When** anyone attempts to reach the kiosk's
   administration area by any means available on the tablet, **Then** they cannot.
5. **Given** a face capture whose quality is below the accepted standard, **When**
   enrollment is attempted, **Then** it is refused with a reason and nothing is
   stored.
6. **Given** an employee who does not belong to the kiosk's branch, **When**
   enrollment is attempted, **Then** they are not offered for selection.
7. **Given** an enrollment performed at a kiosk, **When** management reviews that
   employee, **Then** they can see that the employee is enrolled, when, by whom,
   and at which kiosk.
8. **Given** the administration area is open and left untouched, **When** a short
   idle period passes, **Then** it closes by itself and the tablet returns to the
   identification screen.

---

### User Story 3 - Employee records attendance by face at the kiosk (Priority: P1)

An employee with no smartphone arrives at the branch. They stand in front of the
tablet, it recognises them, shows their name, and asks them to confirm whether
they are starting or ending their shift. They press once and see a confirmation
with their name and the time. The whole interaction takes seconds and requires no
typing, no card, and no phone.

**Why this priority**: This is the reason the feature exists. It is the only path
in Medjat by which a worker without a smartphone can record their own attendance
without a supervisor or a hardware terminal.

**Independent Test**: Can be fully tested on a paired kiosk with an enrolled
employee by standing in front of it and confirming that a correctly attributed
attendance record appears in the management app, and that an unenrolled or
unknown person is not matched to anybody.

**Acceptance Scenarios**:

1. **Given** an enrolled employee belonging to the kiosk's branch, **When** they
   present themselves at the kiosk, **Then** the kiosk shows their name and the
   available action, and recording it produces an attendance record attributed to
   them, to that kiosk, and to that branch.
2. **Given** a person who is not enrolled at all, **When** they present themselves
   at the kiosk, **Then** no employee is identified, no attendance is recorded,
   and the attempt is logged.
3. **Given** an employee who belongs to a **different** branch, **When** they
   present themselves at the kiosk, **Then** they are not identified and the
   attempt is logged.
4. **Given** an identification whose confidence falls below the company's
   threshold, **When** the kiosk evaluates it, **Then** no attendance is recorded
   automatically and the employee is offered the fallback path.
5. **Given** a company still tuning its threshold, **When** identifications are
   scored, **Then** the company can run in an observe-only state where results are
   recorded for review without anybody being refused.
6. **Given** an employee who has already checked in, **When** they present
   themselves again within a short configurable interval, **Then** a duplicate
   record is not created and the kiosk tells them what their current state is.
7. **Given** any identification attempt, successful or not, **When** it completes,
   **Then** it is recorded with its outcome, its confidence, the kiosk, and the
   time — and is reviewable by management.
8. **Given** two enrolled employees of the branch whose faces score closely
   against the same capture, **When** the kiosk evaluates it, **Then** no employee
   is identified, no attendance is recorded, the attempt is logged as ambiguous,
   and the fallback path is offered.
9. **Given** an employee presenting themselves, **When** the kiosk identifies
   them, **Then** it does so without the employee first selecting, typing, or
   otherwise declaring who they are.

---

### User Story 4 - Employee records attendance by personal code (Priority: P2)

An employee whose face is not enrolled, or whose face is not being recognised
because of a mask, poor light, or a bandage, taps an option on the kiosk and
enters a short personal code instead. Their name appears and they confirm their
punch the same way. The record is stored with a clear note that it was identified
by code rather than by face.

**Why this priority**: Without a fallback the kiosk becomes unusable for an
individual on a bad day, and the supervisor goes back to entering punches by
hand. It is P2 rather than P1 because it is materially weaker — a code can be
shared, and buddy punching is exactly the abuse this whole feature must resist.

**Independent Test**: Can be fully tested by disabling or failing face
identification for one employee, recording a punch using their personal code, and
confirming the resulting record is distinguishable in reporting from a
face-identified punch.

**Acceptance Scenarios**:

1. **Given** an employee with an assigned personal code, **When** they enter it
   correctly at the kiosk, **Then** their name is shown and they can record a
   punch.
2. **Given** an incorrect code, **When** it is entered, **Then** no employee is
   identified and the attempt is logged.
3. **Given** repeated incorrect codes from the same kiosk in a short window,
   **When** the threshold is crossed, **Then** further attempts are slowed or
   blocked and the event is flagged.
4. **Given** a punch recorded by code, **When** management reviews attendance,
   **Then** the record clearly shows it was identified by code rather than face.
5. **Given** an administrator, **When** they view an employee, **Then** they can
   issue or reset that employee's personal code, and the previous code stops
   working immediately.
6. **Given** a company that considers codes too weak, **When** they configure the
   branch, **Then** they can switch the code fallback off entirely.

---

### User Story 5 - The tablet stays a kiosk (Priority: P2)

The tablet sits unattended on a wall all day. It does not fall asleep, it does not
wander off to another screen, and an employee cannot back out of it into the
device's settings, browser, or another application. When a supervisor genuinely
needs to leave kiosk mode — to change the WiFi, hand the tablet back, or move it
to another branch — they enter a kiosk access code and the tablet unlocks.

**Why this priority**: An unattended shared device that can be navigated away
from is not a kiosk. This is the difference between a product and a demo, and it
is the story most likely to generate support calls if skipped.

**Independent Test**: Can be fully tested on a paired tablet left idle by
attempting to leave the kiosk screen through every ordinary device gesture, and
confirming that only a kiosk access code releases it.

**Acceptance Scenarios**:

1. **Given** a tablet in kiosk mode, **When** it is left untouched, **Then** the
   screen remains on and returns to the identification screen ready for the next
   person.
2. **Given** a tablet in kiosk mode, **When** an employee attempts to navigate
   away from the kiosk, **Then** they remain on the kiosk.
3. **Given** a tablet in kiosk mode, **When** a valid kiosk access code is
   entered, **Then** kiosk mode is released.
4. **Given** an invalid kiosk access code, **When** it is entered repeatedly,
   **Then** further attempts are slowed and the event is recorded.
5. **Given** a tablet that has been powered off, **When** it is powered back on,
   **Then** it returns to the kiosk screen for its branch without anyone signing
   in.

---

### User Story 6 - The kiosk fails honestly without internet (Priority: P2)

The branch's internet drops in the middle of a shift. The tablet says so, plainly
and immediately, in words a worker can act on — it does not spin, it does not
appear to accept a punch, and it does not quietly drop anybody's attendance on the
floor. Management is told that a kiosk has gone dark during working hours so a
supervisor can record the affected punches manually. The moment the connection
returns the tablet resumes on its own, with nobody signing in and nobody touching
a setting.

**Why this priority**: Identification requires the server, so a kiosk without
connectivity **cannot record attendance** — that is a direct consequence of the
security posture and is not negotiable within this design. What *is* in scope is
that the failure is honest, visible, and recoverable rather than silent. A shared
clock that appears to work while losing punches is worse than one that admits it
is down.

**Independent Test**: Can be fully tested by disconnecting the tablet, confirming
it states clearly that it cannot record attendance and identifies nobody, then
reconnecting and confirming it resumes unattended with no punches invented and
none lost.

**Acceptance Scenarios**:

1. **Given** a kiosk that cannot reach the server, **When** an employee presents
   themselves, **Then** the kiosk states that it cannot record attendance right
   now, identifies nobody, and records nothing.
2. **Given** a kiosk that cannot reach the server, **When** it displays that
   state, **Then** the message tells the employee what to do instead rather than
   showing a technical error.
3. **Given** a punch that was accepted by the server but whose confirmation did
   not reach the tablet, **When** connectivity returns, **Then** the punch exists
   exactly once and is not duplicated by a retry.
4. **Given** a kiosk that has gone offline during the branch's working hours,
   **When** the outage is detected, **Then** management is notified so the
   affected punches can be handled manually.
5. **Given** connectivity returns, **When** the tablet reconnects, **Then** it
   resumes accepting employees automatically without anyone signing in or
   reconfiguring it.
6. **Given** a period during which a kiosk was offline, **When** management
   reviews that branch, **Then** the outage window is visible so absent punches
   have an explanation.

---

### User Story 7 - Management sees and governs kiosk activity (Priority: P3)

An HR manager opens attendance and can tell at a glance which punches came from a
kiosk, which tablet recorded them, and how each person was identified. When
identification starts failing repeatedly at one branch — a camera smeared, a light
burned out, a threshold set too tight — that shows up as something they can act
on rather than as a stream of employee complaints.

**Why this priority**: The feature can ship and deliver value without this
reporting layer, but it cannot be **tuned** without it, and an untunable face
threshold is how a company ends up turning the whole thing off.

**Independent Test**: Can be fully tested by recording a mix of successful and
failed identifications on a kiosk and confirming that all of them, with their
outcomes, are visible and filterable in the management app.

**Acceptance Scenarios**:

1. **Given** attendance records from several sources, **When** management views
   attendance, **Then** kiosk records are identifiable as such, including which
   kiosk and which identification method produced them.
2. **Given** identification attempts that did not result in a punch, **When**
   management reviews kiosk activity, **Then** those attempts are visible with
   their reason.
3. **Given** a branch whose identification failure rate crosses a threshold,
   **When** management reviews their branches, **Then** that branch is surfaced
   as needing attention.
4. **Given** a paired kiosk that has not been seen for an extended period,
   **When** management reviews devices, **Then** that kiosk is surfaced as
   offline.

---

### Edge Cases

- **The tablet is moved out of the branch.** A kiosk is a fixed device; if it
  starts reporting from somewhere other than its branch, that is either a theft
  or a relocation, and it must not silently keep recording attendance for the
  branch it no longer sits in.
- **The tablet is stolen.** Its credential must be revocable from the management
  app without physical access to the device, and revocation must take effect the
  next time the device contacts the server.
- **An employee is terminated.** Identification is resolved server-side on every
  attempt, so a terminated employee stops being identifiable immediately, with no
  device to synchronise and no stale roster to expire.
- **The branch loses internet during the busiest ten minutes of the morning.**
  Nobody can clock in, and the honest failure path is the only path — the kiosk
  must make that unmistakable to the queue in front of it and to management at the
  same time, because the punches will have to be entered by hand.
- **Connectivity drops in the instant between identification and confirmation.**
  The employee cannot tell whether their punch registered; the system must resolve
  it to exactly one punch rather than none or two.
- **Two employees present themselves at once.** Only one identity can be acted on
  at a time, and the kiosk must not attribute a punch to whoever is standing
  behind the person it just recognised.
- **The same employee punches on the kiosk and on their phone.** Attendance state
  is one per employee per day, not one per device; the second attempt must be
  handled as a duplicate, not as a second shift.
- **A photograph or video is held up to the camera.** The company's anti-spoofing
  setting decides whether this is refused or merely flagged, and either way it is
  recorded.
- **More than one kiosk in the same branch.** Two doors, two tablets; an employee
  may check in on one and check out on the other.
- **A branch is deactivated or deleted while a kiosk is paired to it.** The kiosk
  must stop, and say why.
- **The pairing code is seen by an employee.** A code must be single-use,
  short-lived, and useless once consumed — seeing it over a manager's shoulder
  must not be enough to build a rogue kiosk.
- **The access code is seen by an employee.** The same property must hold for the
  code that opens the kiosk's administration area — an employee who reads it over
  a supervisor's shoulder must not be able to reuse it to enroll their own face
  or unlock the tablet.
- **The supervisor walks away with the administration area open.** An enrollment
  screen left unattended is a self-enrollment machine; it must close itself.
- **An employee is enrolled twice, or a second person is enrolled onto an
  existing employee.** Re-enrollment must be an explicit, recorded act rather than
  a silent overwrite, so that a face swapped onto someone else's record is
  visible afterwards.
- **Enrollment is attempted while the kiosk is offline.** Enrollment changes who
  the system will identify tomorrow and cannot be resolved locally; the kiosk must
  say so rather than appear to succeed.
- **The tablet's clock is wrong or its timezone differs from the company's.** The
  time recorded must be the company's time, not the tablet's local guess.
- **Battery dies mid-shift.** On power-up the tablet must return to the kiosk for
  its branch without a human signing anything in. Punches already accepted by the
  server are unaffected, because nothing about them lives on the tablet.
- **The camera is unavailable or denied.** The kiosk must fall back rather than
  present a dead screen.

## Requirements *(mandatory)*

### Functional Requirements

#### Pairing and device identity

- **FR-001**: The system MUST allow a user holding the `kiosk_devices` permission
  to generate a kiosk pairing code for a specific branch, and MUST refuse the
  request from anyone without it.
- **FR-002**: A pairing code MUST be single-use and MUST expire after a short
  window; a consumed or expired code MUST NOT pair any device.
- **FR-003**: On successful pairing the system MUST issue the device a credential
  bound to exactly one company and one branch, and the device MUST use that
  credential — never an employee's credential — for everything it does.
- **FR-004**: The system MUST allow a user holding `kiosk_devices` to list every
  kiosk paired to their branches, showing at least the device's name, when it was
  last seen, its version, and its activity volume.
- **FR-005**: The system MUST allow a user holding `kiosk_devices` to revoke a
  kiosk's credential, after which the system MUST refuse every subsequent request
  from that device.
- **FR-006**: The system MUST record who paired each kiosk, when, and who revoked
  it.

#### Identification and attendance

- **FR-007**: The kiosk MUST identify an employee by face as its primary method,
  and MUST offer a personal code only as a per-employee fallback where the company
  permits it.
- **FR-008**: The system MUST evaluate every identification **on the server**.
  The tablet MUST NOT be the authority on whether a face matched, and a claim of
  a successful match originating from the device MUST NOT be sufficient to record
  attendance.
- **FR-009**: The kiosk MUST only identify employees who belong to the branch it
  is paired to, and MUST refuse anyone else.
- **FR-010**: A successful identification MUST allow the employee to record a
  check-in or a check-out, and the kiosk MUST show the employee which of the two
  is appropriate for their current state.
- **FR-011**: Every attendance record produced by a kiosk MUST be stored with the
  kiosk that produced it, the identification method used, and the confidence of
  that identification where one applies.
- **FR-012**: The system MUST refuse a second punch of the same type from the
  same employee within a configurable minimum interval, and MUST tell the employee
  their current state rather than failing silently.
- **FR-013**: The system MUST record every identification attempt — successful,
  ambiguous, unmatched, refused, or suspected spoofing — with its outcome, its
  confidence, the kiosk, and the time.
- **FR-014**: The system MUST support an observe-only state in which
  identification results are scored and recorded but nobody is refused, so a
  company can tune its threshold against its own data before enforcing it.
- **FR-015**: A company MUST be able to set its own identification confidence
  threshold per branch.
- **FR-016**: Attendance times recorded through a kiosk MUST be stamped in the
  company's own timezone, not the tablet's and not the server's.
- **FR-043**: The kiosk MUST resolve an employee's identity by searching the
  enrolled roster of its branch, without the employee first selecting or declaring
  who they are.
- **FR-044**: A one-to-many match MUST be accepted only when the best candidate
  both exceeds the branch's confidence threshold **and** exceeds the second-best
  candidate by a configurable margin. When the two are too close the result MUST
  be treated as ambiguous: no attendance recorded, the attempt logged as
  ambiguous, and the fallback path offered.
- **FR-045**: The confidence threshold used for kiosk identification MUST be
  configurable independently of the threshold used for one-to-one selfie
  verification, and MUST default to a stricter value, because false-accept risk
  compounds across every additional enrolled employee at the branch.
- **FR-046**: Every identification MUST record how many enrolled candidates were
  searched, so that mis-attribution can be correlated with roster size when
  tuning.
- **FR-047**: The system MUST warn a company when a branch's enrolled roster grows
  beyond the size at which its configured threshold and margin can still hold the
  target mis-attribution rate.
- **FR-055**: The system MUST store the capture that produced each kiosk punch,
  and MUST make it viewable beside that attendance record by a user holding the
  `kiosk_evidence` permission, so a disputed punch can be settled visually.
- **FR-056**: Stored captures MUST be deleted automatically once their retention
  period has passed, and deletion MUST remove the image itself rather than only
  hiding it from view.
- **FR-057**: The retention period MUST be configurable per company, defaulting to
  the close of the payroll cycle the punch belongs to.
- **FR-058**: For identification attempts that produced **no** punch, a capture
  MUST be retained only where the attempt was flagged as a security event, under
  the same retention rules. Captures of people the system could not identify MUST
  NOT be accumulated otherwise.
- **FR-059**: Access to stored captures MUST be gated by `kiosk_evidence` and MUST
  be recorded, so that viewing another person's biometric evidence is itself
  auditable.
- **FR-060**: `kiosk_devices`, `kiosk_access`, and `kiosk_evidence` MUST be
  independently grantable — holding one MUST NOT imply any other.
- **FR-061**: Every navigation entry, tab, button, and menu item that leads to a
  kiosk action MUST be gated by the same permission the corresponding endpoint
  enforces, so that a user who lacks a permission never reaches a control that
  will refuse them.

#### Personal codes

- **FR-017**: The system MUST allow an administrator to issue and reset an
  employee's personal kiosk code, and a reset MUST invalidate the previous code
  immediately.
- **FR-018**: Personal codes MUST be stored so that they cannot be read back from
  storage, and MUST never be displayed anywhere except at the moment of issuing
  or resetting them.
- **FR-019**: The system MUST slow or block repeated incorrect code attempts from
  the same kiosk and MUST flag the event.
- **FR-020**: A company MUST be able to disable the personal-code path entirely
  for a branch.

#### Device behaviour

- **FR-021**: The kiosk MUST keep its screen awake and MUST return to the
  identification screen after each interaction or after a short idle period.
- **FR-022**: The kiosk MUST prevent an ordinary user from leaving the kiosk
  screen, and MUST require a kiosk access code (FR-036) to release kiosk mode.
- **FR-023**: The kiosk MUST return to its kiosk screen automatically after the
  device is restarted, without anyone signing in.
- **FR-024**: The kiosk MUST NOT record attendance while it cannot reach the
  server. It MUST state that plainly to the employee, identify nobody, and store
  nothing that would later be applied as a punch.
- **FR-025**: The kiosk MUST NOT store face templates, face embeddings, or any
  other biometric identifier at rest on the device, for any purpose including
  offline identification.
- **FR-026**: A face or enrollment capture MUST exist on the device only for as
  long as the request that carries it, and MUST be discarded once that request
  completes or is abandoned.
- **FR-027**: Where a request has been sent but its outcome is unknown — a
  connection lost mid-submission — the kiosk MUST resolve the outcome on
  reconnection such that the punch exists exactly once, neither duplicated by a
  retry nor lost.
- **FR-048**: The system MUST detect that a kiosk has gone offline during its
  branch's working hours and MUST notify management, so that the affected punches
  can be recorded manually.
- **FR-049**: The kiosk MUST resume normal operation automatically when
  connectivity returns, with no sign-in and no reconfiguration.
- **FR-050**: The system MUST make a kiosk's outage windows visible to management
  alongside that branch's attendance, so that missing punches have an explanation.
- **FR-028**: When the kiosk reports a location, the system MUST verify it is
  within the branch's configured radius, and MUST refuse or flag attendance
  according to the company's configuration when it is not.

#### Configuration and governance

- **FR-029**: A company MUST be able to enable or disable the kiosk per branch.
- **FR-030**: Kiosk attendance MUST participate in the existing attendance-method
  resolution so that a company can assign it to specific employees, categories,
  or branches rather than to everybody.
- **FR-031**: An employee MUST NOT be able to place any device into kiosk mode,
  and this MUST be enforced by the server rather than by the absence of a button.
- **FR-032**: The system MUST surface kiosks that have not been seen for an
  extended period, and branches whose identification failure rate is abnormal.
- **FR-033**: The kiosk application MUST be a distinct installable application
  from the employee application, with its own identity on the device.
- **FR-034**: Every refusal or flag raised at a kiosk MUST be written to the
  existing attendance security log alongside refusals from other channels.
- **FR-051**: The kiosk MUST be governed by the same remote-configuration
  mechanism that already governs the employee and management apps, carrying its
  own minimum-version and maintenance settings rather than a mechanism built for
  it alone.
- **FR-052**: The kiosk MUST report its version to the server, and management MUST
  be able to see the version each paired kiosk is running.
- **FR-053**: A kiosk running below the configured minimum version MUST refuse to
  record attendance, and MUST display an instruction addressed to a supervisor
  rather than a technical error addressed to the employee standing in front of it.
- **FR-054**: The system MUST allow management to see which kiosks would be
  blocked by a given minimum version **before** that minimum takes effect, so a
  fleet is not disabled without warning.

#### Enrollment and kiosk administration

- **FR-035**: The system MUST allow an employee's face to be enrolled at the
  kiosk itself, so that an employee who has never owned a smartphone can be
  brought into service without one.
- **FR-036**: Enrollment, kiosk settings, and release of kiosk mode MUST all be
  reachable only through the kiosk's administration area, and that area MUST open
  only on presentation of an access code generated in the management app by a user
  holding the `kiosk_access` permission.
- **FR-037**: A kiosk access code MUST be single-use and short-lived. It MUST NOT
  be a value stored permanently against the branch or the device, and it MUST NOT
  be derivable from anything visible on the tablet.
- **FR-038**: The kiosk administration area MUST close by itself after a short
  idle period and return the tablet to the identification screen.
- **FR-039**: Enrollment at a kiosk MUST be limited to employees who already
  exist in the system and belong to that kiosk's branch. The kiosk MUST NOT create
  employees.
- **FR-040**: The system MUST refuse an enrollment whose capture quality falls
  below the accepted standard, and MUST state the reason.
- **FR-041**: The system MUST record, for every enrollment performed at a kiosk,
  which administrator authorised it, which kiosk performed it, and when. Where an
  enrollment replaces an existing one, the replacement MUST be recorded as such
  rather than silently overwriting it.
- **FR-042**: Face identification MUST always be available on a kiosk. A company
  MUST NOT be able to configure a kiosk that identifies employees by personal code
  alone.

### Key Entities

- **Kiosk Station**: A physical tablet in service at one branch. Belongs to
  exactly one company and one branch. Holds a revocable credential, a name, the
  time it was last seen, and its lifecycle state. Replaces the removed
  `attendance_stations` concept.
- **Pairing Code**: A short-lived, single-use secret that converts an
  unconfigured tablet into a Kiosk Station for one branch. Records who issued it,
  when it expires, and when it was consumed.
- **Kiosk Access Code**: A short-lived, single-use secret generated in the
  management app that opens an already-paired kiosk's administration area — the
  only route to enrollment, kiosk settings, and release of kiosk mode. Distinct
  from a Pairing Code, which brings a device into service rather than opening one
  already in service.
- **Employee Personal Code**: A per-employee secret used to identify an employee
  at a kiosk when face identification is unavailable or not permitted. Stored
  irreversibly, resettable by an administrator.
- **Identification Attempt**: One attempt by a person at a kiosk to be
  identified. Records the kiosk, the resolved employee if any, the method, the
  confidence, the outcome, and the time — including attempts that produced no
  attendance. Replaces the removed `station_recognition_logs` concept.
- **Attendance Record**: The existing company-wide record, extended in use rather
  than in shape — the columns that carry the kiosk, the identification method,
  and the confidence already exist in production.
- **Branch Kiosk Settings**: Per-branch configuration — whether the kiosk is
  enabled, the confidence threshold, whether the personal-code fallback is
  permitted, the location radius, and the anti-spoofing posture. Most of these
  columns already exist in production.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A worker with no smartphone can record their attendance
  unaided — from approaching the tablet to seeing their confirmation — in under
  10 seconds.
- **SC-002**: A branch manager can put a brand-new tablet into service, from
  installing the application to the first successful punch, in under 10 minutes
  without contacting support.
- **SC-003**: At least 95% of identification attempts by correctly enrolled
  employees succeed on the first attempt under normal branch lighting.
- **SC-004**: A kiosk that loses connectivity says so within 10 seconds, records
  nothing during the outage, notifies management, and resumes unattended once the
  connection returns — with zero punches invented and zero punches lost across the
  outage boundary.
- **SC-005**: An employee cannot record attendance on behalf of a colleague using
  face identification, and 100% of attempts to do so are recorded and reviewable.
- **SC-006**: A tablet removed by an administrator stops being able to record
  attendance from its very next contact with the system.
- **SC-007**: An employee, using only the applications and permissions available
  to them, cannot place any device into kiosk mode.
- **SC-008**: A company of 40 workers without smartphones can be brought onto
  self-recorded attendance without installing anything on a personal phone and
  without buying dedicated attendance hardware.
- **SC-009**: 100% of kiosk-recorded attendance is distinguishable in management
  reporting by the device that recorded it and the way the employee was
  identified.
- **SC-010**: An unattended tablet cannot be navigated out of the kiosk by an
  ordinary user through any standard device gesture.
- **SC-011**: A supervisor can enroll a branch of 40 workers at the kiosk in one
  sitting, averaging under 30 seconds per employee, with no employee needing to
  touch a phone at any point.
- **SC-012**: An employee cannot open the kiosk's administration area, enroll
  themselves, or release kiosk mode without a code that only an administrator can
  generate.
- **SC-013**: Fewer than 1 in 1,000 kiosk punches is attributed to the wrong
  employee, at the largest branch roster the product supports for face-only
  identification.
- **SC-014**: A disputed punch inside the retention window can be settled visually
  by an authorised reviewer without contacting support, and no capture survives
  past its retention period.
- **SC-015**: A user granted only the permission to run daily kiosk operations
  can enroll employees without being able to unpair a tablet or view a colleague's
  stored capture.
- **SC-016**: No user reaches a kiosk control that then refuses them: every kiosk
  action a user can see is one they are permitted to perform.

## Assumptions

- **Android tablets only for this release.** The target market runs inexpensive
  Android tablets, and the platform supports true kiosk lockdown natively. iPad
  requires either manual per-device configuration or a mobile-device-management
  subscription and is out of scope.
- **The kiosk is its own application, sharing one package with the employee
  app.** It has its own project, package identity, signing key, and release
  cadence. The single shared component is the face pipeline and its model,
  because both products send embeddings the server compares against one stored
  vector per employee — two copies would drift and silently stop matching
  anybody. The data layer, theme, routing, and the employee app's offline
  attendance queue are **not** shared; the kiosk has no offline path to queue.
- **Stored captures are a meaningful volume, not an afterthought.** A 40-person
  branch punching twice a day produces on the order of 1,700 images a month, and a
  company with ten branches an order of magnitude more. Sizing, downscaling, and
  the scheduled purge that enforces FR-056 are planning concerns, but the volume is
  a consequence of this decision and should not surprise anyone later.
- **No biometric data exists at rest on the tablet.** This is a direct consequence
  of server-only identification and is one of the strongest privacy properties of
  the design: a stolen or discarded wall-mounted tablet carries no face templates
  for anybody. It is also what makes offline operation impossible, and the two
  cannot be separated.
- **A branch that loses connectivity loses attendance recording for that
  window.** Punches from that window are entered manually by a supervisor through
  the existing manual path. Companies in areas with unreliable connectivity should
  understand this before deploying a kiosk as their only method.
- **Direct installation first, an app-store listing later.** A kiosk is installed
  once per branch, usually by the person delivering the tablet. A public listing
  is a distribution decision that can follow without changing this specification.
- **Blocking an outdated kiosk is not the same as updating it.** On the
  store-distributed apps a forced update sends the user to the store; a
  directly-installed kiosk has no store to be sent to. Raising the minimum version
  therefore takes a branch offline until somebody installs the new build on that
  tablet, which is why FR-054 requires the blast radius to be visible first. This
  is the strongest practical argument for eventually listing the kiosk on a store,
  and it should be weighed once more than a handful of branches are live.
- **The kiosk records both check-in and check-out**, not check-in alone.
- **Fingerprint identification is out of scope.** The surviving per-branch
  configuration offers fingerprint options, but those assume hardware a tablet
  does not have; that configuration must be reconsidered rather than honoured as
  written.
- **Identification happens on demand, not continuously.** The kiosk identifies a
  person when they ask it to, rather than watching the room.
- **Identification is one-to-many and carries a roster-size ceiling.** Because the
  kiosk resolves identity from the face alone, false-accept risk grows with every
  enrolled employee at the branch. There is therefore a branch roster size beyond
  which face-only identification cannot meet SC-013 at any threshold; establishing
  that ceiling from real measurement is planning work, and FR-047 requires the
  product to warn once a branch approaches it.
- **Photo-without-matching is out of scope.** Some competitors offer a mode that
  stores a photo without identifying anybody; this release identifies or refuses.
- **NFC cards and badges are out of scope** for this release, though the device
  identity model is intended to accommodate them later.
- **The existing face enrollment data and matching service are reused** rather
  than replaced; a kiosk identifies against the same enrollment an employee would
  use for a selfie punch, and an enrollment captured at a kiosk is the same
  enrollment — not a parallel one.
- **The kiosk enrolls faces; it does not create employees.** An employee record
  must already exist and belong to the branch before that employee can be enrolled
  at its kiosk. Hiring stays in the management app.
- **Re-enrollment is permitted but recorded.** An employee whose appearance has
  changed can be re-enrolled through the same administration area, and the
  previous enrollment being replaced is an auditable event.
- **The surviving `station_admin_pin_hash` column is expected to go unused.** It
  was built for a static per-branch PIN; the chosen mechanism is a single-use code
  generated in the management app, which is stronger because it cannot be shared
  once and reused forever. The column is left in place rather than dropped, in
  keeping with the additive-only rule.
- **The existing attendance-method resolution, per-company timezone handling,
  permission enforcement, and security logging are reused** rather than
  duplicated for this channel.
- **The surviving production columns are treated as reserved and reused** —
  `branches.station_*`, `attendance.station_id`,
  `attendance.recognition_confidence`, and the `station_*` values inside
  `attendance.recognition_method`. Only the removed tables are rebuilt.
- **Every schema change is additive.** No existing column is dropped or narrowed
  by this feature.

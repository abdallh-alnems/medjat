# Feature Specification: Web Attendance Check-In / Check-Out

**Feature Branch**: `004-web-attendance-checkin`
**Created**: 2026-08-02
**Status**: Draft
**Input**: User description: "تنفيذ الويب للحضور والانصراف"

## Summary

Let an employee record their attendance — check in and check out — from a **web
browser**, without installing the employee mobile app.

Today attendance can only be self-recorded from the Permedjat employee app on the
employee's own phone. If the app is not installed, the phone is broken, storage
is full, or the employee is sitting at an office computer, there is no way to
record attendance at all except asking an administrator to enter it manually.
Every comparable product on the market — regional (ZenHR, Bayzat, Jisr) and
global (Deputy, Buddy Punch, Jibble) — offers a browser clock-in. This closes
that gap.

**This feature is deliberately narrow: attendance only.** It is not an employee
self-service portal. Payslips, leave requests, documents, and profile management
stay in the mobile app for this release. The narrower the browser surface, the
less data is exposed on the least verifiable channel.

**Why the scope matters for security:** a browser cannot see things the mobile
app can. It cannot read the wireless access point the device is joined to, and it
receives no signal about location spoofing. It also cannot run the on-device face
model. Web attendance is therefore **inherently weaker than app attendance**, and
this specification treats that as a first-class constraint rather than an
afterthought: the feature ships disabled, each company turns it on knowingly, and
it carries compensating controls (network restriction, photo evidence,
one-active-session-per-employee, and shared-device detection).

## Clarifications

### Session 2026-08-02

- Q: Can an employee who has never used the mobile app be onboarded entirely through the browser, or is prior activation in the app a prerequisite? → A: The browser is a full first door — an employee can activate and work without ever opening the mobile app.
- Q: Is image capture at each web punch always required, a per-company choice, or excluded from this release? → A: A per-company choice, enabled by default whenever web attendance is turned on.
- Q: At what granularity can the browser channel be permitted — whole company, full employee/category/branch hierarchy, or something between? → A: A company-wide switch, plus an exception at the job-category level only.
- Q: When does a browser session end, given it must survive a shift but must not persist on a shared device? → A: It ends when the employee checks out, or at a maximum age, whichever comes first.
- Q: If the session ends at check-out but the activation credential is single-use, what does the employee sign in with the next day? → A: They choose a personal numeric secret when they first activate, and use it for every subsequent sign-in; an administrator can reset it. *(Raised and resolved during planning — the two answers above are contradictory without it. See research.md R-002.)*

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Employee records attendance from a browser (Priority: P1)

An employee arrives at work. Instead of opening the mobile app, they open a link
in whatever browser they have — their phone's browser, the office computer, a
tablet. They identify themselves, the browser confirms where they are, and they
press a single button to check in. At the end of the day they return to the same
link and check out.

**Why this priority**: This is the entire feature. Without it nothing else in
this specification has a reason to exist, and with it alone the market gap is
closed. Every other story exists to make this one safe or governable.

**Independent Test**: Can be fully tested by opening the check-in link on a
device with no Permedjat app installed, recording a check-in inside a branch's
approved area, and confirming the punch appears in that employee's attendance
record with the same fields an app punch carries.

**Acceptance Scenarios**:

1. **Given** an employee whose company has web attendance enabled and who is
   physically inside their branch's approved area, **When** they open the
   check-in link and confirm their identity, **Then** a check-in is recorded
   against their attendance record for today and they see confirmation of the
   recorded time.
2. **Given** an employee who has already checked in today from the browser,
   **When** they return to the link at the end of their shift, **Then** they can
   check out without repeating identity confirmation from the start, and the
   worked duration is calculated exactly as it would be for an app punch.
3. **Given** an employee physically outside their branch's approved area,
   **When** they attempt to check in from the browser, **Then** the attempt is
   refused with a reason they can understand, no attendance is recorded, and the
   refusal is written to the security log.
4. **Given** an employee who declines the browser's location permission, **When**
   they attempt to check in, **Then** the attempt is refused with an explanation
   that location is required, and they are told how to grant it.
5. **Given** an employee who has already checked in from the mobile app today,
   **When** they open the browser link, **Then** they see their true current
   state (checked in, with the time) rather than an empty state — the browser and
   the app describe one attendance day, not two.

---

### User Story 2 - Company decides whether the browser channel is allowed (Priority: P2)

A company administrator reviews attendance settings. They can see that web
attendance exists, read plainly what it can and cannot verify compared with the
app, and decide whether to allow it. A company with office staff turns it on. A
company with hourly site labour leaves it off.

**Why this priority**: Because web attendance is the weakest channel, shipping it
enabled would silently downgrade the verification standard of every existing
company. Making the choice explicit is what makes P1 safe to release at all. It
is P2 rather than P1 only because P1 can be demonstrated with the setting forced
on in a test company.

**Independent Test**: Can be fully tested by toggling the setting on a company
and confirming that web check-in becomes available and then unavailable to that
company's employees, with no effect on any other company or on app check-in.

**Acceptance Scenarios**:

1. **Given** a company that has never changed the setting, **When** its employees
   open the check-in link, **Then** web attendance is unavailable — the default
   is off, and existing companies are unaffected by the release.
2. **Given** an administrator viewing the setting, **When** they read it, **Then**
   the interface states which verification controls do not apply on the browser,
   so the decision is informed rather than blind.
3. **Given** a company that enables web attendance and later disables it, **When**
   an employee attempts a web check-in after it is disabled, **Then** the attempt
   is refused and previously recorded web punches remain intact and auditable.
4. **Given** a company with web attendance enabled, **When** an administrator
   restricts which employees may use it, **Then** only those employees can record
   attendance from a browser and all others are refused.

---

### User Story 3 - Manager reviews who actually punched (Priority: P3)

A manager reviewing the month's attendance can see, for each web punch, the
evidence captured at the moment it happened — the location and, when the company
has it enabled, a photograph of whoever pressed the button. When the same device
records attendance for more than one employee, the manager sees that flagged.

**Why this priority**: This is the control that answers the realistic abuse case
— an employee lending their credentials to a colleague who punches for them. No
non-biometric channel can *prevent* a willing accomplice; this makes the pattern
visible and reviewable, which is what every comparable product relies on. It is
P3 because P1 delivers value without it, but the feature should not be considered
complete in a company that cares about attendance fraud.

**Independent Test**: Can be fully tested by recording web punches for two
different employees from the same browser and device, then confirming both the
captured evidence and the shared-device flag are visible to a manager reviewing
attendance.

**Acceptance Scenarios**:

1. **Given** photo evidence is enabled for a company, **When** an employee
   records a web check-in, **Then** an image of whoever is at the camera is
   stored with that punch and is visible to a manager reviewing that day.
2. **Given** two different employees record attendance from the same browser on
   the same device within one working day, **When** a manager reviews attendance,
   **Then** both punches are flagged as sharing a device.
3. **Given** a flagged punch, **When** a manager reviews it, **Then** the
   attendance record itself is not automatically rejected — the flag is
   information for a human decision, consistent with how existing security flags
   behave.

---

### Edge Cases

- **Session outlives the shift, or dies during it.** A session that expires
  between check-in and check-out leaves the employee unable to close their day —
  worse than never letting them start. A session that never expires on a shared
  office computer lets the next person punch as them. Resolved by FR-004: the
  session ends at check-out or at a maximum age, whichever is first, and an
  employee whose session lapsed mid-shift can always re-identify and close it.
- **Employee checks out on the app after checking in on the web.** Their browser
  session must not be left alive by a check-out that happened elsewhere.
- **Employee checked in on the app and checks out on the web** (and the reverse).
  One attendance day must be maintained across channels.
- **The employee never installed the app and has no activated identity.** They
  must be able to activate from the browser and reach a working check-in in the
  same sitting; a dead end here defeats the purpose of the channel.
- **Repeated failed activation attempts from the same source.** The activation
  page is publicly reachable, so guessing must be throttled and visible rather
  than silently tolerated.
- **Two browsers, two devices, one employee.** Opening the link on a second
  device while a session is live on the first.
- **Network is lost mid-punch.** The app queues punches offline; a browser
  generally cannot. The employee must be told clearly whether their punch was
  recorded, never left guessing.
- **Company disables web attendance while an employee is checked in via the
  browser.** The open shift must still be closable.
- **A company whose approved networks are all wireless access points rather than
  addresses.** The browser cannot see access points, so such a company
  effectively has no network control on this channel and must be told so.
- **Employee's device clock is wrong.** Recorded times must come from the
  company's own clock, not the browser's.
- **Shared computer, employee walks away without closing the tab.**
- **Camera unavailable or permission denied** when evidence capture is required.

## Requirements *(mandatory)*

### Functional Requirements

#### Access and identity

- **FR-001**: Employees MUST be able to reach an attendance page from a standard
  web browser on a phone, tablet, or computer, without installing an application.
- **FR-002**: The system MUST identify the employee before allowing any
  attendance action, using the employee's existing credentials — the same
  identity they use in the mobile app, not a second separate account.
- **FR-002a**: An employee who has never used the mobile app MUST be able to
  establish their identity entirely from the browser, using the same
  single-use activation credential their employer already issues them. Installing
  the mobile app MUST NOT be a prerequisite for any part of this feature.
- **FR-002c**: At activation the employee MUST choose a personal secret that they
  can reuse, and every later sign-in MUST use it. The employer-issued activation
  credential is consumed once and MUST NOT be required again — an employee who
  signs in daily must never need their employer to issue anything.
- **FR-002d**: An administrator MUST be able to reset a forgotten or locked
  secret. The reset MUST take effect immediately, ending any live browser session
  for that employee, so that it also serves as a way to cut off browser access
  for a departing employee.
- **FR-002b**: Because the identity-establishment step is reachable by anyone
  with the link, the system MUST limit repeated attempts against it so that an
  activation credential cannot be discovered by guessing, and MUST record such
  attempts for review.
- **FR-003**: An employee MUST be able to check out from the browser at the end of
  a shift without re-establishing identity from the beginning, for at least the
  length of a full working day including overtime.
- **FR-004**: An employee's browser identity MUST end at whichever comes first:
  the moment they record their check-out, or a fixed maximum age long enough to
  cover a full working day including overtime. It MUST NOT persist indefinitely,
  because the browser channel is expected to be used on shared and borrowed
  devices.
- **FR-004a**: Ending the session on check-out MUST require no action from the
  employee — a shared computer must be left safe by default, not by the
  departing employee remembering to do something.
- **FR-004b**: An employee who is still checked in when the maximum age is
  reached MUST be able to establish their identity again and close their open
  shift; reaching the limit MUST never leave a shift impossible to close.
- **FR-005**: An employee MUST have only one active browser identity at a time;
  establishing a new one MUST end the previous one.
- **FR-006**: Employees MUST be able to explicitly end their browser session.

#### Recording attendance

- **FR-007**: Employees MUST be able to record a check-in and a check-out from the
  browser.
- **FR-008**: Web punches MUST produce attendance records equivalent to app
  punches — same working-day calculation, same payroll treatment, same visibility
  in reports — and MUST be distinguishable as having originated from the browser.
- **FR-009**: The system MUST present the employee's true current attendance state
  on opening the page, reflecting punches made through any channel.
- **FR-010**: Recorded times MUST be determined by the company's own clock, never
  by the time reported by the employee's device or browser.
- **FR-011**: The system MUST tell the employee unambiguously whether a punch was
  recorded or not, including when the connection fails mid-action.

#### Verification and refusal

- **FR-012**: The system MUST require the employee's location and MUST refuse any
  web punch taken outside the approved area for their branch.
- **FR-013**: The system MUST be able to additionally restrict web punches to the
  company's approved network addresses where the company has defined them.
- **FR-014**: The system MUST make clear to administrators that verification
  controls which depend on the mobile device — the company's wireless access
  points and location-spoofing signals — do not apply to the browser channel.
- **FR-015**: Every refused web punch MUST be recorded in the existing security
  log with its reason, exactly as refusals from the app are.
- **FR-016**: The system MUST NOT decide a punch is valid based on any claim made
  by the browser about itself; validity MUST be determined by the server.

#### Evidence and detection

- **FR-017**: The system MUST capture an image of the person at the moment of a
  web punch and store it with that attendance record for later human review.
- **FR-017a**: Image capture MUST be a per-company setting that is **enabled by
  default whenever web attendance is enabled**, and that an administrator may
  switch off. A company that switches it off MUST be told that it is then
  relying on location alone, with nothing recording who pressed the button.
- **FR-017b**: When image capture is enabled and no usable image can be obtained
  — no camera, or permission refused — the punch MUST be refused with an
  explanation rather than recorded without evidence.
- **FR-017c**: The employee MUST be told, before the image is taken, that it is
  being captured and retained, so that consent is informed rather than implied.
- **FR-018**: Captured evidence MUST be visible to a manager reviewing that
  employee's attendance.
- **FR-019**: The system MUST detect when web punches for more than one employee
  originate from the same device within a working day, and MUST flag them.
- **FR-020**: Flags MUST NOT automatically reject attendance; they MUST surface
  for a human decision, consistent with existing security-flag behaviour.

#### Administration

- **FR-021**: Web attendance MUST be disabled by default for every company,
  including all companies existing before this release.
- **FR-022**: A company administrator with the appropriate permission MUST be able
  to enable and disable web attendance for their company.
- **FR-023**: Administrators MUST be able to restrict the browser channel to
  specific job categories within a company that has enabled it. An employee may
  use the browser channel only if their company allows it **and** — where
  category restrictions have been set — at least one of their job categories is
  permitted.
- **FR-023a**: A company that sets no category restriction MUST have the channel
  available to all its employees, so that the simple case requires no extra
  configuration.
- **FR-023b**: Permission for the browser channel MUST be governed by this
  setting alone and MUST NOT be expressed as an attendance method within the
  existing employee/category/branch method-resolution hierarchy, so that this
  feature does not deepen the existing conflation of *how attendance is proven*
  with *where it is recorded from*.
- **FR-024**: Enabling or disabling web attendance MUST be recorded in the audit
  trail with who changed it and when.
- **FR-025**: Disabling web attendance MUST NOT delete or invalidate attendance
  already recorded through it.
- **FR-026**: The browser interface MUST be available in Arabic and English and
  MUST render correctly right-to-left, consistent with every other Permedjat
  interface.

#### Explicitly out of scope for this release

- **FR-027**: The browser channel MUST NOT expose payslips, leave requests,
  documents, assets, advances, or profile editing in this release.
- **FR-028**: Face verification MUST NOT be offered on the browser channel in this
  release; companies requiring identity verification MUST use the mobile app.

### Key Entities

- **Web attendance session**: An employee's established identity on one browser.
  Belongs to exactly one employee, is limited in lifetime, is superseded when the
  employee establishes a new one elsewhere, and is distinguishable from a mobile
  app session so that punches can be attributed to the channel they came from.
- **Attendance record (extended)**: The existing attendance entry, extended so
  that the originating channel is recorded and browser punches can be
  distinguished in reporting and review.
- **Punch evidence**: An image captured at the moment of a web punch, bound to
  that one attendance record, retained under the company's data-retention
  obligations, and visible only to those permitted to review attendance.
- **Company web-attendance setting**: A per-company decision, off by default,
  governing whether the browser channel is available and to whom.
- **Security log entry (existing)**: Extended with the refusal and flag reasons
  introduced by this channel, including the shared-device flag.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An employee with no Permedjat application installed can record a
  check-in from opening the link to seeing confirmation in under 60 seconds,
  including identifying themselves for the first time.
- **SC-002**: A returning employee can record a check-out in under 15 seconds from
  opening the link.
- **SC-003**: 100% of attendance recorded through the browser carries a verified
  location, and where the company has enabled evidence capture, an image.
- **SC-004**: Zero web punches are accepted from outside the branch's approved
  area across a full month of use.
- **SC-005**: 100% of employees who check in via the browser are able to check out
  via the browser at the end of the same shift without their identity having
  lapsed, and 100% of those whose identity does lapse can re-establish it and
  still close the open shift.
- **SC-010**: After an employee checks out on a shared computer, no further
  attendance can be recorded as that employee on that computer without
  identifying afresh — verified with zero exceptions.
- **SC-006**: Companies existing before release see no change whatsoever in
  attendance behaviour until an administrator explicitly enables the channel.
- **SC-007**: A manager reviewing a month of attendance can identify every case
  where one device recorded attendance for more than one employee, without
  manually cross-referencing records.
- **SC-008**: Requests to administrators to manually enter attendance because "the
  app would not work" fall by at least half within two months of a company
  enabling the channel.
- **SC-009**: No category of data beyond attendance becomes reachable through the
  browser channel in this release.

## Assumptions

- **The employee identity system is reused, not rebuilt.** Employees authenticate
  with the same credentials they already use in the mobile app; no second account
  system is introduced. The browser exposes the same activation path rather than
  a parallel one, so an employee who activates on the web and one who activates
  in the app end up in exactly the same state.
- **The existing branch approved-area definitions are reused** — this feature
  introduces no new concept of location or of what counts as "at work".
- **Attendance rules are unchanged.** Shifts, lateness, overtime, absence, and
  payroll treatment behave identically regardless of the channel a punch came
  from; only the recorded origin differs.
- **The browser cannot observe the device's wireless network or detect location
  spoofing.** These are accepted limitations, disclosed to administrators rather
  than worked around.
- **Offline punching is not offered on the browser.** The mobile app queues punches
  without connectivity; the browser will refuse clearly instead of queuing
  silently.
- **Photographic and location data captured here fall under the same consent and
  retention obligations as existing attendance data** under Egyptian Labour Law
  14/2025, and no new retention policy is invented by this feature.
- **The existing administration application is where the company setting lives**;
  no new administrative surface is introduced.
- **One active browser identity per employee is a prerequisite of this feature**,
  not an optional enhancement — without it the shared-device risk this channel
  introduces cannot be contained.
- **This is the first release of a browser surface for employees.** It is expected
  to grow toward broader self-service later; it should not be designed as a dead
  end.

*All clarifications raised during specification have been resolved — see the
Clarifications section above.*

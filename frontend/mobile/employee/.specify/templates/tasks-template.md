---
description: "Task list template for Farkha feature implementation"
---

# Tasks: [FEATURE NAME]

**Input**: Design documents from `/specs/[###-feature-name]/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Test tasks are OPTIONAL — only include them if the spec explicitly requested them. Farkha's practical default is manual QA on Android (primary) + iOS (secondary); `flutter test` is nice-to-have for pure logic in controllers/models.

**Organization**: Tasks are grouped by user story so each story stays independently implementable and shippable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions (absolute paths relative to repo root)

## Path Conventions (Farkha)

- **Flutter app** (this project): `frontend/farkha_app/lib/`
  - Models: `lib/data/model/<feature>_model.dart`
  - Remote data source: `lib/data/data_source/remote/<feature>_data.dart`
  - Controller: `lib/logic/controller/<feature>_controller.dart`
  - Binding: `lib/logic/bindings/<feature>_binding.dart`
  - Screen: `lib/view/screen/<feature>/<name>.dart`
  - Widget: `lib/view/widget/<feature>/<name>.dart`
  - Route constant: `lib/core/constant/routes/...`
  - Theme/colors/sizes: `lib/core/constant/theme/`
- **PHP backend**: `backend_farkha/app/<endpoint>.php` + `backend_farkha/core/queries/<feature>_query.php`
- **Admin panel** (if touched): `frontend/farkha_admin/`
- **Tests** (optional): `test/<feature>/`

<!-- 
  ============================================================================
  IMPORTANT: The tasks below are SAMPLE TASKS for illustration only.
  The /speckit.tasks command MUST replace them with real tasks derived from:
  - User stories in spec.md (with priorities P1, P2, P3...)
  - Technical context in plan.md
  - Entities in data-model.md
  - Contracts in contracts/
  DO NOT keep these sample tasks in the generated tasks.md file.
  ============================================================================
-->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project-level wiring that must exist before any story can be worked on.

- [ ] T001 Add feature route name to `lib/core/constant/routes/` and register in the app's `getPages` list
- [ ] T002 [P] Add any new `.env` keys (if backend URL/flags differ) and document in `AGENTS.md`
- [ ] T003 [P] Add any new dependency to `pubspec.yaml` (only if plan.md justifies it) and run `flutter pub get`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared MVVM scaffolding that all user stories will reuse.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 [P] Create model in `lib/data/model/<feature>_model.dart` (fromJson/toJson, fields from data-model.md)
- [ ] T005 [P] Create PHP endpoint(s) in `backend_farkha/app/<endpoint>.php` and corresponding query class in `backend_farkha/core/queries/<feature>_query.php`
- [ ] T006 Create remote data source in `lib/data/data_source/remote/<feature>_data.dart` wrapping `CRUD` calls (one method per endpoint)
- [ ] T007 Create base controller in `lib/logic/controller/<feature>_controller.dart` — extends `GetxController`, holds `StatusRequest`, exposes fetch/submit methods
- [ ] T008 Create binding in `lib/logic/bindings/<feature>_binding.dart` (`Get.lazyPut<FeatureController>`)
- [ ] T009 Wire up `AnalyticsService` event names and `FirebaseCrashlytics.recordError` for the feature's critical paths
- [ ] T010 Confirm dark/light theme tokens in `core/constant/theme/` cover any new colors (add if missing)

**Checkpoint**: Foundation ready — user story implementation can now begin in parallel.

---

## Phase 3: User Story 1 - [Title] (Priority: P1) 🎯 MVP

**Goal**: [What this story delivers from the user's perspective]

**Independent Test**: [How to verify this story works on its own — e.g., "Open screen X from home, perform Y, see Z"]

### Tests for User Story 1 (OPTIONAL — only if tests requested) ⚠️

> **NOTE**: If included, write these FIRST, ensure they FAIL before implementation.

- [ ] T011 [P] [US1] Unit test for `<feature>_controller` logic in `test/<feature>/<feature>_controller_test.dart`
- [ ] T012 [P] [US1] Widget test for `<feature>_screen` golden path in `test/<feature>/<feature>_screen_test.dart`

### Implementation for User Story 1

- [ ] T013 [US1] Add controller methods to `lib/logic/controller/<feature>_controller.dart` for US1 journey (fetch/create/update as needed)
- [ ] T014 [P] [US1] Build `lib/view/widget/<feature>/<sub_widget>.dart` reusable widget(s)
- [ ] T015 [US1] Build `lib/view/screen/<feature>/<us1_screen>.dart` screen, wrapped in `HandlingData`, uses `EdgeInsetsDirectional` + Cairo font
- [ ] T016 [US1] Hook screen into route and binding (from T001, T008)
- [ ] T017 [US1] Add form validation via `core/functions/` helpers (Arabic error messages)
- [ ] T018 [US1] Fire Analytics events on screen-open + key actions
- [ ] T019 [US1] Verify RTL layout, light mode, dark mode on Android + iOS

**Checkpoint**: User Story 1 is shippable as MVP.

---

## Phase 4: User Story 2 - [Title] (Priority: P2)

**Goal**: [Description]

**Independent Test**: [How to verify on its own]

### Tests for User Story 2 (OPTIONAL — only if tests requested) ⚠️

- [ ] T020 [P] [US2] Unit/widget test files

### Implementation for User Story 2

- [ ] T021 [P] [US2] Extend controller with US2 methods in `lib/logic/controller/<feature>_controller.dart`
- [ ] T022 [P] [US2] Add US2 widget(s) under `lib/view/widget/<feature>/`
- [ ] T023 [US2] Build `lib/view/screen/<feature>/<us2_screen>.dart`
- [ ] T024 [US2] Integrate with US1 navigation (if relevant) without breaking US1 independence
- [ ] T025 [US2] Handle permissions if required (via `core/services/permission.dart`)

**Checkpoint**: US1 and US2 both ship independently.

---

## Phase 5: User Story 3 - [Title] (Priority: P3)

**Goal**: [Description]

**Independent Test**: [How to verify on its own]

### Implementation for User Story 3

- [ ] T026 [P] [US3] Extend controller/data source as needed
- [ ] T027 [US3] Build US3 screen/widgets
- [ ] T028 [US3] Analytics + RTL + theme checks

**Checkpoint**: All stories are independently functional.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements touching multiple stories.

- [ ] TXXX [P] Update `AGENTS.md` / `CLAUDE.md` if new conventions emerged
- [ ] TXXX Refactor duplicated widgets into `lib/view/widget/<feature>/` or `core/shared/`
- [ ] TXXX Run `flutter analyze` and fix any warnings
- [ ] TXXX [P] Add unit tests for pure logic (if not already done and if requested)
- [ ] TXXX Manual QA pass on Android + iOS, light + dark mode, RTL
- [ ] TXXX Add Remote Config flag (if feature needs kill-switch)
- [ ] TXXX Run `quickstart.md` end-to-end to validate

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories. Model → Endpoint → Data source → Controller → Binding.
- **User Stories (Phase 3+)**: Each depends on Phase 2 completion. Can proceed in parallel if staffed.
- **Polish (Final Phase)**: After all desired user stories are in.

### User Story Dependencies

- **US1 (P1)**: No dependencies on other stories.
- **US2 (P2)**: Can integrate with US1 but must remain independently testable.
- **US3 (P3)**: Same constraint as US2.

### Within Each User Story

- If tests requested: write and run them (failing) before implementation.
- Controller methods → widgets → screen → route wiring.
- Validate RTL + theme + Analytics before marking the story done.

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel.
- All Foundational tasks marked [P] can run in parallel within Phase 2.
- Once Foundational is done, stories can run in parallel if team capacity allows.
- Model creation and PHP endpoint creation are naturally parallel.
- Widgets within a story marked [P] can be built in parallel (different files).

---

## Parallel Example: Foundational Phase

```bash
# Parallel tasks in Phase 2:
Task T004: Create Dart model in lib/data/model/<feature>_model.dart
Task T005: Create PHP endpoint in backend_farkha/app/<endpoint>.php

# Sequential (after above):
Task T006: Wire data source (needs model + endpoint)
Task T007: Wire controller (needs data source)
Task T008: Wire binding (needs controller)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP & VALIDATE**: Manual QA on Android (Arabic RTL, light + dark).
5. Ship as a Remote-Config-gated release if risky.

### Incremental Delivery

1. Setup + Foundational → foundation ready.
2. Add US1 → ship/demo (MVP).
3. Add US2 → ship/demo.
4. Add US3 → ship/demo.
5. Every story adds value without regressing earlier ones.

### Parallel Team Strategy

With multiple developers:

1. Everyone finishes Setup + Foundational together.
2. Split after Foundational:
   - Dev A: US1
   - Dev B: US2
   - Dev C: US3 / PHP backend endpoints
3. Stories integrate independently.

---

## Notes

- [P] tasks = different files, no dependencies.
- [Story] label maps task → user story for traceability.
- Each user story must stay independently completable.
- Commit after each task or logical group (follow existing Arabic/English git log style).
- Verify tests fail before implementing (if tests requested).
- Stop at any checkpoint to validate the story in isolation.
- Avoid: vague tasks, same-file conflicts, cross-story dependencies that break independence, hard-coded strings (must be Arabic user-facing), direct `http.*` outside `data_source/remote/`.

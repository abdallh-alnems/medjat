# Implementation Plan: [FEATURE]

**Branch**: `[###-feature-name]` | **Date**: [DATE] | **Spec**: [link]
**Input**: Feature specification from `/specs/[###-feature-name]/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/plan-template.md` for the execution workflow.

## Summary

[Extract from feature spec: primary requirement + the chosen technical approach (which controllers/screens/endpoints, which Firebase service, which part of backend_farkha/)]

## Technical Context

<!--
  Farkha app stack is fixed. Fill these with the concrete choices for THIS feature.
  Only mark NEEDS CLARIFICATION if the spec truly left a gap.
-->

**Language/Version**: Dart 3.7.2+ / Flutter SDK (channel stable) · PHP 8.x for backend  
**Primary Dependencies**: GetX 4.7.2 · Firebase (Core/Auth/Analytics/Crashlytics/Messaging/Remote Config/App Check) · `http` via `core/class/crud.dart` · `flutter_screenutil` · `flutter_dotenv` · `flutter_svg` · `lottie` · [ADD feature-specific packages, e.g., `geolocator`, `pdf`, `excel`]  
**Storage**: PHP REST API (`backend_farkha/app/*.php`) + Firebase (Auth users, Remote Config, FCM tokens) · `get_storage` for client cache if needed  
**Testing**: `flutter test` for widget/unit · Manual QA on Android (primary) + iOS (secondary) · Firebase Crashlytics post-release monitoring  
**Target Platform**: Android SDK 23+ / iOS 13+ · Arabic RTL locale  
**Project Type**: Mobile app (Flutter) + REST backend (PHP). Admin panel in `front_end/farkha_admin/` may also be affected — flag if so.  
**Performance Goals**: First paint of feature screen < 1s on 3G · Smooth 60fps scroll on mid-range Android · API call latency ≤ 2s p95  
**Constraints**: Arabic RTL mandatory · Light + Dark mode parity · Works offline for read-only data where possible · `.env` driven config · No direct `http.*` outside `data_source/remote/`  
**Scale/Scope**: [feature-specific — e.g., "expected 1k daily cycle updates across 500 active farms, 20 new screens/widgets, 3 new endpoints"]

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Reference: `.specify/memory/constitution.md`

- [ ] **Arabic RTL First**: All new UI uses `EdgeInsetsDirectional`, Cairo font, Arabic strings, tested in RTL.
- [ ] **MVVM with GetX**: New code goes in correct layer (`controller/` vs `view/` vs `data_source/` vs `model/`). Bindings registered.
- [ ] **Unified API Layer**: Every HTTP call flows through `CRUD` + `StatusRequest` + `HandlingData`. No direct `http.*` in controllers/views.
- [ ] **Observable by Default**: Analytics events + Crashlytics error capture defined for critical paths. Remote-config-gated where reversibility matters.
- [ ] **Responsive & Scoped Permissions**: Sizes via `flutter_screenutil`. New permissions requested just-in-time with Arabic rationale.

If any gate fails, document the justification in **Complexity Tracking** at the bottom of this file.

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command) — API contracts, UI contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command — NOT created by /speckit.plan)
```

### Source Code (repository root)

<!--
  Farkha layout is fixed. Replace bracketed names below with the actual files/folders
  this feature adds or modifies. Delete lines that don't apply.
-->

```text
# Flutter app (this project): front_end/farkha_app/
lib/
├── core/
│   ├── class/                 # (usually unchanged)
│   ├── constant/
│   │   ├── routes/            # ADD: route names for new screens
│   │   └── [api/theme/id]/    # ADD: endpoint constants if new
│   ├── services/              # ADD: new singleton service if cross-cutting
│   └── shared/                # ADD: shared widget if reused across screens
├── data/
│   ├── data_source/remote/    # ADD: <feature>_data.dart — wraps CRUD calls
│   └── model/                 # ADD: <feature>_model.dart — JSON ↔ Dart
├── logic/
│   ├── bindings/              # ADD: <feature>_binding.dart
│   └── controller/            # ADD: <feature>_controller.dart — extends GetxController
└── view/
    ├── screen/<feature>/      # ADD: full screens
    └── widget/<feature>/      # ADD: reusable widgets

test/
└── <feature>/                 # ADD: widget + unit tests (if tests requested)

# PHP backend: backend_farkha/
app/                           # ADD: new endpoint files (one per endpoint)
core/queries/                  # ADD: query classes for DB access

# Admin panel (only if feature affects it): front_end/farkha_admin/
```

**Structure Decision**: [Document which layers this feature touches. Examples: "Client-only: adds controller + screen + widget, reuses existing endpoint." — or — "Full-stack: new PHP endpoint + query class + Flutter data_source + controller + screen."]

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., new state-mgmt lib alongside GetX] | [why the current tool is insufficient] | [why staying on GetX won't work] |
| [e.g., direct `http` call bypassing CRUD] | [specific constraint: streaming, multipart, etc.] | [why CRUD wrapper can't handle it] |

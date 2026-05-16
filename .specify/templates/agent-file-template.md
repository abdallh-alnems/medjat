# Farkha App — Development Guidelines

Auto-generated from feature plans. Last updated: [DATE]

## Active Technologies

[EXTRACTED FROM ALL PLAN.MD FILES — base stack is Flutter 3.7.2+ / Dart · GetX 4.7.2 · Firebase suite · PHP REST backend. Only add here what a specific feature introduced.]

## Project Structure

```text
farkha/
├── front_end/farkha_app/        # Flutter app (this project) — MVVM with GetX
│   └── lib/
│       ├── core/{class,constant,functions,middleware,package,services,shared}/
│       ├── data/{data_source/remote, model}/
│       ├── logic/{bindings, controller}/
│       └── view/{screen, widget}/
├── front_end/farkha_admin/      # Flutter admin panel
└── backend_farkha/              # PHP REST API
    ├── app/                     # one file per endpoint
    └── core/queries/            # query classes
```

[ACTUAL STRUCTURE FROM PLANS — add sub-trees specific to each active feature]

## Commands

```bash
flutter run --dart-define-from-file=.env       # run app
flutter build apk --release
flutter build appbundle --release
flutter test
flutter analyze
flutter clean && flutter pub get
```

[ONLY add commands introduced by new technologies — e.g., `dart run build_runner build` if a new gen package is added]

## Code Style

- **Dart/Flutter**: follow `analysis_options.yaml`. Use `EdgeInsetsDirectional`. Sizes via `flutter_screenutil` (`.w`/`.h`/`.sp`/`.r`). Cairo font for Arabic.
- **GetX**: controllers extend `GetxController`; views use `GetBuilder` or `Obx`; DI via `*Binding`.
- **HTTP**: only through `core/class/crud.dart` + `StatusRequest` + `HandlingData`.
- **PHP**: one endpoint per file under `backend_farkha/app/`; queries in `backend_farkha/core/queries/`.

[LANGUAGE-SPECIFIC additions only when a feature introduces new languages/tools]

## Recent Changes

[LAST 3 FEATURES AND WHAT THEY ADDED]

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

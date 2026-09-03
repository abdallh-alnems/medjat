# Permedjat App - Agent Guidelines

## Project Overview
Flutter mobile application — the Permedjat **employee** app.
- **Version**: 1.0.3+7
- **SDK**: Flutter 3.11.1+
- **State Management**: GetX
- **Backend**: Custom PHP API (`backend_medjet/`) + Firebase (messaging, remote config, crashlytics)
- **Sign-in**: phone number + activation code (or a join code / link / QR) — no Google Sign-In here

## Architecture Pattern
MVVM (Model-View-ViewModel) using GetX

```
lib/
├── core/           # Shared utilities
│   ├── class/      # Base classes (CRUD, StatusRequest, HandlingData)
│   ├── constant/   # Constants (routes, theme, Firebase, headers)
│   ├── functions/  # Helper functions (validation, formatting)
│   ├── middleware/  # Route guards
│   ├── package/    # Third-party package configs
│   ├── services/   # Singleton services (analytics, notifications, etc.)
│   └── shared/     # Shared widgets/components
├── data/           # Data layer
│   ├── data_source/ # API/Local data sources
│   └── model/       # Data models
├── logic/          # Business logic
│   ├── bindings/   # GetX dependency injection
│   └── controller/ # GetX controllers
└── view/           # UI layer
    ├── screen/     # Full screens/pages
    └── widget/     # Reusable widgets
```

## Key Technologies
- **State Management**: GetX (`get: ^4.7.2`)
- **Navigation**: GetX routing with `getPages`
- **Firebase**: Core, Analytics, Crashlytics, Messaging, App Check, Remote Config
- **Attendance**: `mobile_scanner` (QR), `geolocator` (GPS), `network_info_plus` (WiFi BSSID),
  `camera` + `google_mlkit_face_detection` + `tflite_flutter` (face selfie)
- **Offline**: `Hive` queue + `connectivity_plus` auto-sync
- **Localization**: Arabic (ar) default with `flutter_localizations`
- **Responsive UI**: `flutter_screenutil`
- **Design System**: IBM Plex Sans Arabic (Arabic) + Geist (Latin/numerals), custom themes in
  `core/constant/theme/`

## Important Conventions

### Naming
- Controllers: `*Controller` (e.g., `HomeController`)
- Screens: lowercase file names in folders (e.g., `screen/home.dart`)
- Models: `*Model` suffix
- Services: `*Service` suffix
- Bindings: `*Binding` suffix

### GetX Patterns
- Use `GetBuilder` for state that rebuilds widgets
- Use `Obx` with Rx observables for reactive state
- Bind dependencies in `AppBindings` or per-route bindings
- Controllers extend `GetxController`

### API Communication
- Custom `CRUD` class in `core/class/crud.dart`
- `StatusRequest` enum for request states
- `HandlingData` for response processing

### Theme
- Light/Dark mode via `DarkLightService`
- Theme definitions in `core/constant/theme/theme.dart`
- `ScreenUtilInit` wraps the entire app

## Commands

```bash
flutter run
flutter run --dart-define-from-file=.env
flutter build apk --release
flutter build appbundle --release
flutter test
flutter analyze
flutter format lib/
flutter clean && flutter pub get
```

## Firebase
- Config: `lib/core/constant/firebase_options.dart`
- Services initialized in `core/services/initialization.dart`
- Analytics tracked via `AnalyticsService`

## Environment
- `.env` file required for API endpoints and keys
- Loaded via `flutter_dotenv`

## Testing
- Test structure mirrors `lib/` structure under `test/`
- Shared helpers: `test/helpers/` (FakeCrud, TestHarness, fixtures)
- Unit tests: `test/unit/` (`controller/`, `core/`, `data_source/`, `models/`, `utils/`)
- Widget tests: `test/view/screen/` and `test/view/widget/`
- Integration wiring: `test/integration/`
- Controllers accept optional constructor params for DI in tests

## UI/UX Design Guidelines

When building Flutter widgets or screens, apply intentional design thinking:

### Design Direction
Before coding, commit to a clear aesthetic: refined minimal, warm organic, bold editorial, luxury, etc. Every screen should feel purposefully designed, not generic.

### Flutter Design Principles
- **Typography**: Use the configured families — IBM Plex Sans Arabic for Arabic, Geist for Latin and
  numerals. Apply scale contrast — large bold headers vs. light body text.
- **Color**: Use the app's theme system (`DarkLightService`). Dominant colors + sharp accent. Avoid flat evenly-distributed palettes.
- **Spacing**: Generous and consistent via `flutter_screenutil` (`.w`, `.h`, `.sp`). Unexpected whitespace creates premium feel.
- **Motion**: Add subtle animations (`AnimationController`, `AnimatedContainer`, Hero transitions) for high-impact moments — not scattered everywhere.
- **Depth**: Use `BoxShadow`, `BorderRadius`, `Gradient` to create layers. Avoid flat cards with no depth.
- **RTL**: All layouts must respect Arabic RTL. Use `EdgeInsetsDirectional`, `MainAxisAlignment.end` where needed.

### What to Avoid
- Generic AI-looking UI: symmetric cards, purple gradients, Inter font
- Cookie-cutter `ListTile` and default `AppBar` without customization
- Placeholder icons instead of meaningful visual language

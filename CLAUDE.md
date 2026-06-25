# Medjat Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-06-20

## Active Technologies
- PHP 8.x (backend), Dart 3.11 / Flutter (medjat_admin app), GetX state managemen + Backend — `kreait/firebase-php` (Remote Config + FCM, already vendored), existing `AdminAuth`/`AdminBaseApi`/`Database`/`NotificationService`. Frontend — `get`, `http`, `flutter_secure_storage`, `flutter_dotenv`; **NEW**: `firebase_core` + `firebase_messaging` in medjat_admin (currently absent) for support push only (002-admin-support-control)
- MySQL 8 via MAMP (`medjat`, host 127.0.0.1 port 8889, root/root). Tables `support_tickets`, `support_messages` already exist (migration `2026_06_support.sql`). Firebase Remote Config holds the app-control values. **NEW** table for super-admin device tokens (002-admin-support-control)
- TypeScript 5.x, React 19, Next.js 16 (App Router), Node 20+ + next, react/react-dom, @tanstack/react-query, zustand, (003-medjat-central-web)
- None local-authoritative. Server state via TanStack Query cache; (003-medjat-central-web)

- (001-rebuild-employee-app)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for 

## Code Style

: Follow standard conventions

## Recent Changes
- 003-medjat-central-web: Added TypeScript 5.x, React 19, Next.js 16 (App Router), Node 20+ + next, react/react-dom, @tanstack/react-query, zustand,
- 002-admin-support-control: Added PHP 8.x (backend), Dart 3.11 / Flutter (medjat_admin app), GetX state managemen + Backend — `kreait/firebase-php` (Remote Config + FCM, already vendored), existing `AdminAuth`/`AdminBaseApi`/`Database`/`NotificationService`. Frontend — `get`, `http`, `flutter_secure_storage`, `flutter_dotenv`; **NEW**: `firebase_core` + `firebase_messaging` in medjat_admin (currently absent) for support push only
- 001-rebuild-employee-app: Added [if applicable, e.g., PostgreSQL, CoreData, files or N/A]


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->

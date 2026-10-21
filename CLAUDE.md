# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project
**StudyBetter** — a Flutter app for **Android and Windows** to create and take
multiple-choice quizzes, get evaluated with metrics (scores, trends, per-question
accuracy, weakest questions), and study **flashcards** with spaced repetition.
A **Dart server** lets users publish their quizzes/decks and download content made
by others. The app is **offline first**: the local database is the source of truth
on the device; the server is only needed to publish and download.

Full plan: [docs/PLAN.md](docs/PLAN.md). Tasks live as GitHub issues on the
project's Kanban board — reference the issue number in branches and PRs.

## Monorepo layout (Dart pub workspace)
- `app/` — Flutter client (Riverpod, go_router, Drift/SQLite, dio, fl_chart).
  Feature-first structure under `app/lib/features/<feature>/`.
- `server/` — Dart REST API (shelf + shelf_router), PostgreSQL with JSONB, JWT auth.
- `packages/quiz_core/` — pure Dart, shared by app **and** server: models
  (freezed + json_serializable), validation, scoring, SM-2 scheduler, schema migrations.
  It must not import Flutter or server-only packages.
- `docs/` — plan, JSON data format, API reference.

## Key design rules
- Quizzes and flashcard decks are **JSON documents** with `schemaVersion`, `kind`,
  `id` (UUID) and `version`. The same document is used for file export/import,
  upload and download. Change the format only in `quiz_core`, bump
  `schemaVersion`, and add a migration + test.
- Personal data (attempts, answers, flashcard review state) stays **out** of the
  shared document and is stored in local tables.
- Server stores the document in a `jsonb` column plus indexed metadata columns,
  and validates every upload with `quiz_core`.
- Updates use optimistic concurrency: `PUT` with `If-Match: <version>`, `409` on conflict.
- Downloaded content the user doesn't own is read-only; editing makes a local copy.

## Commands
```bash
# from repo root
dart pub get                       # resolves the whole workspace
dart run build_runner build -d     # codegen (run inside app/ or packages/quiz_core/)
dart format .
dart analyze

# shared package
cd packages/quiz_core && dart test

# app
cd app && flutter run -d windows   # or: flutter run -d <android-device-id>
cd app && flutter test

# server
docker compose up -d db            # postgres
cd server && dart run bin/server.dart
cd server && dart test
```

## Conventions
- Lints: root `analysis_options.yaml` (`lints/recommended` + strict casts) for
  `quiz_core` and `server`; `app/analysis_options.yaml` builds on `flutter_lints`.
  Keep `dart analyze` (run from the repo root) clean.
- Don't add `Co-Authored-By` or other Claude attribution to commits.
- Keep business logic (scoring, validation, SRS) in `quiz_core` as pure functions with unit tests.
- Widgets stay thin; logic goes in Riverpod notifiers/controllers and repositories.
- Generated files (`*.g.dart`, `*.freezed.dart`) are **not** committed; they are
  generated in CI — run `build_runner` after pulling.
- Branch names: `feat/<issue>-short-name`, `fix/<issue>-short-name`.
- Conventional commit messages (`feat:`, `fix:`, `chore:`, `docs:`, `test:`).

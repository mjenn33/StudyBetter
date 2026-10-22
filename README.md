# StudyBetter

[![CI](https://github.com/mjenn33/StudyBetter/actions/workflows/ci.yml/badge.svg)](https://github.com/mjenn33/StudyBetter/actions/workflows/ci.yml)

Create multiple-choice quizzes, take them, and track how you're improving —
plus flashcards with spaced repetition. Built with **Flutter** for **Android** and
**Windows**, with a **Dart server** for sharing quizzes and decks.

> 🚧 Early development. See the [project plan](docs/PLAN.md) and the Kanban board
> for progress.

## Features
- 📝 **Quiz editor** — single- and multi-answer questions, explanations, tags,
  shuffle and time-limit settings.
- ▶️ **Take quizzes** — timer, instant scoring, full answer review with explanations.
- 📊 **Metrics** — attempt history, score trends, time per question, per-question
  accuracy and a "practice your weakest questions" mode.
- 🃏 **Flashcards** — decks of front/back cards studied with the SM-2 spaced
  repetition algorithm, due counts and streaks.
- ☁️ **Share** — publish your quizzes and decks to the server, browse and search
  the public catalog, and download content to your device.
- 📴 **Offline first** — everything except publishing/downloading works offline.
- 💾 **Import / export** — quizzes and decks are plain JSON files.

## Tech stack
| Part | Tech |
|---|---|
| App | Flutter, Riverpod, go_router, Drift (SQLite), dio, fl_chart |
| Shared | `packages/quiz_core` — pure Dart models, validation, scoring, SRS |
| Server | Dart (shelf), PostgreSQL (JSONB), JWT auth, Docker Compose |

## Repository structure
```
app/                 Flutter client (Android + Windows)
server/              REST API
packages/quiz_core/  Shared models and logic used by app and server
docs/                Plan, data format, API reference
```

## Getting started

### Prerequisites
- Flutter SDK (stable) with Android and Windows desktop toolchains
  (`flutter doctor` should be green for both)
- Docker Desktop (for PostgreSQL / running the server)

### Run the app
```bash
dart pub get
cd app
dart run build_runner build -d
flutter run -d windows
```
For Android, start an emulator or plug in a device and run `flutter run`.

### Run the server
Settings come from environment variables. For Docker Compose, copy the example
env file and adjust it (`.env` is git-ignored):
```bash
cp .env.example .env
```

| Variable | Default | Used by |
|---|---|---|
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | `studybetter` | `db` service, server `DATABASE_URL` |
| `DB_PORT` | `5432` | host port for PostgreSQL |
| `SERVER_PORT` | `8080` | host port for the server container |
| `JWT_SECRET` | random per start | signing tokens — set it to keep tokens valid across restarts |

Start PostgreSQL and run the server from source (hot restart, debugger):
```bash
docker compose up -d db
cd server
dart run bin/server.dart
```
Outside Docker the server reads `PORT`, `DATABASE_URL` and `JWT_SECRET`; the
defaults match the Compose database on `localhost:5432`.

Or run everything in Docker (AOT-compiled server image):
```bash
docker compose up -d --build
```

The API is served at `http://localhost:8080/api/v1` (health check: `/api/v1/health`).
Stop with `docker compose down` (add `-v` to also delete the database volume).

### Tests
```bash
cd packages/quiz_core && dart test
cd app && flutter test
cd server && dart test
```

## Quiz file format
Quizzes and decks are JSON documents with a `schemaVersion`. Example:
```json
{
  "schemaVersion": 1,
  "kind": "quiz",
  "id": "8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11",
  "title": "World Capitals",
  "version": 1,
  "questions": [
    {
      "id": "q1",
      "prompt": "What is the capital of Australia?",
      "type": "single",
      "options": [
        { "id": "a", "text": "Sydney" },
        { "id": "b", "text": "Canberra" }
      ],
      "correctOptionIds": ["b"],
      "explanation": "Canberra was purpose-built as the capital."
    }
  ]
}
```
Full reference in [docs/PLAN.md](docs/PLAN.md#4-data-format-json-schemaversion-1).

## Roadmap
M0 Foundation → M1 Core models & storage → M2 Quiz authoring → M3 Quiz taking →
M4 Metrics → M5 Flashcards → M6 Server → M7 Sync & catalog → M8 Polish & release.
Each milestone is a set of issues on the GitHub project board.

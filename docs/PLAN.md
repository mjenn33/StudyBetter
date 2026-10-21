# StudyBetter — Project Plan

A cross-platform (Android + Windows desktop) Flutter app for creating and taking
multiple-choice quizzes, tracking performance metrics, and studying flashcards,
backed by a server where users can publish their content and download content
made by others.

---

## 1. Goals and scope

### Must have (v1)
- **Quiz authoring** — create, edit, duplicate and delete multiple-choice quizzes
  (single-answer and multi-answer questions, optional explanation per question).
- **Quiz taking** — play a quiz with optional shuffling and time limit, get a
  score at the end, review every answer with the correct solution and explanation.
- **Metrics** — attempt history, score trends over time, time spent, per-question
  accuracy, "weakest questions", overall stats dashboard.
- **Flashcards** — create decks of front/back cards, study them with a spaced
  repetition scheduler (SM-2), see due counts and study streaks.
- **Offline first** — everything works without a network; the server is only
  needed to publish and to download.
- **Server** — user accounts, upload (publish) quizzes and decks, browse/search
  the public catalog, download content to the device, update content you own.
- **Import / export** — quizzes and decks can be saved to and loaded from
  `.json` files (same format the server uses).

### Nice to have (later)
- Images in questions/cards, true/false and free-text questions.
- Syncing attempts and flashcard progress across the user's devices.
- Ratings, comments and download counts on public content.
- iOS / macOS / Linux / web builds (Flutter makes these cheap later).

### Non-goals for v1
- Real-time multiplayer quizzes, classrooms, paid content.

---

## 2. Architecture overview

```
┌──────────────────────── Device (Android / Windows) ────────────────────────┐
│ Flutter UI (screens, widgets)                                               │
│      │ Riverpod providers / controllers                                     │
│      ▼                                                                      │
│ Repositories ──► Local DB (Drift / SQLite)  ← source of truth on the device │
│      │                                                                      │
│      └────────► API client (dio) ──────────────┐                            │
└────────────────────────────────────────────────┼────────────────────────────┘
                                                 │ HTTPS + JSON, JWT auth
┌────────────────────────── Server ──────────────▼────────────────────────────┐
│ Dart (shelf + shelf_router) REST API                                        │
│      │                                                                      │
│      ▼                                                                      │
│ PostgreSQL — metadata columns + full document in JSONB                      │
└─────────────────────────────────────────────────────────────────────────────┘

        packages/quiz_core  (pure Dart, shared by app AND server)
        models · JSON (de)serialization · validation · scoring · SRS
```

### Why this stack
| Decision | Choice | Reason |
|---|---|---|
| Client | Flutter | One codebase for Android and Windows (and more later). |
| Server language | **Dart** (shelf) | Shares the exact same model/validation/scoring code with the app via `quiz_core` — no duplicated schema. |
| Interchange format | **JSON** with a `schemaVersion` | Human readable, trivially exportable as files, natively supported by Dart and PostgreSQL. Binary formats (protobuf) give no real benefit at this data size. |
| Server storage | **PostgreSQL + JSONB** | The quiz/deck is stored as one JSON document (exactly what the client uploads/downloads), while title, owner, tags, visibility, version are real columns so they can be indexed, searched and paged. |
| Device storage | **Drift (SQLite)** | Works on Android and Windows, typed queries, migrations, reactive streams; needed for metrics queries (aggregations over attempts). |
| State management | **Riverpod** | Testable, compile-safe, works well with streams from Drift. |
| Routing | **go_router** | Declarative routes, deep links, works on desktop. |
| Models | **freezed + json_serializable** | Immutable models with generated `toJson/fromJson`. |
| HTTP | **dio** | Interceptors for JWT refresh, good error handling. |
| Charts | **fl_chart** | Score trends and stats dashboard. |
| Auth | Email + password, **JWT** access + refresh tokens, passwords hashed with argon2/bcrypt. |
| Deployment | **Docker Compose** (server + postgres) | Easy to run locally and on any VPS. |

---

## 3. Repository layout (monorepo, Dart pub workspace)

```
StudyBetter/
├── app/                    # Flutter client (android + windows)
│   └── lib/
│       ├── main.dart
│       ├── app/            # router, theme, DI/bootstrap
│       ├── data/           # drift database, DAOs, repositories, api client
│       └── features/
│           ├── quizzes/    # list, editor, question editor
│           ├── play/       # quiz player, results, review
│           ├── stats/      # metrics dashboard
│           ├── flashcards/ # decks, card editor, study session
│           ├── catalog/    # browse/search/download from server
│           ├── auth/       # login/register
│           └── settings/
├── server/                 # Dart shelf REST API
│   ├── bin/server.dart
│   ├── lib/
│   │   ├── routes/         # auth, quizzes, decks, users
│   │   ├── db/             # postgres access, migrations
│   │   ├── auth/           # jwt, password hashing, middleware
│   │   └── config.dart
│   ├── migrations/         # SQL migration files
│   └── Dockerfile
├── packages/
│   └── quiz_core/          # shared pure-Dart package
│       └── lib/src/
│           ├── models/     # Quiz, Question, Option, FlashcardDeck, Flashcard, ...
│           ├── validation/
│           ├── scoring/
│           └── srs/        # SM-2 scheduler
├── docs/
│   ├── PLAN.md             # this file
│   ├── data-format.md      # JSON format reference
│   └── api.md              # REST API reference
├── docker-compose.yml
├── pubspec.yaml            # workspace root
├── CLAUDE.md
└── README.md
```

---

## 4. Data format (JSON, schemaVersion 1)

The same JSON document is used for **file export/import**, **upload** and
**download**. Every document carries `schemaVersion` so the format can evolve with
migrations in `quiz_core`.

### Quiz
```json
{
  "schemaVersion": 1,
  "kind": "quiz",
  "id": "8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11",
  "title": "World Capitals",
  "description": "Capitals of the world, easy level",
  "language": "en",
  "tags": ["geography", "capitals"],
  "version": 3,
  "createdAt": "2026-10-21T10:00:00Z",
  "updatedAt": "2026-10-21T12:30:00Z",
  "settings": {
    "shuffleQuestions": true,
    "shuffleOptions": true,
    "timeLimitSeconds": null,
    "passingScorePercent": 70
  },
  "questions": [
    {
      "id": "q1",
      "prompt": "What is the capital of Australia?",
      "type": "single",
      "options": [
        { "id": "a", "text": "Sydney" },
        { "id": "b", "text": "Canberra" },
        { "id": "c", "text": "Melbourne" }
      ],
      "correctOptionIds": ["b"],
      "explanation": "Canberra was purpose-built as the capital in 1913.",
      "points": 1
    }
  ]
}
```
- `type`: `single` (exactly one correct option) or `multiple` (one or more).
- Validation rules: ≥1 question, 2–10 options per question, ≥1 correct option,
  `single` ⇒ exactly one correct, unique ids, non-empty text.

### Flashcard deck
```json
{
  "schemaVersion": 1,
  "kind": "flashcardDeck",
  "id": "c3d1...",
  "title": "Spanish verbs",
  "description": "",
  "language": "es",
  "tags": ["spanish"],
  "version": 1,
  "createdAt": "2026-10-21T10:00:00Z",
  "updatedAt": "2026-10-21T10:00:00Z",
  "cards": [
    { "id": "k1", "front": "tener", "back": "to have", "hint": null }
  ]
}
```

### Data that stays on the device (not in the shared document)
- **Attempts**: quizId, quizVersion, startedAt, finishedAt, score, maxScore,
  and per-question answers (selected option ids, correct?, time spent ms).
- **Flashcard review state** (per card): ease factor, interval, repetitions,
  due date, last reviewed, lapse count.
- **Library origin**: for downloaded items — `remoteId`, `remoteVersion`,
  `ownerName`, `downloadedAt`.

Keeping personal progress out of the shared document means a published quiz
never leaks anyone's results, and a re-download never overwrites progress.

---

## 5. Local database (Drift)

| Table | Key columns |
|---|---|
| `quizzes` | id, title, tags, document (JSON text), version, origin (local/downloaded), remoteId, remoteVersion, isOwnedByMe, updatedAt, deletedAt |
| `attempts` | id, quizId, quizVersion, startedAt, finishedAt, score, maxScore, durationMs |
| `attempt_answers` | attemptId, questionId, selectedOptionIds (JSON), isCorrect, timeMs |
| `decks` | id, title, tags, document (JSON text), version, origin, remoteId, remoteVersion, isOwnedByMe, updatedAt |
| `card_reviews` | deckId, cardId, easeFactor, intervalDays, repetitions, dueAt, lastReviewedAt, lapses |
| `review_log` | id, deckId, cardId, reviewedAt, grade |
| `settings` | key, value |

The full document is stored as JSON text (one source of truth, easy export), with
denormalized columns for listing/searching.

---

## 6. Metrics (what "evaluated with metrics" means)

Per attempt (results screen):
- Score (points and %), pass/fail vs `passingScorePercent`
- Correct / incorrect / skipped counts
- Total time and average time per question
- Review list: your answer vs correct answer + explanation

Per quiz (quiz stats screen):
- Number of attempts, best / average / last score
- Score trend line chart over attempts
- Per-question accuracy (% correct across attempts), sorted to show the
  **weakest questions** first, with "practice weakest questions" mode
- Average time per question

Global (dashboard):
- Total quizzes taken, total questions answered, overall accuracy
- Activity over the last 30 days (attempts/day)
- Flashcards: cards due today, cards learned, review streak, retention rate

---

## 7. Flashcards and spaced repetition

- Study session shows the front, user taps to flip, then grades:
  **Again / Hard / Good / Easy** (mapped to SM-2 quality 0/3/4/5).
- SM-2 implemented in `quiz_core/srs` as a pure function
  `ReviewState next(ReviewState current, Grade grade, DateTime now)` → unit tested.
- Modes: "Due cards" (SRS) and "Cram all cards" (no scheduling changes).
- New cards per day limit (setting, default 20).

---

## 8. Server API (v1)

Base path `/api/v1`, JSON bodies, `Authorization: Bearer <accessToken>`.

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/register` | – | email, username, password → tokens |
| POST | `/auth/login` | – | email, password → tokens |
| POST | `/auth/refresh` | refresh token | new access token |
| GET | `/me` | ✓ | current user profile |
| GET | `/quizzes?q=&tag=&sort=&page=` | – | public catalog (summaries only) |
| GET | `/quizzes/{id}` | – / ✓ | full quiz document (public, or private if owner) |
| POST | `/quizzes` | ✓ | publish a quiz (server validates with `quiz_core`) |
| PUT | `/quizzes/{id}` | ✓ owner | update; requires `If-Match: <version>`, 409 on conflict |
| DELETE | `/quizzes/{id}` | ✓ owner | unpublish |
| GET | `/me/quizzes` | ✓ | my published quizzes |
| … | `/decks…` | | identical set of endpoints for flashcard decks |
| GET | `/health` | – | liveness check |

PostgreSQL tables: `users`, `refresh_tokens`, `quizzes`, `decks`.
`quizzes`/`decks` columns: id (uuid), owner_id, title, description, tags (text[]),
language, visibility (`public`/`unlisted`/`private`), version, item_count,
download_count, document (jsonb), created_at, updated_at.
Full-text search on title/description/tags via a `tsvector` index.

Server-side protection: request size limit (e.g. 1 MB), rate limiting on auth
endpoints, schema validation of every upload, owner checks on mutation.

---

## 9. Sync model (upload / download)

- **Download**: browse catalog → open details → "Download" stores the document
  locally with `origin = downloaded`, `remoteId`, `remoteVersion`.
  If the server has a newer version, the library shows "Update available".
- **Edit a downloaded quiz you don't own**: app creates a local copy ("Make a copy")
  with a new id, so it can be edited and published as your own.
- **Upload**: on a quiz you own, "Publish" sends `POST` (first time) or `PUT`
  (later) with the version you last synced. On `409 Conflict` the user chooses
  "keep mine (overwrite)" or "take server version".
- Attempts and flashcard progress stay local in v1 (sync is a later milestone).

---

## 10. Milestones

| # | Milestone | Outcome |
|---|---|---|
| M0 | **Foundation** | Monorepo, workspace, lints, CI, app runs on Android + Windows, server "hello world". |
| M1 | **Core models & local storage** | `quiz_core` models/validation/JSON, Drift database, repositories. |
| M2 | **Quiz authoring** | Quiz library, quiz editor, question editor, JSON import/export. |
| M3 | **Quiz taking & evaluation** | Player, timer, scoring, results and review screens, attempts saved. |
| M4 | **Metrics** | Per-quiz stats, weakest questions, global dashboard with charts. |
| M5 | **Flashcards** | Decks, card editor, study session, SM-2 scheduling, due counts. |
| M6 | **Server** | Postgres schema, auth, quizzes/decks endpoints, search, Docker. |
| M7 | **Sync & catalog** | Login in app, publish, browse/search catalog, download, updates, conflicts. |
| M8 | **Polish & release** | Responsive desktop layout, theming/dark mode, accessibility, tests, Android & Windows release builds. |

M1–M5 can be built entirely offline; M6 can be developed in parallel with M2–M5
because the shared `quiz_core` package fixes the contract early.

Every task above is tracked as a GitHub issue on the project's Kanban board.

---

## 11. Testing strategy
- `quiz_core`: unit tests for validation, JSON round-trips, scoring, SM-2 (high coverage).
- `app`: repository tests with an in-memory Drift DB, widget tests for editor
  and player, a few integration tests (create → play → see stats).
- `server`: route tests against a throwaway Postgres (Docker) — auth, ownership,
  validation errors, version conflicts.
- CI (GitHub Actions): `dart format --set-exit-if-changed`, `dart analyze`,
  tests for all three packages, Android APK + Windows build on main.

## 12. Risks
| Risk | Mitigation |
|---|---|
| Schema changes break old files/devices | `schemaVersion` + migration functions in `quiz_core`, tests for old samples. |
| Abuse of public uploads (spam, huge payloads) | Size limits, rate limits, validation, report/delete later. |
| Sync conflicts | Optimistic concurrency with `version`, explicit user choice. |
| Desktop vs mobile UX differences | Responsive layouts (navigation rail vs bottom bar), keyboard shortcuts in player. |

# Data format (schemaVersion 1)

StudyBetter stores every quiz and flashcard deck as one **JSON document**. The
same document is used everywhere:

- **Export / import** — a `.json` file on disk
- **Publish** — the body of `POST` / `PUT` to the server
- **Download** — what the server returns and the app stores locally

The format is defined in code by [`packages/quiz_core`](../packages/quiz_core):
models in `lib/src/models/`, rules in `lib/src/validation/`, reading and
migrations in `lib/src/documents/`. This page describes that code; if they ever
disagree, the code wins and this page should be fixed.

Sample documents: [`quiz_v1.json`](../packages/quiz_core/test/fixtures/quiz_v1.json),
[`deck_v1.json`](../packages/quiz_core/test/fixtures/deck_v1.json).

## Common fields

Both document kinds start with the same fields.

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `schemaVersion` | integer | yes | — | Format version, currently `1`. See [Versioning](#versioning). |
| `kind` | string | yes | — | `"quiz"` or `"flashcardDeck"`. |
| `id` | string | yes | — | UUID (e.g. `8f6c2a7e-1c1b-4c55-9a0e-4b7e6b0d2f11`). Never changes, even across versions or when published. |
| `title` | string | yes | — | Must not be blank. |
| `description` | string | no | `""` | |
| `language` | string or `null` | no | `null` | BCP 47 tag such as `en` or `es`. |
| `tags` | array of strings | no | `[]` | Used for search and filtering. |
| `version` | integer | no | `1` | Content revision, incremented on every saved change. The server uses it for optimistic concurrency (`If-Match`). |
| `createdAt` | string | yes | — | ISO 8601 timestamp. Written in UTC (`…Z`); offsets are accepted on read and converted to UTC. |
| `updatedAt` | string | yes | — | Same as `createdAt`. |

`schemaVersion` (the format) and `version` (the content) are unrelated: editing
a quiz bumps `version`; only a change to this specification bumps
`schemaVersion`.

## Quiz (`kind: "quiz"`)

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

### `settings`

| Field | Type | Default | Notes |
|---|---|---|---|
| `shuffleQuestions` | boolean | `false` | Random question order on each attempt. |
| `shuffleOptions` | boolean | `false` | Random option order within each question. |
| `timeLimitSeconds` | integer or `null` | `null` | Limit for the whole quiz; `null` means no limit. Must be > 0 when set. |
| `passingScorePercent` | integer | `70` | 0–100. |

The whole `settings` object may be omitted; every field then takes its default.

### `questions[]`

| Field | Type | Required | Default | Notes |
|---|---|---|---|---|
| `id` | string | yes | — | Unique within the quiz. Attempt history is linked by this id, so keep it stable when editing. |
| `prompt` | string | yes | — | Must not be blank. |
| `type` | string | no | `"single"` | `"single"`: exactly one correct option. `"multiple"`: one or more. |
| `options` | array | no | `[]` | 2–10 entries (see below). |
| `correctOptionIds` | array of strings | no | `[]` | Ids from `options`; at least one. |
| `explanation` | string or `null` | no | `null` | Shown when reviewing answers. |
| `points` | integer | no | `1` | ≥ 1. A question scores its points only when the selected set equals `correctOptionIds` exactly. |

### `questions[].options[]`

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Unique within the question (e.g. `a`, `b`, `c`). |
| `text` | string | yes | Must not be blank. |

## Flashcard deck (`kind: "flashcardDeck"`)

```json
{
  "schemaVersion": 1,
  "kind": "flashcardDeck",
  "id": "c3d1b7a2-5e4f-4a3b-9c8d-1e2f3a4b5c6d",
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

### `cards[]`

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | string | yes | Unique within the deck. Review progress is stored per card id, so keep it stable when editing. |
| `front` | string | yes | Must not be blank. |
| `back` | string | yes | Must not be blank. |
| `hint` | string or `null` | no | Optional, may be empty. |

## What is *not* in a document

Personal data never goes into the shared document, so publishing a quiz can't
leak anyone's results and downloading a new version never overwrites progress.
It stays in the app's local database:

- Quiz attempts and per-question answers (score, selected options, time spent)
- Flashcard review state (ease factor, interval, due date, lapses) and the review log
- Library origin of downloaded items (`remoteId`, `remoteVersion`, owner)

## Reading a document

Always read documents with `parseDocument` (or `parseDocumentString` for file
contents), then validate:

```dart
final doc = parseDocumentString(fileContents); // throws DocumentFormatException
switch (doc) {
  case QuizDocument(:final quiz):
    final issues = validateQuiz(quiz); // empty = valid
  case DeckDocument(:final deck):
    final issues = validateDeck(deck);
}
```

The two steps report different kinds of problems:

1. **Format** — `parseDocument` throws `DocumentFormatException` when the input
   is not JSON or not an object, `kind` is missing or unknown, `schemaVersion`
   is missing, newer than the app supports or too old to migrate, or a field is
   missing or has the wrong type (e.g. an unknown question `type`).
2. **Content** — `validateQuiz` / `validateDeck` return a list of
   `ValidationIssue`s and never throw. The app uses them to highlight fields in
   the editor; the server rejects an upload with any issue (`422`).

Unknown extra fields are ignored on read and dropped on write.

## Validation rules

Each issue has a `path` into the document (e.g. `questions[2].options[0].text`),
a `code` and an English `message`. All issues are reported at once.

| Applies to | Rule | `code` |
|---|---|---|
| Both | `id` is a UUID | `invalidId` |
| Both | `title` is not blank | `emptyText` |
| Both | `version` ≥ 1 | `outOfRange` |
| Quiz | at least one question | `noQuestions` |
| Quiz | question ids are non-empty and unique | `emptyId`, `duplicateId` |
| Quiz | `prompt` is not blank | `emptyText` |
| Quiz | 2–10 options per question | `tooFewOptions`, `tooManyOptions` |
| Quiz | option ids are non-empty and unique within the question | `emptyId`, `duplicateId` |
| Quiz | option `text` is not blank | `emptyText` |
| Quiz | at least one correct option | `noCorrectOption` |
| Quiz | `single` questions have exactly one correct option | `multipleCorrectInSingle` |
| Quiz | every correct id is one of the question's options | `unknownOptionId` |
| Quiz | correct ids don't repeat | `duplicateId` |
| Quiz | `points` ≥ 1 | `outOfRange` |
| Quiz | `settings.timeLimitSeconds` > 0 when set | `outOfRange` |
| Quiz | `settings.passingScorePercent` is 0–100 | `outOfRange` |
| Deck | at least one card | `noCards` |
| Deck | card ids are non-empty and unique | `emptyId`, `duplicateId` |
| Deck | `front` and `back` are not blank | `emptyText` |

"Blank" means empty or only whitespace.

## Versioning

`schemaVersion` identifies the format of the document, independently of its
content `version`.

- Documents are always **written** in the current version
  (`currentSchemaVersion` in `quiz_core`, currently `1`).
- Documents with an **older** version are upgraded on read by a chain of
  migrations, one per version step (`documentMigrations`, keyed by the version
  they upgrade from). A version is readable as long as the chain from it to the
  current version is complete.
- Documents with a **newer** version than the app knows are rejected with a
  message asking the user to update the app; the app never guesses at a newer
  format.

### Changing the format

Change the format only in `quiz_core`, never in the app or server alone:

1. Update the models (and validation rules if needed).
2. Bump `currentSchemaVersion`.
3. Add a migration to `documentMigrations` that turns a document of the
   previous version into the new shape.
4. Keep a sample of the previous version under
   `packages/quiz_core/test/fixtures/` (e.g. `quiz_v1.json`) with a test that
   parses it, and add the new samples.
5. Update this page.

Because the server validates uploads with the same package, app and server must
be deployed with matching `quiz_core` versions when the format changes; the
server should be updated first so it accepts the new version.

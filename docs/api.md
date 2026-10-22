# StudyBetter REST API

Base URL: `http://localhost:8080/api/v1`. All bodies and errors are JSON,
except successful DELETE and OPTIONS responses (204, empty body). Requests
with JSON use `Content-Type: application/json`. Dates are UTC ISO 8601 strings.

## Authentication

| Method | Path | Request | Response |
|---|---|---|---|
| POST | `/auth/register` | `{"email":"sam@example.com","username":"sam","password":"long-password"}` | 200 token pair; 400 invalid fields; 409 duplicate email/username |
| POST | `/auth/login` | `{"email":"sam@example.com","password":"long-password"}` | 200 token pair; 401 invalid credentials |
| POST | `/auth/refresh` | `{"refreshToken":"opaque-token"}` | 200 new token pair; 401 invalid, expired, or already used token |
| GET | `/me` | Bearer token | 200 `{"id":"uuid","email":"sam@example.com","username":"sam"}`; 401 |

A token pair is `{"accessToken":"jwt","refreshToken":"opaque-token"}`.
Send `Authorization: Bearer <accessToken>` for protected endpoints. Refresh
rotates the refresh token: store both replacement tokens atomically and retry
an unauthorized request once. Authentication endpoints allow 20 requests per
socket-peer IP per minute; 429 includes `Retry-After: 60`. In-memory limits
reset on restart; multi-instance deployments need a shared limiter.

## Health

`GET /health` → 200 `{"status":"ok"}`. No authentication required.

## Public catalog

Both `GET /quizzes` and `GET /decks` accept:

| Parameter | Default | Meaning |
|---|---|---|
| `q` | empty | PostgreSQL full-text search across title, description and tags |
| `tag` | empty | Exact tag match |
| `sort` | `newest` | `newest` or `downloads` (most downloaded first) |
| `page` | `1` | One-based page, 20 entries; integer 1–1000000 |

Example: `GET /quizzes?q=biology&tag=science&sort=downloads&page=1`

```json
{"page":1,"hasMore":false,"items":[{"id":"uuid","title":"Cells","description":"Cell biology","tags":["science"],"language":"en","version":2,"itemCount":10,"downloadCount":12,"createdAt":"2026-10-01T00:00:00.000Z","updatedAt":"2026-10-02T00:00:00.000Z","ownerName":"sam","ownerId":"uuid"}]}
```

Only public items are listed. Summaries omit full documents. Invalid sort or
page returns 400. Ties sort by ID for deterministic paging. Concurrent catalog
changes can move items between pages.

## Quiz and deck documents

The following endpoints exist for **both** `/quizzes` and `/decks`.
Replace `{collection}` with one of these names.

| Method | Path | Authentication | Success | Errors |
|---|---|---|---|---|
| GET | `/{collection}/{id}` | Optional; owner required for private content | 200 full document, `ETag: <version>`; increments downloads | 404 absent/private |
| POST | `/{collection}` | Required | 201 document, server version 1 | 401, 409 duplicate ID, 422 validation |
| PUT | `/{collection}/{id}` | Owner required | 200 document with next server version | 400 missing/invalid If-Match, 401, 403, 404, 409 stale version, 422 |
| DELETE | `/{collection}/{id}` | Owner required | 204 | 401, 403, 404 |
| GET | `/me/{collection}` | Required | 200 array of owned summaries | 401 |

POST/PUT bodies use the [document format](data-format.md), with an additional
`visibility` field (`public`, `unlisted`, or `private`, default `private`). The
stored/downloaded document omits visibility and personal study data.

Quiz upload example:

```json
{"schemaVersion":1,"kind":"quiz","id":"00000000-0000-4000-8000-000000000001","title":"Cells","description":"Cell biology","version":1,"visibility":"public","createdAt":"2026-10-01T00:00:00.000Z","updatedAt":"2026-10-01T00:00:00.000Z","tags":["science"],"questions":[{"id":"q1","prompt":"Basic unit of life?","type":"single","options":[{"id":"a","text":"Cell"},{"id":"b","text":"Rock"}],"correctOptionIds":["a"]}]}
```

Deck upload example:

```json
{"schemaVersion":1,"kind":"flashcardDeck","id":"00000000-0000-4000-8000-000000000002","title":"Cells","version":1,"visibility":"unlisted","createdAt":"2026-10-01T00:00:00.000Z","updatedAt":"2026-10-01T00:00:00.000Z","cards":[{"id":"c1","front":"Cell","back":"Basic unit of life"}]}
```

A successful upload returns the same document fields (without `visibility`),
with the authoritative server `version`. PUT requires `If-Match: 1` (bare
integer version). A conflict returns `{"error":"version conflict","version":2}`;
a concurrent-write conflict may omit `version`. Fetch the current document,
then explicitly choose the server version or resubmit local content with its
latest version. Private documents return 404 to other users; unlisted documents
are accessible by ID but never appear in search.

Owned summaries have `id`, `title`, `description`, `tags`, `language`,
`visibility`, `version`, `itemCount`, `downloadCount`, `createdAt`, `updatedAt`.

## Errors and CORS

General error example: `{"error":"Not found."}`. Validation errors use
`{"errors":[{"path":"title","code":"required","message":"Title is required."}]}`.
Malformed JSON or field types return 400 on auth routes and 422 for document
validation. Unhandled errors return 500 with a generic message and no stack
trace. Bodies exceeding **1 MiB (1048576 bytes)** return 413, including chunked
uploads. These limits apply before JSON parsing.

CORS permits any origin, methods GET/POST/PUT/DELETE/OPTIONS, and request
headers Authorization/Content-Type/If-Match. ETag and Retry-After are exposed.
OPTIONS returns 204. CORS does not grant access to protected resources.

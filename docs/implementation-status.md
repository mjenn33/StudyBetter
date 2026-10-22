# Issues #41–#55 implementation status

Changes are on `feat/41-55`, based on `main` at `688a785`.
The checkout is the `repository/` subdirectory of the supplied source folder,
which did not contain Git history.

| Issue | Implementation | Validation |
|---|---|---|
| #41 Public catalog | PostgreSQL full-text search, tags, sort, paging, summaries, atomic download increments | PostgreSQL tests |
| #42 Server protection | 1 MiB streaming body cap, auth throttling, CORS, JSON errors | Middleware tests |
| #43 Server tests | Disposable Docker PostgreSQL, auth/ownership/validation/conflict/search, CI | Harness passes locally |
| #44 API docs | Endpoint, examples and error reference linked from README | Checked against routes |
| #45 API client | Dio auth/refresh interceptor, one retry, secure server-scoped tokens, typed errors | Client tests |
| #46 Accounts | Validated sign-in/register forms, settings logout, optional accounts | Offline app tests |
| #47 Publishing | POST/PUT, If-Match, visibility, both conflict choices, remote metadata | Publishing/conflict UI tests |
| #48 Catalog UI | Quizzes/decks, search/tag/sort, infinite scroll, details, offline/retry state | Download UI test |
| #49 Downloads/updates | Provenance/ownership/version, update badges, in-place updates | Attempts/reviews preserved in tests |
| #50 Read-only/copy | Permissions, deck viewer, editable copies with new IDs | Repository copy/permissions tests |
| #51 Desktop | Quiz library/catalog list-detail panes, shortcuts/help, DPI-aware minimum size | App tests; native Windows check pending |
| #52 Themes | Persistent light/dark/system setting | Both-theme contrast tests |
| #53 Accessibility | Flashcard semantics, progress, long/scaled text, explicit result labels | 200% text/keyboard/contrast tests; native screen-reader check pending |
| #54 Integration | Create/play/results/stats and flashcard study scenarios, Windows CI | Scenarios pass locally; Windows runner pending |
| #55 Releases | Icons, Android permission/signing, Windows ZIP, main artifacts, tagged release uploads | Workflows prepared; native/signed builds pending |

## Verified locally

- Shared package: 84 passing tests.
- Server: 12 passing tests, including real disposable PostgreSQL integration.
- App: 181 tests passed in the complete suite; additional publishing, conflict,
  and ownership/download UI cases pass separately.
- Shared-model and Drift code generation completed.
- Static analysis and formatting pass.
- Publishing/conflict and downloads for both owners and other users pass UI tests.

## Remaining external steps

Git push approval was declined. No branch or pull request has been published.
The user will merge the branch themselves; do not merge it into `main`.
GitHub CI has not run for these changes. A browser preview is documented in [preview.md](preview.md).

Configure the four Android signing secrets in [releases.md](releases.md), publish
the branch once authorized, and run the Windows/native release jobs before
considering platform/release acceptance complete. Keep issues open and merge
only after the required checks pass.

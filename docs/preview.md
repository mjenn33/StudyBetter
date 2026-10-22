# Local browser preview

Build the web app from `app/`:

```sh
flutter build web --release
python3 -m http.server 8765 --bind 127.0.0.1 --directory build/web
```

Open `http://127.0.0.1:8765/#/catalog`. The app uses its browser-local database;
Android and Windows use their own local storage. Offline quiz/flashcard features
work without the API. Set the API base URL in Settings (default
`http://localhost:8080/api/v1`).

For the sharing preview, start PostgreSQL and the API using the README's server
instructions. The active development preview uses an isolated disposable
PostgreSQL container and contains the test fixtures “World Capitals” and
“Spanish verbs” as public catalog items. Download either to try the quiz player,
statistics, read-only content, making a copy, and flashcard study. Create your
own preview account from Settings to try publishing. Demo catalog content lives
only in the local preview database.

A successful browser preview does not verify native Windows/Android builds.
Those checks run in the configured CI workflows after the branch is published;
Android release signing additionally requires repository secrets.

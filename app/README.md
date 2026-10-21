# StudyBetter app

Flutter client for Android and Windows. See the [root README](../README.md) and
[docs/PLAN.md](../docs/PLAN.md).

```bash
dart run build_runner build -d
flutter run -d windows
flutter test
```

Code lives under `lib/`:
- `app/` — app widget, router, theme and bootstrap
- `data/` — Drift database, repositories, API client
- `features/<feature>/` — screens, widgets and controllers per feature

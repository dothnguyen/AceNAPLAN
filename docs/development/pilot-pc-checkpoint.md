# Windows PC pilot target checkpoint

Date: 13 October 2026 (Australia/Brisbane). Approved scope revision: 2.

The approved pilot now includes a native Windows x64 desktop evaluation target. It runs the same Flutter app with `PILOT_QA_HARNESS=true`, shows an evaluation/progress-reset banner, and uses an in-memory test repository. Data resets when the app closes. Android remains the only durable SQLite learner-data target in this phase; Windows is not an app distribution target.

The generated Windows runner opens a regular resizable window (`WS_OVERLAPPEDWINDOW`). The app reflows at narrow/tall and wide/landscape widths. Test the same flows on PC with:

```powershell
flutter run -d windows --dart-define=PILOT_QA_HARNESS=true
```

Resize the app window to a portrait-proportioned size and then a landscape-proportioned size. The separate layout tests exercise 720×1100 and 1440×900 Flutter viewports, and desktop integration launches the actual Windows target.

## Recorded checks

The operator ran the checks against the current scope-revision source and saved logs under `.autonomy/evidence/pilot/`:

| Check | Result |
| --- | --- |
| `flutter devices` | Windows desktop target detected; Chrome, Edge and an Android target also listed |
| Windows integration (`flutter test --dart-define=PILOT_QA_HARNESS=true integration_test -d windows`) | Passed; app built and started, one integration test passed |
| Windows orientation layout tests (`flutter test test/windows_layout_test.dart`) | Passed at tall and wide desktop proportions; included in the 10-test widget suite |
| Windows Release build (`flutter build windows --release --dart-define=PILOT_QA_HARNESS=true`) | Passed |
| Android Release APK build | Passed after revising the platform guard |
| Flutter analysis | Passed, no issues |
| Flutter unit/widget tests | Passed, ten tests including platform guards and large text |
| Dart formatting | Passed, zero changed files |
| Autonomous-execution unit tests | Passed, 36 tests, including approval-history revision behavior |

Windows run and build verify the evaluation target, not Windows persistence. The tests exercise responsive Flutter viewports and startup; manually resize the desktop window before treating portrait/landscape presentation as visually accepted. Final independent review for this scope revision remains outstanding.

## Remaining pilot work

Question-bank authoring/review, audio, scoring, SQLite import/update, fresh session selection, practice and parent-summary flows are not implemented yet. The Android release, real phone/tablet checks, educator approval and final phase evidence remain mandatory. Neither local build was published.

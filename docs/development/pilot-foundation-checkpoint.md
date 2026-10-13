# Pilot foundation checkpoint

Date: 13 October 2026, Australia/Brisbane.

The pilot scope, prerequisite packet and `design/AceNAPLAN.html` visual reference are approved. Work is on `development/pilot`. The native supervisor has a saved exact session and a board with 15 implementation/release tasks plus two linked foundation fixes. No task or phase has been marked complete.

## Implemented so far

Flutter Android/Web scaffold, responsive anonymous landing screen using the selected cream/navy palette and subject cards, independent-product wording, and platform guards. Web requires `PILOT_QA_HARNESS=true` and displays a persistent test-mode warning; Android rejects that flag. Practice entry points are not yet active. Current typography and composition are an initial foundation, not final visual acceptance of the supplied design.

Package resolution produced `pubspec.lock`. The operator applied the formatter correction found after package resolution. Android uses the current scaffold's debug signing identity for local testing; the resulting APK is not a signed Play release candidate.

## Actual verification

The operator ran these checks in the normal user environment because the initial sandbox-only native session could not write SDK/Dart state or Git metadata:

| Check | Result | Log under `.autonomy/evidence/pilot/` |
| --- | --- | --- |
| Flutter package resolution | Passed | `operator-pub-get.log` |
| Exact approved Dart format check, after correction | Passed, five files / zero changes | `operator-format.log` |
| Flutter analysis | Passed, no issues | `operator-analyze.log` |
| Flutter unit/widget tests | Passed, six tests | `operator-flutter-test.log` |
| Approved Web QA build | Passed | `operator-web-build.log` |
| Approved Android release APK build | Passed | `operator-apk-build.log` |
| Orchestration regression suite | Passed, 34 tests | Operator execution output |

The six app tests cover platform guards, narrow/phone/landscape/tablet layouts and enlarged text with the Web banner. These checks were executed against the source preserved in the foundation commit. They do not establish content correctness, durable SQLite, audio, session functionality, device performance or final release readiness. Build output includes a Flutter warning about future migration from the Kotlin Gradle plugin; current APK compilation succeeded. A Web font-discovery warning also requires visual verification rather than treating the build as visual sign-off.

## Resume and unresolved work

The initial native reviewer found a Kotlin plugin omission and a formatting issue. Those corrections are in the preserved source. Its reports remain blocked and tied to the earlier uncommitted snapshot. They must not be promoted to current passing review after integration. Fresh QA/acceptance and independent review are still required before the supervisor may mark the foundation tasks done.

The resumed native coordinator and a separate runner reviewer both received a model usage-limit error. The desktop usage tool reported ordinary usage allowed, so the cause cannot be established from the aggregate quota view alone. Do not switch authentication, substitute the configured models, fabricate evidence or reset persistent limits to work around it. Logs for launches 0002 and 0003 retain the CLI argument error and model usage-limit failure respectively.

Runner repair: `--automatic-review` now selects the installed native `--approve-for-me` workspace-write preset without the conflicting explicit sandbox flag. Default routing is unchanged. The native resume parser accepts this invocation; 34 regression tests pass. An independent source review of this runner repair remains unfinished because its reviewer hit the usage limit.

After native model access is available, resume the exact supervisor session with `--automatic-review`, inspect `.autonomy/evidence/pilot/operator-toolchain-diagnosis.txt` and these logs, reconcile blocked tasks, obtain fresh review and continue the dependency queue. Preserve cumulative usage and retries. If repeated-launch guards apply, record a materially different diagnosis before an operator-authorized retry; do not reset them silently.

Question generation/review, the 440-item bank and spelling recordings, atomic SQLite import/update, fresh/review session selection, practice/feedback and parent-summary flows remain pending. Educator review, real phone/tablet evidence and final signing remain later release gates. No publishing or cloud provisioning occurred.

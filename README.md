# Ace NAPLAN Practice pilot

This is an independent Year 5 Numeracy and Conventions practice pilot. It is not affiliated with or endorsed by ACARA. Android is the intended learner target. Windows desktop and Web builds provide temporary local evaluation targets and visibly warn that progress resets.

## Run on Windows PC

Install Flutter 3.44 or a compatible SDK and Visual Studio with the **Desktop development with C++** workload. From the project root:

```powershell
flutter run -d windows --dart-define=PILOT_QA_HARNESS=true
```

Resize the window to a tall, portrait-proportioned shape and a wide, landscape-proportioned shape to check responsive behavior. Evaluation progress uses an in-memory repository and clears when the application exits.

## Run on Web for UI checks

```powershell
flutter run -d chrome --dart-define=PILOT_QA_HARNESS=true
```

Web progress also uses the in-memory test repository and clears on reload. Neither evaluation target verifies Android SQLite durability.

## Android target

```powershell
flutter run -d <android-device-id>
```

Android startup rejects the Web/Windows QA harness flag and is the pilot's durable SQLite target. Publishing a build remains separate from local testing.

## Verification

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test --dart-define=PILOT_QA_HARNESS=true -d windows
flutter build windows --release --dart-define=PILOT_QA_HARNESS=true
```

See [pilot scope](docs/product/pilot.md), [design mapping](docs/product/pilot-design-reference.md), and [execution plan](docs/development/pilot-execution-plan.md) for acceptance and release gates.

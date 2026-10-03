# marketplace (app)

The Flutter app. See the [repository README](../../README.md) for an
overview, and [`docs/adr`](../../docs/adr) for design decisions.

```bash
flutter run                                   # from this directory
flutter test                                  # unit + widget tests
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/app_test.dart     # end-to-end, live API
```

Deep link on a simulator:

```bash
xcrun simctl openurl booted "marketplace://app/listing/167"
adb shell am start -a android.intent.action.VIEW -d "marketplace://app/listing/167"
```

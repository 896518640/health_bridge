# DNurse Health Plugin

A Flutter plugin for integrating health data across different platforms, providing unified access to health and fitness information.

## Features

- 📱 Cross-platform health data integration (Android & iOS)
- 🏥 Samsung Health SDK support for Android
- 💊 Apple HealthKit integration for iOS
- 📊 Unified data models for health metrics
- 🔒 Privacy-focused implementation with user consent

## Supported Health Data Types

- Step counts and walking data
- Heart rate measurements
- Blood pressure readings
- Weight and body measurements
- Sleep tracking data
- Exercise and workout sessions

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dnurse_health_plugin: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### Android Setup

1. Add Samsung Health SDK permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="com.samsung.android.providers.health.permission.READ" />
<uses-permission android:name="com.samsung.android.providers.health.permission.WRITE" />
```

2. Ensure minimum SDK version is 24 or higher in `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 24
        targetSdkVersion 34
    }
}
```

### iOS Setup

1. Add HealthKit capability to your app in Xcode
2. Add health permissions to your `ios/Runner/Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>This app needs access to health data to provide health insights.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>This app needs to update health data to sync your health information.</string>
```

## Usage

```dart
import 'package:dnurse_health_plugin/dnurse_health_plugin.dart';

// Initialize the plugin
final healthPlugin = DnurseHealthPlugin();

// Request permissions
await healthPlugin.requestPermissions();

// Read step count data
final steps = await healthPlugin.getSteps(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);

// Read heart rate data
final heartRate = await healthPlugin.getHeartRate(
  startDate: DateTime.now().subtract(Duration(hours: 24)),
  endDate: DateTime.now(),
);
```

## Example App

Check out the [example app](./example) for a complete implementation demonstrating all plugin features.

## Permissions

This plugin requires appropriate health data permissions on both platforms:

- **Android**: Samsung Health app must be installed and permissions granted
- **iOS**: HealthKit permissions must be granted by the user

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For questions and support, please open an issue on [GitHub](https://github.com/896518640/dnurse_health_plugin/issues).


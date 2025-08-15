# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2025-01-15

### Added
- Initial release of Health Bridge plugin
- Cross-platform health data integration for Android and iOS
- Samsung Health SDK support for Android devices
- Apple HealthKit integration for iOS devices
- Unified data models for health metrics including:
  - Step counts and walking data
  - Heart rate measurements
  - Blood pressure readings
  - Weight and body measurements
  - Sleep tracking data
  - Exercise and workout sessions
- Privacy-focused implementation with user consent management
- Example app demonstrating plugin usage
- Comprehensive documentation and setup guides

### Platform Support
- **Android**: Minimum SDK 24+, Samsung Health integration
- **iOS**: HealthKit integration with proper permission handling

### Dependencies
- Flutter SDK 3.3.0+
- Dart SDK 3.4.1+
- plugin_platform_interface ^2.0.2

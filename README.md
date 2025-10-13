# Health Bridge

A Flutter plugin for integrating health data across different platforms, providing unified access to health and fitness information.

## Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Samsung Health (Android) | ✅ Supported | Requires Samsung Health app installed |
| Apple HealthKit (iOS) | ✅ Supported | Native iOS integration |
| Huawei Health (Android) | ✅ Supported | Requires Huawei Health app and HMS Core |
| HarmonyOS NEXT | 🚧 In Development | Basic structure completed, health integration in progress |
| Google Fit (Android) | 🚧 Coming Soon | Planned for future release |

## Supported Health Data Types

- Step counts and walking data
- Heart rate measurements
- Blood pressure readings
- Weight and body measurements
- Sleep tracking data
- Exercise and workout sessions
- Blood glucose levels
- Body fat percentage
- BMI (Body Mass Index)
- Respiratory rate
- Oxygen saturation
- Distance and calories

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  health_bridge: ^0.0.1
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### Android Setup

#### For Samsung Health

Add Samsung Health SDK permissions to your `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="com.samsung.android.providers.health.permission.READ" />
<uses-permission android:name="com.samsung.android.providers.health.permission.WRITE" />
```

#### For Huawei Health

See the detailed **华为健康 Demo 调试步骤** section below for complete setup and debugging guide.

#### Common Android Configuration

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
import 'package:health_bridge/health_bridge.dart';

// Initialize the plugin
final healthPlugin = HealthBridge();

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

## 华为健康 Demo 调试步骤

### 前置准备

1. **注册华为开发者账号**
   - 访问 [华为开发者联盟](https://developer.huawei.com/consumer/cn/)
   - 完成实名认证

2. **创建应用并申请 Health Kit 服务**
   - 在开发者控制台创建应用
   - 在"服务" → "Health Kit"中申请服务
   - 等待审核通过（通常 1-2 个工作日）

3. **配置应用签名证书**
   - 生成签名证书（如果还没有）:
     ```bash
     keytool -genkey -v -keystore key.keystore -alias YOUR_ALIAS -keyalg RSA -keysize 2048 -validity 10000
     ```
   - 获取 SHA-256 证书指纹:
     ```bash
     keytool -list -v -keystore key.keystore -alias YOUR_ALIAS
     ```
   - 在华为开发者控制台配置证书指纹

### 配置步骤

#### 1. 下载并配置 agconnect-services.json

从华为开发者控制台下载 `agconnect-services.json` 文件，放置到：
```
example/android/app/agconnect-services.json
```

#### 2. 配置项目级 build.gradle

在 `example/android/build.gradle` 中添加：

```gradle
buildscript {
    repositories {
        google()
        mavenCentral()
        maven { url 'https://developer.huawei.com/repo/' }  // 添加华为 Maven 仓库
    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.3.0'
        classpath 'com.huawei.agconnect:agcp:1.9.1.301'    // 添加 AGConnect 插件
    }
}
```

#### 3. 配置应用级 build.gradle

在 `example/android/app/build.gradle` 顶部添加插件：

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    id "com.huawei.agconnect"  // 添加 AGConnect 插件
}
```

确保包名与华为控制台配置一致：

```gradle
android {
    namespace = "com.your.package.name"  // 必须与 agconnect-services.json 中的 package_name 一致
    defaultConfig {
        applicationId = "com.your.package.name"
        minSdkVersion 24  // 华为 Health Kit 要求最低 API 24
        targetSdkVersion 34
    }
}
```

#### 4. 配置 AndroidManifest.xml

在 `example/android/app/src/main/AndroidManifest.xml` 的 `<application>` 标签内添加：

```xml
<!-- 华为 HMS Core App ID -->
<meta-data
    android:name="com.huawei.hms.client.appid"
    android:value="appid=YOUR_APP_ID"/>  <!-- 从 agconnect-services.json 中获取 -->
```

#### 5. 配置签名（用于调试和发布）

创建 `example/android/key.properties` 文件：

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=path/to/your/key.keystore
```

在 `example/android/app/build.gradle` 中配置签名：

```gradle
// 加载签名配置
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
        debug {
            // Debug 版本也使用相同的签名，确保证书指纹一致
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
        debug {
            signingConfig signingConfigs.debug
        }
    }
}
```

### 运行调试

#### 1. 确保设备满足要求

- 华为/荣耀设备
- Android 7.0 (API 24) 及以上
- 已安装华为运动健康 App (版本 11.0.0.512+)
- 已安装 HMS Core (版本 4.0.2.300+)

#### 2. 构建并运行

```bash
cd example
flutter clean
flutter pub get
flutter run -d <device-id>
```

或者使用热重载（如果应用已在运行）：
```
按 'r' 键进行热重载
按 'R' 键进行热重启
```

#### 3. 查看调试日志

使用 logcat 查看详细日志：

```bash
# 查看华为健康相关日志
adb logcat | grep "HuaweiHealthProvider"

# 查看完整的初始化和权限请求日志
adb logcat | grep -E "HuaweiHealthProvider|AGConnect|HMS|===|Scope"

# 查看特定设备的日志
adb -s <device-id> logcat | grep "HuaweiHealthProvider"
```

#### 4. 调试检查清单

**初始化阶段日志：**
```
✅ AGConnectProvider#onCreate
✅ AGConnectInstance#initialize
✅ Huawei Health is available
✅ === Huawei Health Kit Initialization Start ===
✅ Package name: com.your.package.name
✅ AGConnect App ID from manifest: appid=YOUR_APP_ID
✅ SettingController created: true
✅ DataController created: true
✅ === Huawei Health Kit initialized successfully ===
```

**权限请求阶段日志：**
```
✅ === Request Permissions Start ===
✅ Activity available: MainActivity
✅ SettingController is ready
✅ Calling requestAuthorizationIntent...
✅ Got authorization intent successfully
```

**如果遇到问题：**

| 日志信息 | 可能原因 | 解决方案 |
|---------|---------|---------|
| `SettingController is null!` | Provider 未初始化 | 已在最新代码中自动修复 |
| `App ID not found` | AndroidManifest.xml 未配置 App ID | 检查 meta-data 配置 |
| `Failed to get authorization intent` | Health Kit 服务未启用或证书指纹不匹配 | 检查华为控制台配置 |
| `Package name mismatch` | 包名不一致 | 确保代码、配置文件、控制台三处包名一致 |

### 常见问题排查

1. **证书指纹不匹配**
   - 确认 debug 和 release 版本使用相同的签名证书
   - 验证华为控制台配置的 SHA-256 指纹与本地证书一致
   - 使用命令验证：`keytool -list -v -keystore key.keystore`

2. **Health Kit 服务未启用**
   - 登录华为开发者控制台
   - 进入应用 → 服务 → Health Kit
   - 确认状态为"已启用"或"审核已通过"

3. **HMS Core 版本过低**
   - 在设备上打开"设置" → "应用" → "HMS Core"
   - 检查版本是否 ≥ 4.0.2.300
   - 如需更新，访问华为应用市场

4. **包名、App ID、证书指纹三者必须匹配**
   - 包名：代码中的 `applicationId` = `agconnect-services.json` 中的 `package_name` = 华为控制台配置
   - App ID：代码中的 meta-data = `agconnect-services.json` 中的 `app_id` = 华为控制台应用 ID
   - 证书指纹：本地签名证书的 SHA-256 = 华为控制台配置的证书指纹

### 测试功能

在 example 应用中测试以下功能：

1. **查看可用平台** - 应显示 "huawei_health"
2. **查看平台能力** - 显示支持的数据类型
3. **申请读权限** - 测试权限请求流程
4. **读取健康数据** - 测试步数、心率等数据读取
5. **写入健康数据** - 测试体重、身高等数据写入

### 相关文档

- [华为 Health Kit 开发指南](https://developer.huawei.com/consumer/cn/doc/HMSCore-Guides/health-assemble-0000001050071707)
- [华为开发者控制台](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
- [项目内部文档](docs/HUAWEI_HEALTH_INTEGRATION.md)

## Permissions

This plugin requires appropriate health data permissions on each platform:

- **Samsung Health (Android)**: Samsung Health app must be installed and permissions granted
- **Huawei Health (Android)**: Huawei Health app and HMS Core must be installed, app must be registered in Huawei Developer Console
- **Apple Health (iOS)**: HealthKit permissions must be granted by the user

**Important**: For production use with Huawei Health, you must:
1. Register your app in [Huawei Developer Console](https://developer.huawei.com/consumer/cn/)
2. Apply for Health Kit service
3. Configure your app's signature certificate
4. Add the App ID to your AndroidManifest.xml

See [Huawei Health Integration Guide](docs/HUAWEI_HEALTH_INTEGRATION.md) for complete setup instructions.

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting a pull request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For questions and support, please open an issue on [GitHub](https://github.com/896518640/health_bridge/issues).


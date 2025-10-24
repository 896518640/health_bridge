# Health Bridge

A Flutter plugin for integrating health data across different platforms, providing unified access to health and fitness information.

## 📚 Architecture Overview

This plugin is organized into modular components for better maintainability:

```
lib/src/
├── oauth/          # OAuth 2.0 authorization module (PKCE)
│   ├── huawei_oauth_config.dart     # OAuth configuration
│   ├── huawei_oauth_helper.dart     # OAuth helper (recommended Layer 2 API)
│   └── huawei_auth_service.dart     # OAuth HTTP service
├── cloud/          # Cloud-side data access module
│   ├── huawei_cloud_client.dart     # Huawei Health Cloud API client
│   └── huawei_cloud_models.dart     # Cloud API data models
└── models/         # Common data models
    ├── health_data.dart             # Health data types
    └── health_platform.dart         # Platform definitions
```

### Module Responsibilities

| Module | Purpose | Dependencies |
|--------|---------|--------------|
| **oauth** | User authentication, obtain access tokens | None |
| **cloud** | Access health data via Cloud APIs | Requires access_token from oauth |
| **models** | Shared data structures | None |

**Typical workflow:**
1. Use **oauth** module → Get `access_token` via OAuth 2.0 PKCE flow
2. Use **cloud** module → Pass `access_token` to query health data from Huawei Cloud APIs
3. Use **models** → Parse and convert data to unified format

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

---

## 华为 OAuth 集成指南（推荐 Layer 2 半托管方案）

> ⚠️ **重要提示**：由于华为官方 PKCE 模式刷新 token 的接口文档存在问题，**refresh_token 功能暂时禁用**。当前版本建议在 access_token 过期后重新引导用户登录授权。我们正在与华为沟通解决此问题，待官方接口文档修复后会立即恢复该功能。

### 为什么需要 OAuth？

华为健康云侧 API 需要通过 OAuth 2.0 授权才能访问用户的健康数据。我们提供了**半托管的 OAuth 辅助类**，让您可以：

- ✅ 使用插件提供的核心 OAuth 逻辑（URL 生成、PKCE、Token 交换）
- ✅ 使用自己的 WebView 实现（完全自定义 UI 和业务逻辑）
- ✅ 完全控制 Token 的存储方式
- ✅ 轻松集成，无需深入了解 OAuth 2.0 和 PKCE 细节

### 快速开始（5 步集成）

#### 步骤 1：添加依赖

确保已在 `pubspec.yaml` 中添加必要的依赖：

```yaml
dependencies:
  health_bridge: ^0.0.1
  webview_flutter: ^4.4.0  # 用于自定义 WebView
  flutter_secure_storage: ^9.0.0  # 推荐用于安全存储 Token
```

#### 步骤 2：初始化 OAuth 辅助类

```dart
import 'package:health_bridge/health_bridge.dart';

final oauthHelper = HuaweiOAuthHelper(
  config: HuaweiOAuthConfig(
    clientId: 'your_client_id',  // 从华为开发者控制台获取
    redirectUri: 'https://your-domain.com/callback',  // 您的回调地址
    scopes: [
      'openid',
      'https://www.huawei.com/healthkit/step.read',
      'https://www.huawei.com/healthkit/bloodpressure.read',
    ],
    state: 'random_state_${DateTime.now().millisecondsSinceEpoch}',
    codeChallengeMethod: 'S256',  // PKCE 加密方法
  ),
);
```

#### 步骤 3：生成授权 URL 并在 WebView 中打开

```dart
import 'package:webview_flutter/webview_flutter.dart';

// 生成授权 URL
final authUrl = oauthHelper.generateAuthUrl();

// 在您的自定义 WebView 中打开
final webViewController = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setNavigationDelegate(
    NavigationDelegate(
      onNavigationRequest: (request) {
        // 监听导航，检查是否是回调 URL
        if (oauthHelper.isCallbackUrl(request.url)) {
          // 拦截回调 URL
          _handleCallback(request.url);
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      },
    ),
  )
  ..loadRequest(Uri.parse(authUrl));

// 在页面中显示 WebView
Scaffold(
  body: WebViewWidget(controller: webViewController),
);
```

#### 步骤 4：解析回调并换取 Token

```dart
Future<void> _handleCallback(String callbackUrl) async {
  // 解析回调 URL
  final params = oauthHelper.parseCallback(callbackUrl);

  if (params == null) {
    print('❌ 解析失败');
    return;
  }

  // 检查是否有错误
  if (params['error'] != null) {
    print('❌ 授权失败: ${params['error']}');
    return;
  }

  // 获取授权码
  final code = params['code'];
  if (code == null) {
    print('❌ 未获取到授权码');
    return;
  }

  // 用授权码换取 Token
  final result = await oauthHelper.exchangeToken(code);

  if (result.isSuccess) {
    print('✅ 授权成功！');
    print('Access Token: ${result.accessToken}');
    print('过期时间: ${result.expiresIn} 秒');

    // 保存 Token（下一步）
    await _saveToken(result);
  } else {
    print('❌ Token 交换失败: ${result.error}');
  }
}
```

#### 步骤 5：安全存储 Token（推荐）

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

// 保存 Token
Future<void> _saveToken(HuaweiOAuthResult result) async {
  await storage.write(key: 'access_token', value: result.accessToken);
  await storage.write(key: 'refresh_token', value: result.refreshToken);

  // 计算过期时间
  final expiresAt = DateTime.now().add(Duration(seconds: result.expiresIn!));
  await storage.write(key: 'expires_at', value: expiresAt.toIso8601String());

  print('💾 Token 已保存到安全存储');
}

// 获取有效的 Token
Future<String?> getValidToken() async {
  final token = await storage.read(key: 'access_token');
  final expiresAtStr = await storage.read(key: 'expires_at');

  if (token == null) return null;

  // 检查是否过期
  if (expiresAtStr != null) {
    final expiresAt = DateTime.parse(expiresAtStr);
    if (DateTime.now().isAfter(expiresAt)) {
      // Token 已过期，需要刷新
      return await _refreshToken();
    }
  }

  return token;
}

// ⚠️ 注意：刷新功能暂时禁用（华为官方 PKCE 接口文档问题）
// 当前建议：access_token 过期后重新引导用户登录授权
/*
// 刷新 Token（待华为官方接口修复后启用）
Future<String?> _refreshToken() async {
  final refreshToken = await storage.read(key: 'refresh_token');
  if (refreshToken == null) return null;

  // 使用 PKCE 模式刷新（自动使用初始的 code_verifier）
  final result = await oauthHelper.refreshToken(refreshToken);

  if (result.isSuccess) {
    // 保存新的 access_token
    await storage.write(key: 'access_token', value: result.accessToken);

    // ⚠️ 关键：检查是否有新的 refresh_token（华为可能返回新的）
    if (result.refreshToken != null && result.refreshToken != refreshToken) {
      print('🔄 检测到新的 refresh_token，立即更新！');
      print('旧 RT: ${refreshToken.substring(0, 30)}...');
      print('新 RT: ${result.refreshToken!.substring(0, 30)}...');

      // 立即保存新的 refresh_token
      await storage.write(key: 'refresh_token', value: result.refreshToken);
    }

    // 更新过期时间
    final expiresAt = DateTime.now().add(Duration(seconds: result.expiresIn!));
    await storage.write(key: 'expires_at', value: expiresAt.toIso8601String());

    return result.accessToken;
  }

  return null;
}
*/
```

### 完整示例代码

查看 [example/lib/pages/huawei_oauth_helper_example.dart](example/lib/pages/huawei_oauth_helper_example.dart) 获取完整的可运行示例，包括：

- 自定义 WebView UI（进度条、Banner 等）
- 自定义埋点统计
- 错误处理
- Token 刷新
- ID Token 解析

### API 参考

#### HuaweiOAuthHelper 主要方法

| 方法 | 说明 | 返回值 |
|------|------|--------|
| `generateAuthUrl()` | 生成授权 URL | `String` |
| `isCallbackUrl(url)` | 检查是否是回调 URL | `bool` |
| `parseCallback(url)` | 解析回调 URL，提取授权码 | `Map<String, String>?` |
| `exchangeToken(code)` | 用授权码换取 Token | `Future<HuaweiOAuthResult>` |
| ~~`refreshToken(token)`~~ | ~~刷新 Access Token~~ | ⚠️ **暂时禁用** |
| `parseIdToken(token)` | 解析 ID Token 获取用户信息 | `Map<String, dynamic>?` |

#### HuaweiOAuthResult 字段

| 字段 | 类型 | 说明 |
|------|------|------|
| `accessToken` | `String?` | 访问令牌 |
| `refreshToken` | `String?` | 刷新令牌 |
| `idToken` | `String?` | ID Token (JWT 格式) |
| `expiresIn` | `int?` | 过期时间（秒） |
| `scope` | `String?` | 授权的权限范围 |
| `isSuccess` | `bool` | 是否成功 |
| `error` | `String?` | 错误码 |
| `errorDescription` | `String?` | 错误描述 |

### 常见问题

<details>
<summary><b>Q1: 为什么推荐使用 Layer 2 半托管方案？</b></summary>

**A:** Layer 2 方案提供了最佳的灵活性和易用性平衡：

- ✅ **易于集成**：插件处理复杂的 OAuth 逻辑（PKCE、Token 交换等）
- ✅ **高度灵活**：您可以完全自定义 WebView UI 和业务逻辑
- ✅ **完全控制**：Token 存储、刷新策略由您决定
- ✅ **职责清晰**：插件专注于 OAuth 核心功能，不干涉您的业务逻辑

</details>

<details>
<summary><b>Q2: Token 应该如何存储？</b></summary>

**A:** 推荐使用 `flutter_secure_storage`：

```dart
// ✅ 推荐：使用安全存储
final storage = FlutterSecureStorage();
await storage.write(key: 'access_token', value: token);

// ❌ 不推荐：SharedPreferences 不够安全
final prefs = await SharedPreferences.getInstance();
await prefs.setString('access_token', token);  // 不安全！
```

安全存储的优势：
- 在 iOS 上使用 Keychain
- 在 Android 上使用 EncryptedSharedPreferences
- 数据加密存储，更安全
</details>

<details>
<summary><b>Q3: 如何处理 Token 过期？</b></summary>

**A:** ⚠️ **由于华为官方 PKCE 模式刷新接口文档问题，refresh_token 功能暂时禁用。**

**当前建议方案：**
```dart
Future<String?> getValidToken() async {
  final token = await storage.read(key: 'access_token');
  final expiresAt = await storage.read(key: 'expires_at');

  // 检查是否过期
  if (expiresAt != null) {
    final expiry = DateTime.parse(expiresAt);
    if (DateTime.now().isAfter(expiry)) {
      // ⚠️ Token 已过期，需要重新授权
      print('⚠️ Access Token 已过期，请重新登录授权');
      return null; // 返回 null，触发重新登录流程
    }
  }

  return token;
}
```

**处理过期的推荐流程：**
1. 定期检查 `expires_at`（建议提前 5 分钟检查）
2. 如果即将过期或已过期，引导用户重新授权
3. 用户完成授权后，保存新的 access_token 和过期时间

**待官方接口修复后的自动刷新方案：**
<details>
<summary>点击查看（待启用）</summary>

```dart
Future<String?> getValidToken() async {
  final token = await storage.read(key: 'access_token');
  final expiresAt = await storage.read(key: 'expires_at');

  // 检查是否即将过期（提前 5 分钟）
  if (expiresAt != null) {
    final expiry = DateTime.parse(expiresAt);
    if (DateTime.now().isAfter(expiry.subtract(Duration(minutes: 5)))) {
      // 自动刷新
      return await _refreshToken();
    }
  }

  return token;
}

Future<String?> _refreshToken() async {
  final oldRefreshToken = await storage.read(key: 'refresh_token');
  if (oldRefreshToken == null) return null;

  // PKCE 模式刷新（自动使用初始的 code_verifier）
  final result = await oauthHelper.refreshToken(oldRefreshToken);

  if (result.isSuccess) {
    await storage.write(key: 'access_token', value: result.accessToken);

    // ⚠️ 关键：refresh_token 可能会变化！
    if (result.refreshToken != null && result.refreshToken != oldRefreshToken) {
      print('🔄 检测到新的 refresh_token，立即更新！');
      await storage.write(key: 'refresh_token', value: result.refreshToken);
    }

    final expiresAt = DateTime.now().add(Duration(seconds: result.expiresIn!));
    await storage.write(key: 'expires_at', value: expiresAt.toIso8601String());

    return result.accessToken;
  }

  return null;
}
```
</details>
</details>

<details>
<summary><b>Q4: 可以不使用 WebView 吗？</b></summary>

**A:** OAuth 2.0 授权流程需要用户在浏览器中登录华为账号，因此必须使用 WebView 或系统浏览器。

如果您希望使用系统浏览器（更安全），可以：
1. 使用 `url_launcher` 打开授权 URL
2. 配置 Deep Link 或 App Link 接收回调
3. 使用 `parseCallback()` 解析回调 URL

但推荐使用 WebView，因为：
- 用户体验更好（不离开 App）
- 更容易控制流程
- 无需配置复杂的 Deep Link
</details>

<details>
<summary><b>Q5: clientId 和 redirectUri 从哪里获取？</b></summary>

**A:** 需要在华为开发者控制台配置：

1. 访问 [华为开发者联盟](https://developer.huawei.com/consumer/cn/)
2. 创建应用并启用 Health Kit 服务
3. 在"OAuth 2.0 客户端"中配置：
   - **Client ID**：系统自动生成
   - **Redirect URI**：您的回调地址（建议使用 HTTPS）

详见下方的"华为健康 Demo 调试步骤"。
</details>

### 安全建议

1. ✅ **使用 PKCE 模式**（已默认启用 `S256`，整个流程使用 code_verifier 而非 client_secret）
2. ✅ **使用安全存储**（`flutter_secure_storage`）
3. ✅ **验证 state 参数**（防止 CSRF 攻击）
4. ✅ **使用 HTTPS 回调地址**
5. ⚠️ **Token 过期处理**：当前建议重新授权（refresh 功能暂时禁用）
6. ✅ **不要在日志中打印完整 Token**
7. ✅ **保持 code_verifier 不变**（PKCE 模式在整个授权周期内使用同一个 code_verifier）

### PKCE 模式说明

本插件使用 **PKCE (Proof Key for Code Exchange)** 模式进行 OAuth 2.0 授权，这是专为公共客户端（如移动应用）设计的安全授权方式：

**关键特性：**
- ✅ 不需要 `client_secret`（更安全）
- ✅ 使用动态生成的 `code_verifier` 和 `code_challenge`
- ✅ 整个授权周期（包括刷新 token）都使用同一个 `code_verifier`
- ✅ 支持 `access_type=offline` 获取 refresh_token

**PKCE 流程：**
```
1. 生成 code_verifier (随机 128 字符)
2. 计算 code_challenge = BASE64URL(SHA256(code_verifier))
3. 授权请求：带上 code_challenge + code_challenge_method=S256 + access_type=offline
4. 换取 token：用 code + code_verifier
5. 刷新 token：用 refresh_token + code_verifier ← ⚠️ 暂时禁用（接口文档问题）
```

### Token 过期处理（当前方案）

> ⚠️ **重要**：由于华为官方 PKCE 模式刷新接口文档存在问题，refresh_token 功能暂时禁用。

**当前建议方案：**
- Access Token 有效期：1 小时
- 过期后：引导用户重新授权
- 建议：提前 5 分钟检查并提醒用户

**代码示例：**
```dart
Future<String?> getValidToken() async {
  final token = await storage.read(key: 'access_token');
  final expiresAt = await storage.read(key: 'expires_at');

  if (expiresAt != null) {
    final expiry = DateTime.parse(expiresAt);
    if (DateTime.now().isAfter(expiry)) {
      // Token 已过期，需要重新授权
      return null;
    }
  }

  return token;
}
```

### refresh_token 生命周期管理（待启用）

> 📝 **说明**：以下功能待华为官方接口文档修复后启用。

根据华为官方文档，refresh_token 可能会在以下情况变化：
- 使用 `access_type=offline` 参数刷新时
- 长时间未使用后刷新时
- 安全策略触发时

**最佳实践（待启用）：**
```dart
// ⚠️ 注意：此功能暂时禁用，待华为官方接口修复后启用
/*
// ✅ 推荐：每次刷新都检查 refresh_token 变化
final result = await oauthHelper.refreshToken(oldRefreshToken);

if (result.isSuccess) {
  // 保存新 token
  await storage.write(key: 'access_token', value: result.accessToken);

  // 检查 refresh_token 是否变化
  if (result.refreshToken != null && result.refreshToken != oldRefreshToken) {
    // 立即更新保存
    await storage.write(key: 'refresh_token', value: result.refreshToken);
    print('✅ refresh_token 已更新');
  }
}
*/
```

**注意：** PKCE 模式刷新 token 时会自动使用初始授权时生成的 `code_verifier`，您无需手动管理。

---

## 授权管理 API（新增）

在完成 OAuth 授权后，您可以使用以下三个云侧 API 来管理用户的授权状态和权限。

### API 概览

| API | 功能 | 使用场景 |
|-----|------|----------|
| **checkPrivacyAuthStatus()** | 查询隐私授权状态 | 检查用户是否在华为运动健康App中开启了数据共享 |
| **getUserConsents()** | 查询用户授权权限 | 查看用户具体授权了哪些健康数据权限 |
| **revokeConsent()** | 取消授权 | 撤销所有健康数据访问权限 |

### 1️⃣ 查询隐私授权状态

检查用户是否在华为运动健康App中开启了数据共享授权。

```dart
import 'package:health_bridge/health_bridge.dart';

// 创建云侧API客户端
final client = HuaweiCloudClient(
  accessToken: yourAccessToken,  // 从 OAuth 流程获取
  clientId: 'your_client_id',
);

// 查询隐私授权状态
final status = await client.checkPrivacyAuthStatus();

if (status.isAuthorized) {
  // 已授权，可以访问健康数据
  print('✅ 用户已授权');
} else if (status == PrivacyAuthStatus.notAuthorized) {
  // 需要引导用户去华为运动健康App开启授权
  print('⚠️ 用户未授权，请引导用户开启数据共享');
  // TODO: 显示引导对话框
} else {
  // 用户没有安装华为运动健康App
  print('❌ 用户未安装华为运动健康App');
}
```

**返回值：**
- `PrivacyAuthStatus.authorized` (1)：已授权
- `PrivacyAuthStatus.notAuthorized` (2)：未授权
- `PrivacyAuthStatus.notHealthUser` (3)：非华为运动健康App用户

### 2️⃣ 查询用户授权权限

获取用户授权给应用的所有健康数据权限详情。

```dart
// 查询用户授权的权限列表
final consentInfo = await client.getUserConsents(
  appId: 'your_client_id',  // 通常与 clientId 相同
  lang: 'zh-cn',  // 'zh-cn' 或 'en-US'
);

print('应用名称: ${consentInfo.appName}');
print('授权时间: ${consentInfo.authTime}');
print('权限数量: ${consentInfo.scopeCount}');

// 查看已授权的所有权限
print('已授权的权限:');
consentInfo.scopeDescriptions.forEach((scope, description) {
  print('  $scope');
  print('    → $description');
});

// 检查是否授权了特定权限
if (consentInfo.hasScope('https://www.huawei.com/healthkit/sleep.read')) {
  print('✅ 有睡眠数据读取权限');
}
```

**返回数据：**
```dart
class UserConsentInfo {
  Map<String, String> scopeDescriptions; // 权限URL到描述的映射
  DateTime authTime;                     // 授权时间
  String appName;                        // 应用名称
  String? appIconPath;                   // 应用图标（可选）

  List<String> get authorizedScopes;     // 已授权的scope列表
  bool hasScope(String scope);           // 检查是否有某个权限
  int get scopeCount;                    // 权限数量
}
```

### 3️⃣ 取消授权

撤销用户对该应用的全部健康数据访问权限。

```dart
// 取消授权（保留数据3天）
final success = await client.revokeConsent(
  appId: 'your_client_id',
  deleteDataImmediately: false,  // false: 3天后删除数据，true: 立即删除
);

if (success) {
  print('✅ 授权已取消');

  // ⚠️ 重要：清除本地存储的 token
  await secureStorage.delete(key: 'access_token');
  await secureStorage.delete(key: 'refresh_token');

  // 提示用户
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('授权已取消'),
      content: Text('如需继续使用健康数据功能，请在3天内重新授权。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('知道了'),
        ),
      ],
    ),
  );
} else {
  print('❌ 取消授权失败');
}
```

**参数说明：**
- `deleteDataImmediately: false`（推荐）：给用户3天反悔期
- `deleteDataImmediately: true`：立即删除所有数据

### 完整使用示例

```dart
import 'package:health_bridge/health_bridge.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HealthDataManager {
  final storage = FlutterSecureStorage();

  /// 检查并获取健康数据
  Future<void> fetchHealthData() async {
    // 1. 获取 access_token
    final accessToken = await storage.read(key: 'access_token');
    if (accessToken == null) {
      print('❌ 未登录，请先进行 OAuth 授权');
      return;
    }

    // 2. 创建云侧客户端
    final client = HuaweiCloudClient(
      accessToken: accessToken,
      clientId: 'your_client_id',
    );

    // 3. 检查隐私授权状态
    final privacyStatus = await client.checkPrivacyAuthStatus();
    if (!privacyStatus.isAuthorized) {
      print('⚠️ 用户未在华为运动健康App中开启数据共享');
      // TODO: 引导用户开启
      return;
    }

    // 4. 查看授权的权限
    final consents = await client.getUserConsents(appId: 'your_client_id');
    print('✅ 已授权 ${consents.scopeCount} 个权限');

    // 5. 检查是否有需要的权限
    if (!consents.hasScope('https://www.huawei.com/healthkit/step.read')) {
      print('⚠️ 没有步数数据权限');
      return;
    }

    // 6. 读取健康数据
    final result = await client.readHealthData(
      dataType: HealthDataType.steps,
      startTime: DateTime.now().subtract(Duration(days: 7)).millisecondsSinceEpoch,
      endTime: DateTime.now().millisecondsSinceEpoch,
    );

    print('📊 获取到 ${result.totalCount} 条步数数据');
  }

  /// 撤销授权
  Future<void> logout() async {
    final accessToken = await storage.read(key: 'access_token');
    if (accessToken == null) return;

    final client = HuaweiCloudClient(
      accessToken: accessToken,
      clientId: 'your_client_id',
    );

    // 取消授权
    final success = await client.revokeConsent(
      appId: 'your_client_id',
      deleteDataImmediately: false,  // 保留3天
    );

    if (success) {
      // 清除本地 token
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
      print('✅ 已登出');
    }
  }
}
```

### 最佳实践

1. **调用顺序建议：**
   ```
   OAuth 授权 → 隐私授权状态检查 → 用户授权权限查询 → 读取健康数据
   ```

2. **错误处理：**
   - 隐私未授权（`notAuthorized`）：引导用户去华为运动健康App开启数据共享
   - 非健康用户（`notHealthUser`）：提示用户安装华为运动健康App
   - 权限不足：提示用户重新授权，申请更多权限

3. **安全提示：**
   - 始终使用 `flutter_secure_storage` 存储 `access_token`
   - 取消授权后立即清除本地 token
   - 定期检查 token 是否过期

### 演示页面

授权管理功能已整合到华为 OAuth V2 页面中：
- 文件路径：`example/lib/pages/huawei_oauth_test_page_v2.dart`
- 在示例应用中点击"OAuth 授权管理"（V2 半托管）卡片
- 完成 OAuth 授权后，页面下方会显示"🔐 授权管理"区域
- 包含三个功能按钮：
  - **隐私状态** - 查询隐私授权状态
  - **查询权限** - 查看已授权的权限列表
  - **取消授权** - 撤销所有授权

**使用流程：**
1. 点击"开始授权"完成 OAuth 2.0 授权
2. 获取 access_token 后，向下滚动查看"授权管理"区域
3. 点击对应按钮体验三个授权管理 API

---

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


import 'package:flutter/foundation.dart';
import 'package:health_bridge/src/oauth/huawei_oauth_config.dart';
import 'package:health_bridge/src/oauth/huawei_auth_service.dart';

/// 【中层 API】半托管的 OAuth 辅助类
///
/// 这是推荐的 OAuth 集成方式，提供了易用性和灵活性的最佳平衡。
///
/// 职责分离：
/// - 插件负责：生成授权 URL、管理 PKCE、交换 Token
/// - App 负责：自定义 WebView UI、添加业务逻辑、Token 存储
///
/// 使用流程：
/// ```dart
/// // 1. 创建辅助类实例
/// final helper = HuaweiOAuthHelper(
///   config: HuaweiOAuthConfig(
///     clientId: 'your_client_id',
///     redirectUri: 'your_redirect_uri',
///     scopes: ['openid', 'https://www.huawei.com/healthkit/step.read'],
///     state: 'random_state',
///     codeChallengeMethod: 'S256',
///   ),
/// );
///
/// // 2. 生成授权 URL
/// final authUrl = helper.generateAuthUrl();
///
/// // 3. 在您自己的 WebView 中打开 authUrl
/// // 4. 监听 WebView 的导航事件
/// // 5. 当检测到回调 URL 时，解析授权码
/// final params = helper.parseCallback(callbackUrl);
///
/// // 6. 用授权码换取 Token
/// if (params?['code'] != null) {
///   final result = await helper.exchangeToken(params['code']!);
///
///   if (result.isSuccess) {
///     // 保存 Token（使用您自己的存储方案）
///     await myTokenStorage.save(result);
///   }
/// }
/// ```
///
/// 详细的接入指南请参考 README.md 文档。
class HuaweiOAuthHelper {
  /// OAuth 配置（包含 PKCE 参数）
  final HuaweiOAuthConfig config;

  /// 认证服务（内部使用）
  late final HuaweiAuthService _authService;

  /// 创建 OAuth 辅助类实例
  ///
  /// 参数：
  /// - [config]: OAuth 配置，包含 clientId、redirectUri、scopes 等
  ///
  /// 示例：
  /// ```dart
  /// final helper = HuaweiOAuthHelper(
  ///   config: HuaweiOAuthConfig(
  ///     clientId: '108913819',
  ///     redirectUri: 'https://your-domain.com/callback',
  ///     scopes: ['openid', 'https://www.huawei.com/healthkit/step.read'],
  ///     state: 'random_state_${DateTime.now().millisecondsSinceEpoch}',
  ///     codeChallengeMethod: 'S256',
  ///   ),
  /// );
  /// ```
  HuaweiOAuthHelper({required this.config}) {
    _authService = HuaweiAuthService(config: config);
  }

  /// Step 1: 生成授权 URL
  ///
  /// 返回华为 OAuth 授权页面的 URL，您需要在自己的 WebView 中打开这个 URL。
  ///
  /// 返回示例：
  /// ```
  /// https://oauth-login.cloud.huawei.com/oauth2/v3/authorize?
  /// response_type=code&client_id=xxx&redirect_uri=xxx&scope=openid&
  /// code_challenge=xxx&code_challenge_method=S256&state=xxx
  /// ```
  ///
  /// 使用示例：
  /// ```dart
  /// final authUrl = helper.generateAuthUrl();
  ///
  /// // 在您的 WebView 中打开
  /// _webViewController.loadRequest(Uri.parse(authUrl));
  /// ```
  String generateAuthUrl() {
    final url = config.buildAuthorizeUrl();
    final uri = Uri.parse(url);

    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  步骤 1: 获取授权码 (Authorization Code)');
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  请求方式: GET');
    debugPrint('[Response]  请求 URL: ${uri.scheme}://${uri.host}${uri.path}');
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  完整 URL:');
    debugPrint('[Response]  $url');
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  请求参数详情:');
    uri.queryParameters.forEach((key, value) {
      if (key == 'code_challenge' || key == 'code_verifier') {
        // 只显示前 30 个字符
        final preview = value.length > 30 ? '${value.substring(0, 30)}...' : value;
        debugPrint('[Response]    $key: $preview (长度: ${value.length})');
      } else if (key == 'scope') {
        // scope 可能很长，换行显示
        debugPrint('[Response]    $key: $value');
      } else {
        debugPrint('[Response]    $key: $value');
      }
    });
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  📌 用户需在浏览器/WebView 中访问此 URL 进行授权');
    debugPrint('[Response]  📌 授权成功后，华为将重定向到 redirect_uri 并附带 code 参数');
    debugPrint('[Response]  ========================================');

    return url;
  }

  /// Step 2: 检查 URL 是否是回调 URL
  ///
  /// 在 WebView 的导航监听中使用此方法判断是否是回调 URL。
  ///
  /// 参数：
  /// - [url]: 当前 WebView 正在导航到的 URL
  ///
  /// 返回：
  /// - `true`: 是回调 URL，应该拦截并解析
  /// - `false`: 不是回调 URL，继续正常导航
  ///
  /// 使用示例：
  /// ```dart
  /// NavigationDelegate(
  ///   onNavigationRequest: (request) {
  ///     if (helper.isCallbackUrl(request.url)) {
  ///       _handleCallback(request.url);
  ///       return NavigationDecision.prevent; // 拦截
  ///     }
  ///     return NavigationDecision.navigate; // 继续导航
  ///   },
  /// )
  /// ```
  bool isCallbackUrl(String url) {
    return url.startsWith(config.redirectUri);
  }

  /// Step 3: 解析回调 URL，提取授权码或错误信息
  ///
  /// 当检测到回调 URL 后，使用此方法解析 URL 中的参数。
  ///
  /// 参数：
  /// - [callbackUrl]: 回调 URL（完整的 URL 字符串）
  ///
  /// 返回：
  /// - 成功时返回包含 'code' 和 'state' 的 Map
  /// - 失败时返回包含 'error' 和 'error_description' 的 Map
  /// - 解析失败返回 null
  ///
  /// 返回值示例：
  /// ```dart
  /// // 成功
  /// {
  ///   'code': 'CF6tNdXXXXX',
  ///   'state': 'random_state_123'
  /// }
  ///
  /// // 失败
  /// {
  ///   'error': 'access_denied',
  ///   'error_description': 'User denied authorization'
  /// }
  /// ```
  ///
  /// 使用示例：
  /// ```dart
  /// final params = helper.parseCallback(callbackUrl);
  ///
  /// if (params != null) {
  ///   if (params['code'] != null) {
  ///     // 授权成功，获取到授权码
  ///     final code = params['code']!;
  ///     final result = await helper.exchangeToken(code);
  ///   } else if (params['error'] != null) {
  ///     // 授权失败
  ///     final error = params['error']!;
  ///     final description = params['error_description'];
  ///     print('授权失败: $error - $description');
  ///   }
  /// }
  /// ```
  Map<String, String>? parseCallback(String callbackUrl) {
    debugPrint('[Response] ========================================');
    debugPrint('[Response] 步骤 1 响应: 接收授权回调 (包含 code)');
    debugPrint('[Response] ========================================');
    debugPrint('[Response] 回调方式: HTTP 302 重定向');
    debugPrint('[Response] 回调 URL: $callbackUrl');
    debugPrint('[Response] ========================================');

    try {
      final uri = Uri.parse(callbackUrl);

      // 检查是否有错误
      final error = uri.queryParameters['error'];
      if (error != null) {
        debugPrint('[Response] ❌ 授权失败');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 错误参数:');
        debugPrint('[Response]   error: $error');
        if (uri.queryParameters['error_description'] != null) {
          debugPrint('[Response]   error_description: ${uri.queryParameters['error_description']}');
        }
        debugPrint('[Response] ========================================');

        return {
          'error': error,
          if (uri.queryParameters['error_description'] != null)
            'error_description': uri.queryParameters['error_description']!,
        };
      }

      // 提取授权码
      final code = uri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        debugPrint('[Response] ❌ 回调中没有找到授权码');
        debugPrint('[Response] 可用参数: ${uri.queryParameters.keys.join(", ")}');
        debugPrint('[Response] ========================================');
        return null;
      }

      // 验证 state（防止 CSRF 攻击）
      final state = uri.queryParameters['state'];
      if (config.state != null && state != config.state) {
        debugPrint('[Response] ⚠️ State 不匹配，可能存在 CSRF 攻击');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] State 验证:');
        debugPrint('[Response]   期望值: ${config.state}');
        debugPrint('[Response]   实际值: $state');
        debugPrint('[Response] ========================================');

        return {
          'error': 'invalid_state',
          'error_description': 'State parameter mismatch',
        };
      }

      debugPrint('[Response] ✅ 成功获取授权码');
      debugPrint('[Response] ========================================');
      debugPrint('[Response] 回调参数:');
      debugPrint('[Response]   code: ${code.substring(0, 20)}... (长度: ${code.length})');
      debugPrint('[Response]   state: $state');
      // 打印所有其他参数
      uri.queryParameters.forEach((key, value) {
        if (key != 'code' && key != 'state') {
          debugPrint('[Response]   $key: $value');
        }
      });
      debugPrint('[Response] ========================================');
      debugPrint('[Response] 📌 下一步: 使用此 code 换取 access_token');
      debugPrint('[Response] ========================================');

      return {
        'code': code,
        if (state != null) 'state': state,
      };
    } catch (e) {
      debugPrint('[Response] ❌ 解析回调 URL 失败: $e');
      debugPrint('[Response] ========================================');
      return null;
    }
  }

  /// Step 4: 用授权码换取 Access Token
  ///
  /// 使用 PKCE 模式安全地将授权码换取为 Access Token。
  ///
  /// 参数：
  /// - [code]: 从回调 URL 中获取的授权码
  ///
  /// 返回：
  /// - [HuaweiOAuthResult]: 包含 access_token、refresh_token、id_token 等信息
  ///
  /// 使用示例：
  /// ```dart
  /// final result = await helper.exchangeToken(code);
  ///
  /// if (result.isSuccess) {
  ///   print('Access Token: ${result.accessToken}');
  ///   print('过期时间: ${result.expiresIn} 秒');
  ///
  ///   // 保存到您的存储系统
  ///   await myTokenStorage.save(result);
  /// } else {
  ///   print('换取 Token 失败: ${result.error}');
  ///   print('错误描述: ${result.errorDescription}');
  /// }
  /// ```
  Future<HuaweiOAuthResult> exchangeToken(String code) async {
    return await _authService.exchangeCodeForToken(code);
  }

  /// 刷新 Access Token
  ///
  /// ⚠️ 暂时禁用：华为官方 PKCE 模式刷新接口文档有问题，待后续修复
  ///
  /// 当 Access Token 过期时，使用 Refresh Token 获取新的 Access Token。
  ///
  /// 参数：
  /// - [refreshToken]: 之前获取的 refresh_token
  ///
  /// 返回：
  /// - [HuaweiOAuthResult]: 包含新的 access_token 等信息
  ///   - ⚠️ 如果返回了新的 refresh_token，请务必更新保存！
  ///
  /// 重要提示：
  /// 华为可能会在刷新时返回新的 refresh_token，请检查并更新：
  /// ```dart
  /// final result = await helper.refreshToken(oldRefreshToken);
  ///
  /// if (result.isSuccess) {
  ///   // 保存新的 access_token
  ///   await myTokenStorage.saveAccessToken(result.accessToken);
  ///
  ///   // ⚠️ 重要：检查是否有新的 refresh_token
  ///   if (result.refreshToken != null && result.refreshToken != oldRefreshToken) {
  ///     print('检测到新的 refresh_token，立即更新！');
  ///     await myTokenStorage.saveRefreshToken(result.refreshToken);
  ///   }
  /// }
  /// ```
  ///
  /// 使用示例：
  /// ```dart
  /// // 检查 Token 是否即将过期
  /// if (isTokenExpiringSoon()) {
  ///   final oldRefreshToken = await myTokenStorage.getRefreshToken();
  ///
  ///   final result = await helper.refreshToken(oldRefreshToken);
  ///
  ///   if (result.isSuccess) {
  ///     // 保存新的 Token
  ///     await myTokenStorage.save(result);
  ///   } else {
  ///     // 刷新失败，需要重新登录
  ///     await reLogin();
  ///   }
  /// }
  /// ```
  Future<HuaweiOAuthResult> refreshToken(String refreshToken) async {
    // TODO: 等华为官方接口文档修复后再启用
    return HuaweiOAuthResult(
      error: 'temporarily_disabled',
      errorDescription: '刷新功能暂时禁用（华为官方 PKCE 接口文档问题）',
    );

    /* 原始实现（已暂时禁用）
    return await _authService.refreshAccessToken(refreshToken);
    */
  }

  /// 解析 ID Token (JWT)
  ///
  /// ID Token 是 JWT 格式，包含用户的基本信息（如用户 ID、OpenID 等）。
  ///
  /// 参数：
  /// - [idToken]: 从 OAuth 结果中获取的 id_token
  ///
  /// 返回：
  /// - 成功时返回包含用户信息的 Map
  /// - 失败时返回 null
  ///
  /// 返回值示例：
  /// ```dart
  /// {
  ///   'sub': 'user_open_id_xxx',
  ///   'iss': 'https://oauth-login.cloud.huawei.com',
  ///   'aud': '108913819',
  ///   'exp': 1234567890,
  ///   'iat': 1234567890,
  /// }
  /// ```
  ///
  /// 使用示例：
  /// ```dart
  /// final result = await helper.exchangeToken(code);
  ///
  /// if (result.isSuccess && result.idToken != null) {
  ///   final userInfo = helper.parseIdToken(result.idToken!);
  ///
  ///   if (userInfo != null) {
  ///     final userId = userInfo['sub'];
  ///     print('用户 OpenID: $userId');
  ///   }
  /// }
  /// ```
  Map<String, dynamic>? parseIdToken(String idToken) {
    return _authService.parseIdToken(idToken);
  }

  /// 获取当前配置的 redirect URI
  ///
  /// 在配置 WebView 的导航监听时可能需要用到。
  String get redirectUri => config.redirectUri;

  /// 获取当前配置的 state 参数
  ///
  /// 用于验证回调参数，防止 CSRF 攻击。
  String? get state => config.state;

  /// 获取 PKCE code_verifier
  ///
  /// 仅供调试使用，正常情况下不需要访问此值。
  String get codeVerifier => config.codeVerifier;

  /// 获取 PKCE code_challenge
  ///
  /// 仅供调试使用，正常情况下不需要访问此值。
  String get codeChallenge => config.codeChallenge;
}

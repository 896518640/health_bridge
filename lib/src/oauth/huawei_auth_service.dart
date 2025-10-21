import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:health_bridge/src/oauth/huawei_oauth_config.dart';
import 'package:flutter/foundation.dart';

/// 华为授权服务 - 纯客户端 PKCE 模式
/// 直接与华为服务器交互，不需要自己的服务端
class HuaweiAuthService {
  /// 华为 OAuth Token 端点
  static const String tokenUrl = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';

  /// OAuth 配置（包含 code_verifier）
  final HuaweiOAuthConfig config;

  HuaweiAuthService({required this.config});

  /// 1. 用授权码换取 Access Token（PKCE 模式 - 直接调用华为服务器）
  Future<HuaweiOAuthResult> exchangeCodeForToken(String code) async {
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  步骤 2: 用授权码换取 Access Token (PKCE 模式)');
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  请求方式: POST');
    debugPrint('[Response]  请求 URL: $tokenUrl');
    debugPrint('[Response]  Content-Type: application/x-www-form-urlencoded');
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  请求参数:');
    debugPrint('[Response]    grant_type: authorization_code');
    debugPrint('[Response]    code: ${code.substring(0, 20)}... (长度: ${code.length})');
    debugPrint('[Response]    client_id: ${config.clientId}');
    debugPrint('[Response]    code_verifier: ${config.codeVerifier.substring(0, 20)}... (长度: ${config.codeVerifier.length})');
    debugPrint('[Response]    redirect_uri: ${config.redirectUri}');
    debugPrint('[Response]  ========================================');

    try {
      // 构建请求参数（PKCE 模式，不需要 client_secret）
      final requestBody = {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': config.clientId,
        'code_verifier': config.codeVerifier, // 使用 code_verifier 而不是 client_secret
        'redirect_uri': config.redirectUri,
      };

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      debugPrint('[Response] ========================================');
      debugPrint('[Response] 步骤 2 响应: Access Token 获取结果');
      debugPrint('[Response] ========================================');
      debugPrint('[Response] HTTP 状态码: ${response.statusCode}');
      debugPrint('[Response] ========================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        debugPrint('[Response] ✅ 成功获取 Access Token');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 完整响应体:');
        debugPrint('[Response] ${response.body}');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 解析后的数据:');
        data.forEach((key, value) {
          if (key == 'access_token' || key == 'refresh_token' || key == 'id_token') {
            // Token 只打印前 30 个字符
            final tokenPreview = value.toString().length > 30
                ? '${value.toString().substring(0, 30)}...'
                : value.toString();
            debugPrint('[Response]   $key: $tokenPreview (长度: ${value.toString().length})');
          } else {
            debugPrint('[Response]   $key: $value');
          }
        });
        debugPrint('[Response] ========================================');
        debugPrint('[Response] Token 信息汇总:');
        debugPrint('[Response]   access_token 存在: ${data['access_token'] != null}');
        debugPrint('[Response]   refresh_token 存在: ${data['refresh_token'] != null}');
        debugPrint('[Response]   id_token 存在: ${data['id_token'] != null}');
        debugPrint('[Response]   expires_in: ${data['expires_in']} 秒');
        debugPrint('[Response]   token_type: ${data['token_type']}');
        debugPrint('[Response]   scope: ${data['scope']}');
        debugPrint('[Response] ========================================');

        return HuaweiOAuthResult.fromJson(data);
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;

        debugPrint('[Response] ❌ 换取 Token 失败');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 错误响应体:');
        debugPrint('[Response] ${response.body}');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 错误详情:');
        debugPrint('[Response]   error: ${errorBody['error']}');
        debugPrint('[Response]   error_description: ${errorBody['error_description']}');
        debugPrint('[Response]   sub_error: ${errorBody['sub_error']}');
        debugPrint('[Response] ========================================');

        return HuaweiOAuthResult(
          error: errorBody['error']?.toString() ?? 'http_error',
          errorDescription: errorBody['error_description']?.toString() ?? '服务器返回错误: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[Response] ❌ 换取 Token 异常');
      debugPrint('[Response] 异常信息: $e');
      debugPrint('[Response] ========================================');

      return HuaweiOAuthResult(
        error: 'network_error',
        errorDescription: '网络请求失败: $e',
      );
    }
  }

  /// 2. 解析 ID Token (JWT)
  /// 可以从 ID Token 中提取用户信息
  Map<String, dynamic>? parseIdToken(String idToken) {
    try {
      // JWT 格式: header.payload.signature
      final parts = idToken.split('.');
      if (parts.length != 3) {
        debugPrint('[Auth PKCE] ❌ ID Token 格式错误');
        return null;
      }

      // 解码 payload（Base64URL）
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));

      final data = jsonDecode(decoded) as Map<String, dynamic>;
      debugPrint('[Auth PKCE] ✅ ID Token 解析成功');
      debugPrint('[Auth PKCE] 用户信息: ${data.keys.join(", ")}');

      return data;
    } catch (e) {
      debugPrint('[Auth PKCE] ❌ 解析 ID Token 失败: $e');
      return null;
    }
  }

  /// 3. 刷新 Access Token
  /// 使用 Refresh Token 获取新的 Access Token
  ///
  /// 重要说明：
  /// - PKCE 模式下刷新 token 需要 code_verifier（不是 client_secret）
  /// - 使用初始请求时生成的 code_verifier
  /// - 如果华为返回新的 refresh_token，请务必更新保存
  Future<HuaweiOAuthResult> refreshAccessToken(String refreshToken) async {
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  步骤 3: 刷新 Access Token (PKCE 模式)');
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  请求方式: POST');
    debugPrint('[Response]  请求 URL: $tokenUrl');
    debugPrint('[Response]  Content-Type: application/x-www-form-urlencoded');
    debugPrint('[Response]  ========================================');
    debugPrint('[Response]  请求参数:');
    debugPrint('[Response]    grant_type: refresh_token');
    debugPrint('[Response]    refresh_token: ${refreshToken.substring(0, 20)}... (长度: ${refreshToken.length})');
    debugPrint('[Response]    client_id: ${config.clientId}');
    debugPrint('[Response]    code_verifier: ${config.codeVerifier.substring(0, 20)}... (长度: ${config.codeVerifier.length})');
    debugPrint('[Response]  ========================================');

    try {
      // 构建刷新请求参数（PKCE 模式，需要 code_verifier）
      final requestBody = {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': config.clientId,
        'code_verifier': config.codeVerifier, // PKCE 必填
      };

      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      debugPrint('[Response] ========================================');
      debugPrint('[Response] 步骤 3 响应: Access Token 刷新结果');
      debugPrint('[Response] ========================================');
      debugPrint('[Response] HTTP 状态码: ${response.statusCode}');
      debugPrint('[Response] ========================================');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        debugPrint('[Response] ✅ 成功刷新 Access Token');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 完整响应体:');
        debugPrint('[Response] ${response.body}');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 解析后的数据:');
        data.forEach((key, value) {
          if (key == 'access_token' || key == 'refresh_token' || key == 'id_token') {
            // Token 只打印前 30 个字符
            final tokenPreview = value.toString().length > 30
                ? '${value.toString().substring(0, 30)}...'
                : value.toString();
            debugPrint('[Response]   $key: $tokenPreview (长度: ${value.toString().length})');
          } else {
            debugPrint('[Response]   $key: $value');
          }
        });
        debugPrint('[Response] ========================================');

        // ⚠️ 重要：检查 refresh_token 是否变化
        final newRefreshToken = data['refresh_token'] as String?;
        if (newRefreshToken != null && newRefreshToken != refreshToken) {
          debugPrint('[Response] 🔄 检测到新的 refresh_token！');
          debugPrint('[Response]   旧 RT: ${refreshToken.substring(0, 30)}...');
          debugPrint('[Response]   新 RT: ${newRefreshToken.substring(0, 30)}...');
          debugPrint('[Response]   ⚠️  请务必更新并保存新的 refresh_token！');
        } else if (newRefreshToken != null) {
          debugPrint('[Response] ✓ refresh_token 未变化');
        } else {
          debugPrint('[Response] ⚠️  响应中未包含 refresh_token');
        }

        debugPrint('[Response] ========================================');
        debugPrint('[Response] Token 信息汇总:');
        debugPrint('[Response]   access_token 存在: ${data['access_token'] != null}');
        debugPrint('[Response]   refresh_token 存在: ${newRefreshToken != null}');
        debugPrint('[Response]   expires_in: ${data['expires_in']} 秒');
        debugPrint('[Response] ========================================');

        return HuaweiOAuthResult.fromJson(data);
      } else {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;

        debugPrint('[Response] ❌ 刷新 Token 失败');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 错误响应体:');
        debugPrint('[Response] ${response.body}');
        debugPrint('[Response] ========================================');
        debugPrint('[Response] 错误详情:');
        debugPrint('[Response]   error: ${errorBody['error']}');
        debugPrint('[Response]   error_description: ${errorBody['error_description']}');
        debugPrint('[Response]   sub_error: ${errorBody['sub_error']}');
        debugPrint('[Response] ========================================');

        return HuaweiOAuthResult(
          error: errorBody['error']?.toString() ?? 'http_error',
          errorDescription: errorBody['error_description']?.toString() ?? '服务器返回错误: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[Response] ❌ 刷新 Token 异常');
      debugPrint('[Response] 异常信息: $e');
      debugPrint('[Response] ========================================');

      return HuaweiOAuthResult(
        error: 'network_error',
        errorDescription: '网络请求失败: $e',
      );
    }
  }

  /// 4. 验证授权码回调
  /// 从回调 URL 中提取 code 和 state
  static Map<String, String>? parseCallbackUrl(String url, String? expectedState) {
    try {
      final uri = Uri.parse(url);

      // 检查是否有错误
      final error = uri.queryParameters['error'];
      if (error != null) {
        debugPrint('[Auth PKCE] ❌ 授权错误: $error');
        debugPrint('[Auth PKCE] 错误描述: ${uri.queryParameters['error_description']}');
        return null;
      }

      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];

      if (code == null || code.isEmpty) {
        debugPrint('[Auth PKCE] ❌ 回调URL中没有授权码');
        return null;
      }

      // 验证 state（防止 CSRF 攻击）
      if (expectedState != null && state != expectedState) {
        debugPrint('[Auth PKCE] ❌ State 不匹配，可能存在 CSRF 攻击');
        return null;
      }

      debugPrint('[Auth PKCE] ✅ 成功提取授权码');
      return {
        'code': code,
        if (state != null) 'state': state,
      };
    } catch (e) {
      debugPrint('[Auth PKCE] ❌ 解析回调URL失败: $e');
      return null;
    }
  }
}


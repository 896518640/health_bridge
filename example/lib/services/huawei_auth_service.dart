import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:health_bridge/src/oauth/huawei_oauth_config.dart';

/// 华为授权服务 - 纯客户端 PKCE 模式
/// 直接与华为服务器交互，不需要自己的服务端
class HuaweiAuthService {
  /// 华为 OAuth Token 端点
  static const String tokenUrl = 'https://oauth-login.cloud.huawei.com/oauth2/v3/token';
  
  /// OAuth 配置（包含 code_verifier）
  final HuaweiOAuthConfig config;

  /// Dio HTTP 客户端（跨平台兼容）
  late final Dio _dio;

  HuaweiAuthService({required this.config}) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    ));
  }

  /// 1. 用授权码换取 Access Token（PKCE 模式 - 直接调用华为服务器）
  Future<HuaweiOAuthResult> exchangeCodeForToken(String code) async {
    print('[Auth PKCE] ========================================');
    print('[Auth PKCE] 正在用授权码换取 Access Token...');
    print('[Auth PKCE] Code: ${code.substring(0, 20)}...');
    print('[Auth PKCE] code_verifier: ${config.codeVerifier.substring(0, 20)}...');
    print('[Auth PKCE] ========================================');

    try {
      // 构建请求参数（PKCE 模式，不需要 client_secret）
      final requestBody = {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': config.clientId,
        'code_verifier': config.codeVerifier, // 使用 code_verifier 而不是 client_secret
        'redirect_uri': config.redirectUri,
      };

      print('[Auth PKCE] 请求参数: ${requestBody.keys.join(", ")}');

      final response = await _dio.post(
        tokenUrl,
        data: requestBody,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      print('[Auth PKCE] 响应状态码: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        print('[Auth PKCE] ✅ 成功获取 Access Token');
        print('[Auth PKCE] expires_in: ${data['expires_in']} 秒');
        print('[Auth PKCE] scope: ${data['scope']}');
        
        return HuaweiOAuthResult.fromJson(data);
      } else {
        final errorBody = response.data;
        print('[Auth PKCE] ❌ 换取Token失败: $errorBody');
        
        return HuaweiOAuthResult(
          error: errorBody['error']?.toString() ?? 'http_error',
          errorDescription: errorBody['error_description']?.toString() ?? '服务器返回错误: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      print('[Auth PKCE] ❌ Dio异常: ${e.type}');
      print('[Auth PKCE] 错误消息: ${e.message}');
      
      if (e.response != null) {
        print('[Auth PKCE] 响应数据: ${e.response?.data}');
        final errorData = e.response?.data;
        return HuaweiOAuthResult(
          error: errorData?['error']?.toString() ?? 'http_error',
          errorDescription: errorData?['error_description']?.toString() ?? e.message,
        );
      }
      
      return HuaweiOAuthResult(
        error: 'network_error',
        errorDescription: '网络请求失败: ${e.message}',
      );
    } catch (e) {
      print('[Auth PKCE] ❌ 换取Token异常: $e');
      return HuaweiOAuthResult(
        error: 'unknown_error',
        errorDescription: '未知错误: $e',
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
        print('[Auth PKCE] ❌ ID Token 格式错误');
        return null;
      }

      // 解码 payload（Base64URL）
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      print('[Auth PKCE] ✅ ID Token 解析成功');
      print('[Auth PKCE] 用户信息: ${data.keys.join(", ")}');
      
      return data;
    } catch (e) {
      print('[Auth PKCE] ❌ 解析 ID Token 失败: $e');
      return null;
    }
  }

  /// 3. 验证授权码回调
  /// 从回调 URL 中提取 code 和 state
  static Map<String, String>? parseCallbackUrl(String url, String? expectedState) {
    try {
      final uri = Uri.parse(url);
      
      // 检查是否有错误
      final error = uri.queryParameters['error'];
      if (error != null) {
        print('[Auth PKCE] ❌ 授权错误: $error');
        print('[Auth PKCE] 错误描述: ${uri.queryParameters['error_description']}');
        return null;
      }

      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];

      if (code == null || code.isEmpty) {
        print('[Auth PKCE] ❌ 回调URL中没有授权码');
        return null;
      }

      // 验证 state（防止 CSRF 攻击）
      if (expectedState != null && state != expectedState) {
        print('[Auth PKCE] ❌ State 不匹配，可能存在 CSRF 攻击');
        return null;
      }

      print('[Auth PKCE] ✅ 成功提取授权码');
      return {
        'code': code,
        if (state != null) 'state': state,
      };
    } catch (e) {
      print('[Auth PKCE] ❌ 解析回调URL失败: $e');
      return null;
    }
  }
}


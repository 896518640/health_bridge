import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// 华为 OAuth 配置（支持 PKCE 模式）
class HuaweiOAuthConfig {
  /// 客户端 ID（App ID）
  final String clientId;

  /// 回调地址（redirect_uri）
  final String redirectUri;

  /// 权限范围（必须包含 "openid"）
  final List<String> scopes;

  /// 随机字符串，用于防 CSRF 攻击
  final String? state;

  /// 授权页面展示风格（touch: 移动端, page: PC端）
  final String display;

  /// 随机值，用于防重放攻击
  final String? nonce;

  /// PKCE code_verifier (由系统自动生成)
  late final String codeVerifier;

  /// PKCE code_challenge (由 code_verifier 计算得出)
  late final String codeChallenge;

  /// PKCE 编码方法 (S256 或 plain，推荐 S256)
  final String codeChallengeMethod;

  /// 访问类型 (offline: 返回 refresh_token, online: 不返回)
  /// 默认 'offline' 以获取 refresh_token
  final String accessType;

  HuaweiOAuthConfig({
    required this.clientId,
    required this.redirectUri,
    required this.scopes,
    this.state,
    this.display = 'touch',
    this.nonce,
    this.codeChallengeMethod = 'S256',
    this.accessType = 'offline',
    String? codeVerifier,
  }) {
    // 如果没有提供 code_verifier，自动生成
    this.codeVerifier = codeVerifier ?? _generateCodeVerifier();
    
    // 根据 code_verifier 计算 code_challenge
    this.codeChallenge = _generateCodeChallenge(this.codeVerifier);
  }

  /// 生成 code_verifier (随机字符串)
  /// 规范：43-128 个字符，[A-Z][a-z][0-9]-._~ 
  static String _generateCodeVerifier() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    final length = 128; // 使用最大长度以提高安全性
    
    return List.generate(length, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// 生成 code_challenge
  /// S256: BASE64URL(SHA256(ASCII(code_verifier)))
  /// plain: code_verifier
  String _generateCodeChallenge(String verifier) {
    if (codeChallengeMethod == 'plain') {
      return verifier;
    }
    
    // S256 方法
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    
    // Base64 URL 编码（去除 padding）
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// 验证配置有效性
  void validate() {
    if (clientId.isEmpty) {
      throw ArgumentError('clientId 不能为空');
    }
    if (redirectUri.isEmpty) {
      throw ArgumentError('redirectUri 不能为空');
    }
    if (!scopes.contains('openid')) {
      throw ArgumentError('scopes 必须包含 "openid"');
    }
  }

  /// 生成授权 URL（PKCE 模式）
  String buildAuthorizeUrl() {
    validate();

    final params = <String, String>{
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'display': display,
      // PKCE 参数
      'code_challenge': codeChallenge,
      'code_challenge_method': codeChallengeMethod,
    };

    if (state != null && state!.isNotEmpty) {
      params['state'] = state!;
    }

    if (nonce != null && nonce!.isNotEmpty) {
      params['nonce'] = nonce!;
    }

    // 添加 access_type 参数以获取 refresh_token
    if (accessType.isNotEmpty) {
      params['access_type'] = accessType;
    }

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return 'https://oauth-login.cloud.huawei.com/oauth2/v3/authorize?$queryString';
  }

  @override
  String toString() {
    return 'HuaweiOAuthConfig(clientId: $clientId, redirectUri: $redirectUri, scopes: $scopes)';
  }
}

/// OAuth 授权结果
class HuaweiOAuthResult {
  /// 访问令牌
  final String? accessToken;

  /// ID Token (JWT 格式)
  final String? idToken;

  /// 刷新令牌
  final String? refreshToken;

  /// 过期时间（秒）
  final int? expiresIn;

  /// 授权的权限范围
  final String? scope;

  /// 令牌类型（通常是 "Bearer"）
  final String? tokenType;

  /// 错误码
  final String? error;

  /// 错误描述
  final String? errorDescription;

  const HuaweiOAuthResult({
    this.accessToken,
    this.idToken,
    this.refreshToken,
    this.expiresIn,
    this.scope,
    this.tokenType,
    this.error,
    this.errorDescription,
  });

  bool get isSuccess => accessToken != null && error == null;
  bool get hasError => error != null;

  factory HuaweiOAuthResult.fromJson(Map<String, dynamic> json) {
    return HuaweiOAuthResult(
      accessToken: json['access_token'] as String?,
      idToken: json['id_token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: json['expires_in'] as int?,
      scope: json['scope'] as String?,
      tokenType: json['token_type'] as String?,
      error: json['error'] as String?,
      errorDescription: json['error_description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (accessToken != null) 'access_token': accessToken,
      if (idToken != null) 'id_token': idToken,
      if (refreshToken != null) 'refresh_token': refreshToken,
      if (expiresIn != null) 'expires_in': expiresIn,
      if (scope != null) 'scope': scope,
      if (tokenType != null) 'token_type': tokenType,
      if (error != null) 'error': error,
      if (errorDescription != null) 'error_description': errorDescription,
    };
  }

  @override
  String toString() {
    if (hasError) {
      return 'HuaweiOAuthResult(error: $error, description: $errorDescription)';
    }
    return 'HuaweiOAuthResult(accessToken: ${accessToken?.substring(0, 20)}..., expiresIn: $expiresIn)';
  }
}

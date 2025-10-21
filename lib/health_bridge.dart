library health_bridge;

export 'src/health_bridge.dart'; // 主要API
export 'src/models/health_data.dart'; // 健康数据模型
export 'src/models/health_platform.dart'; // 健康平台枚举
export 'src/health_bridge_platform_interface.dart'; // 平台接口抽象基类
export 'src/health_bridge_method_channel.dart'; // 方法通道实现

// OAuth 相关导出（Layer 2 半托管 API - 推荐）
export 'src/oauth/huawei_oauth_helper.dart'; // OAuth 辅助类（半托管，推荐）
export 'src/oauth/huawei_oauth_config.dart'; // OAuth 配置类
export 'src/oauth/huawei_auth_service.dart'; // OAuth 认证服务（可选，高级用户使用）

// Cloud API 相关导出（云侧数据访问）
export 'src/cloud/huawei_cloud_client.dart'; // 华为健康云侧API客户端
export 'src/cloud/huawei_cloud_models.dart'; // 云侧API数据模型（包含授权管理模型）
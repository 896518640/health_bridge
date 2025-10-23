import webview from '@ohos.web.webview';
import router from '@ohos.router';

/**
 * 华为 OAuth WebView 页面
 * 用于在 WebView 中完成华为账号授权，拦截回调 URL 获取 code
 */
@Entry
@Component
struct HuaweiOAuthWebViewPage {
  private webController: webview.WebviewController = new webview.WebviewController();
  @State authUrl: string = '';
  @State redirectUri: string = '';
  @State isLoading: boolean = true;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    console.info('[HuaweiOAuth] ========== aboutToAppear 被调用 ==========');
    
    // 使用新的 API 获取路由参数
    try {
      const params = router.getParams();
      console.info('[HuaweiOAuth] 获取到的参数: ' + JSON.stringify(params));
      
      if (params) {
        this.authUrl = (params as Record<string, Object>)['authUrl'] as string || '';
        this.redirectUri = (params as Record<string, Object>)['redirectUri'] as string || '';
      }
    } catch (error) {
      console.error('[HuaweiOAuth] 获取参数失败: ' + error);
    }

    console.info('[HuaweiOAuth] ========== 开始 OAuth 流程 ==========');
    console.info('[HuaweiOAuth] authUrl: ' + this.authUrl);
    console.info('[HuaweiOAuth] authUrl 长度: ' + this.authUrl.length);
    console.info('[HuaweiOAuth] redirectUri: ' + this.redirectUri);
    console.info('[HuaweiOAuth] 时间戳: ' + new Date().toISOString());

    if (!this.authUrl) {
      this.errorMessage = '授权 URL 为空';
      this.isLoading = false;
      console.error('[HuaweiOAuth] 错误: 授权 URL 为空');
    } else {
      console.info('[HuaweiOAuth] ✅ URL 验证通过，准备加载 WebView');
    }
  }

  // 解析 URL 中的查询参数
  private parseUrlParams(url: string): Record<string, string> {
    const params: Record<string, string> = {};
    try {
      const questionMarkIndex = url.indexOf('?');
      if (questionMarkIndex === -1) {
        return params;
      }

      const queryString = url.substring(questionMarkIndex + 1);
      const pairs = queryString.split('&');

      for (const pair of pairs) {
        const parts = pair.split('=');
        const key = parts[0];
        const value = parts.length > 1 ? parts[1] : '';
        if (key) {
          params[decodeURIComponent(key)] = value ? decodeURIComponent(value) : '';
        }
      }
    } catch (error) {
      console.error('[HuaweiOAuth] 解析 URL 参数失败: ' + error);
    }
    return params;
  }

  // 返回结果给 Flutter
  private returnResult(code?: string, state?: string, error?: string, errorDescription?: string) {
    const result: Record<string, string> = {};

    if (code) {
      result['code'] = code;
      console.info('[HuaweiOAuth] 成功获取 code: ' + code);
    }
    if (state) {
      result['state'] = state;
    }
    if (error) {
      result['error'] = error;
      console.error('[HuaweiOAuth] 授权失败: ' + error);
    }
    if (errorDescription) {
      result['error_description'] = errorDescription;
    }

    // 注意：当前华为运动健康使用云端API，不通过原生代码交互
    // OAuth 结果应该通过 Flutter 的 WebView 回调处理
    console.info('[HuaweiOAuth] OAuth 结果: ' + JSON.stringify(result));

    // 关闭当前页面
    router.back();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(24)
            .height(24)
            .fillColor(Color.White)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          console.log('[HuaweiOAuth] 用户点击返回按钮');
          // 用户取消授权
          this.returnResult(undefined, undefined, 'user_cancelled', '用户取消授权');
        })

        Text('华为账号授权 [DEBUG]')
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .margin({ right: 40 }) // 为了居中，抵消左侧按钮的宽度
      }
      .width('100%')
      .height(56)
      .backgroundColor('#FF6200')
      .padding({ left: 8, right: 8 })

      // 调试信息区域
      Column() {
        Text('=== 调试信息 ===')
          .fontSize(12)
          .fontColor('#FF0000')
          .margin({ top: 10 })
        
        Text('authUrl 长度: ' + this.authUrl.length.toString())
          .fontSize(10)
          .fontColor('#333333')
        
        Text('authUrl 前缀: ' + (this.authUrl.length > 0 ? this.authUrl.substring(0, Math.min(50, this.authUrl.length)) : '空'))
          .fontSize(10)
          .fontColor('#333333')
          .margin({ top: 5 })
        
        Text('redirectUri 长度: ' + this.redirectUri.length.toString())
          .fontSize(10)
          .fontColor('#333333')
          .margin({ top: 5 })
        
        Text('isLoading: ' + (this.isLoading ? '是' : '否'))
          .fontSize(10)
          .fontColor('#333333')
          .margin({ top: 5 })
        
        if (this.errorMessage) {
          Text('错误: ' + this.errorMessage)
            .fontSize(10)
            .fontColor('#FF0000')
            .margin({ top: 5 })
        }
      }
      .width('100%')
      .padding(10)
      .backgroundColor('#FFFFCC')
      
      // 加载指示器
      if (this.isLoading && !this.errorMessage) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#FF6200')
          Text('加载中...')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }

      // 错误信息
      if (this.errorMessage) {
        Column() {
          Text('⚠️')
            .fontSize(48)
          Text(this.errorMessage)
            .fontSize(16)
            .fontColor('#FF0000')
            .margin({ top: 16 })
          Button('返回')
            .margin({ top: 24 })
            .onClick(() => {
              this.returnResult(undefined, undefined, 'error', this.errorMessage);
            })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // WebView
      if (this.authUrl && !this.errorMessage) {
        Web({
          src: this.authUrl,
          controller: this.webController
        })
          .width('100%')
          .layoutWeight(1)
          .javaScriptAccess(true) // 启用 JavaScript
          .domStorageAccess(true) // 启用 DOM 存储
          .fileAccess(true) // 启用文件访问
          .imageAccess(true) // 启用图片访问
          .onlineImageAccess(true) // 启用在线图片访问
          .zoomAccess(true) // 启用缩放
          .mixedMode(MixedMode.All) // 允许混合内容
          .cacheMode(CacheMode.Default) // 缓存模式
          .onControllerAttached(() => {
            console.info('[HuaweiOAuth] ========================================');
            console.info('[HuaweiOAuth] WebView Controller 已附加');
            console.info('[HuaweiOAuth] 开始加载授权页面...');
            console.info('[HuaweiOAuth] ========================================');
          })
          .onPageBegin((event) => {
            const url = event?.url || '';
            console.info('[HuaweiOAuth] ========================================');
            console.info('[HuaweiOAuth] >>> 页面开始加载');
            console.info('[HuaweiOAuth] URL: ' + url);
            console.info('[HuaweiOAuth] 时间: ' + new Date().toLocaleTimeString());
            console.info('[HuaweiOAuth] ========================================');

            // 检查是否是 redirect_uri
            if (url.startsWith(this.redirectUri)) {
              console.info('[HuaweiOAuth] !!! 检测到回调 URL: ' + url);

              // 停止加载
              this.webController.stop();

              // 解析 URL 参数
              const params = this.parseUrlParams(url);
              console.info('[HuaweiOAuth] 解析到的参数: ' + JSON.stringify(params));

              // 提取 code、state 或错误信息
              const code = params['code'];
              const state = params['state'];
              const error = params['error'];
              const errorDescription = params['error_description'];

              // 返回结果
              this.returnResult(code, state, error, errorDescription);

              return true; // 拦截导航
            }

            return false;
          })
          .onPageEnd((event) => {
            this.isLoading = false;
            const url = event?.url || '';
            console.info('[HuaweiOAuth] ========================================');
            console.info('[HuaweiOAuth] <<< 页面加载完成');
            console.info('[HuaweiOAuth] URL: ' + url);
            console.info('[HuaweiOAuth] 加载状态已更新为: 完成');
            console.info('[HuaweiOAuth] ========================================');
          })
          .onProgressChange((event) => {
            const progress = event?.newProgress || 0;
            if (progress % 20 === 0 || progress === 100) {
              console.info('[HuaweiOAuth] ⏳ 加载进度: ' + progress + '%');
            }
          })
          .onErrorReceive((event) => {
            this.isLoading = false;
            const errorInfo = event?.error?.getErrorInfo() || '未知错误';
            const errorCode = event?.error?.getErrorCode() || -1;
            const url = event?.request?.getRequestUrl() || '未知 URL';
            this.errorMessage = `加载失败 (${errorCode}): ${errorInfo}`;
            
            console.error('[HuaweiOAuth] ========================================');
            console.error('[HuaweiOAuth] !!! 页面加载错误 !!!');
            console.error('[HuaweiOAuth] 错误码: ' + errorCode);
            console.error('[HuaweiOAuth] 错误信息: ' + errorInfo);
            console.error('[HuaweiOAuth] 请求 URL: ' + url);
            console.error('[HuaweiOAuth] 时间: ' + new Date().toLocaleTimeString());
            console.error('[HuaweiOAuth] ========================================');
          })
          .onHttpErrorReceive((event) => {
            const statusCode = event?.response?.getResponseCode() || 0;
            const url = event?.request?.getRequestUrl() || '';
            const method = event?.request?.getRequestMethod() || '';
            
            console.warn('[HuaweiOAuth] ========================================');
            console.warn('[HuaweiOAuth] ⚠️  HTTP 错误');
            console.warn('[HuaweiOAuth] 状态码: ' + statusCode);
            console.warn('[HuaweiOAuth] 请求方法: ' + method);
            console.warn('[HuaweiOAuth] URL: ' + url);
            console.warn('[HuaweiOAuth] ========================================');
          })
          .onSslErrorEventReceive((event) => {
            const error = event?.error || -1;
            
            console.warn('[HuaweiOAuth] ========================================');
            console.warn('[HuaweiOAuth] ⚠️  SSL 证书错误');
            console.warn('[HuaweiOAuth] 错误码: ' + error);
            console.warn('[HuaweiOAuth] 操作: 忽略错误继续加载（仅开发环境）');
            console.warn('[HuaweiOAuth] ========================================');
            
            // 开发环境继续加载，生产环境应该严格处理
            event?.handler?.handleConfirm();
          })
          .onConsole((event) => {
            const message = event?.message?.getMessage() || '';
            if (message) {
              console.info('[HuaweiOAuth] [WebView Console] ' + message);
            }
            return false;
          })
          .onResourceLoad((event) => {
            const url = event?.url || '';
            // 只记录主要资源，避免日志过多
            if (url.includes('oauth') || url.includes('huawei') || url.includes('authorize')) {
              console.info('[HuaweiOAuth] 📥 加载资源: ' + url);
            }
          })
          .onLoadIntercept((event) => {
            const url = event?.data?.getRequestUrl() || '';
            console.info('[HuaweiOAuth] 🔍 拦截检查: ' + url);
            
            // 检查是否是回调 URL
            if (url.startsWith(this.redirectUri)) {
              console.info('[HuaweiOAuth] !!! 拦截到回调 URL，准备处理');
            }
            
            return false; // 不拦截，让 WebView 正常加载
          })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}

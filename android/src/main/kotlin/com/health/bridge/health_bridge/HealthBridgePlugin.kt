package com.health.bridge.health_bridge

import android.app.Activity
import android.content.Context
import kotlinx.coroutines.*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

import com.health.bridge.health_bridge.services.HealthBridgeService

/**
 * HealthBridge插件 - 符合SOLID原则的重构版本
 * 
 * 职责：
 * 1. Flutter插件生命周期管理
 * 2. 方法调用路由
 * 3. 协程管理
 * 
 * 业务逻辑委托给：
 * - HealthBridgeService（业务逻辑层）
 * - HealthDataProvider（数据提供层）
 * - ResponseBuilder（响应构建层）
 */
class HealthBridgePlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    private lateinit var healthBridgeService: HealthBridgeService
    
    companion object {
        private const val CHANNEL_NAME = "health_bridge"
    }
    
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
        healthBridgeService = HealthBridgeService(context)
    }
    
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "getAvailableHealthPlatforms" -> {
                handleGetAvailableHealthPlatforms(result)
            }
            "initializeHealthPlatform" -> {
                handleInitializeHealthPlatform(call, result)
            }
            "readStepCount" -> {
                handleReadStepCount(call, result)
            }
            "disconnect" -> {
                handleDisconnect(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * 获取可用健康平台
     */
    private fun handleGetAvailableHealthPlatforms(result: Result) {
        val platforms = healthBridgeService.getAvailableHealthPlatforms()
        result.success(platforms)
    }
    
    /**
     * 初始化健康平台
     */
    private fun handleInitializeHealthPlatform(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        
        coroutineScope.launch {
            try {
                val response = healthBridgeService.initializeHealthPlatform(platform)
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf(
                    "status" to "error",
                    "platform" to platform,
                    "message" to e.message
                ))
            }
        }
    }
    
    /**
     * 读取步数数据 - 统一入口
     */
    private fun handleReadStepCount(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val startDateMillis = call.argument<Long>("startDate")
        val endDateMillis = call.argument<Long>("endDate")
        
        coroutineScope.launch {
            try {
                val response = healthBridgeService.readStepCount(
                    platform, 
                    startDateMillis, 
                    endDateMillis
                )
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf(
                    "status" to "error",
                    "platform" to platform,
                    "message" to e.message
                ))
            }
        }
    }
    
    /**
     * 断开连接
     */
    private fun handleDisconnect(result: Result) {
        try {
            healthBridgeService.disconnect()
            result.success(null)
        } catch (e: Exception) {
            result.success(null)
        }
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        coroutineScope.cancel()
    }
    
    // ActivityAware 实现
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }
    
    override fun onDetachedFromActivity() {
        activity = null
    }
}
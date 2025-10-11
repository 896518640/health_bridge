package com.health.bridge.health_bridge

import android.app.Activity
import android.content.Context
import android.util.Log
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
        private const val TAG = "HealthBridgePlugin"
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
            // ----------新增方法----------
            "checkPermissions" -> {
                handleCheckPermissions(call, result)
            }
            "requestPermissions" -> {
                handleRequestPermissions(call, result)
            }
            "revokeAllAuthorizations" -> {
                handleRevokeAllAuthorizations(call, result)
            }
            "revokeAuthorizations" -> {
                handleRevokeAuthorizations(call, result)
            }
            "getSupportedDataTypes" -> {
                handleGetSupportedDataTypes(call, result)
            }
            "isDataTypeSupported" -> {
                handleIsDataTypeSupported(call, result)
            }
            "getPlatformCapabilities" -> {
                handleGetPlatformCapabilities(call, result)
            }
            "readHealthData" -> {
                handleReadHealthData(call, result)
            }
            "writeHealthData" -> {
                handleWriteHealthData(call, result)
            }
            "writeBatchHealthData" -> {
                handleWriteBatchHealthData(call, result)
            }
            // ----------新增方法 END----------
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
     * 检查权限
     */
    private fun handleCheckPermissions(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val dataTypes = call.argument<List<String>>("dataTypes") ?: emptyList()
        val operation = call.argument<String>("operation") ?: "read"

        coroutineScope.launch {
            try {
                val response = healthBridgeService.checkPermissions(platform, dataTypes, operation)
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf<String, Any>())
            }
        }
    }

    /**
     * 申请权限
     */
    private fun handleRequestPermissions(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val dataTypes = call.argument<List<String>>("dataTypes") ?: emptyList()
        val operations = call.argument<List<String>>("operations") ?: listOf("read")
        val reason = call.argument<String>("reason")

        coroutineScope.launch {
            try {
                val response = healthBridgeService.requestPermissions(
                    platform, dataTypes, operations, reason
                )
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf(
                    "status" to "error",
                    "message" to (e.message ?: "Unknown error")
                ))
            }
        }
    }

    /**
     * 取消全部授权
     */
    private fun handleRevokeAllAuthorizations(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"

        coroutineScope.launch {
            try {
                val response = healthBridgeService.revokeAllAuthorizations(platform)
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf(
                    "status" to "error",
                    "message" to (e.message ?: "Unknown error")
                ))
            }
        }
    }

    /**
     * 取消部分授权
     */
    private fun handleRevokeAuthorizations(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val dataTypes = call.argument<List<String>>("dataTypes") ?: emptyList()
        val operations = call.argument<List<String>>("operations") ?: listOf("read")

        coroutineScope.launch {
            try {
                val response = healthBridgeService.revokeAuthorizations(
                    platform, dataTypes, operations
                )
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf(
                    "status" to "error",
                    "message" to (e.message ?: "Unknown error")
                ))
            }
        }
    }

    /**
     * 获取支持的数据类型
     */
    private fun handleGetSupportedDataTypes(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val operation = call.argument<String>("operation")

        val supportedTypes = healthBridgeService.getSupportedDataTypes(platform, operation)
        result.success(supportedTypes)
    }

    /**
     * 检查是否支持某个数据类型
     */
    private fun handleIsDataTypeSupported(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val dataType = call.argument<String>("dataType") ?: ""
        val operation = call.argument<String>("operation") ?: "read"

        val supported = healthBridgeService.isDataTypeSupported(platform, dataType, operation)
        result.success(supported)
    }

    /**
     * 获取平台能力
     */
    private fun handleGetPlatformCapabilities(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"

        val capabilities = healthBridgeService.getPlatformCapabilities(platform)
        result.success(capabilities)
    }

    /**
     * 读取健康数据
     */
    private fun handleReadHealthData(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val dataType = call.argument<String>("dataType") ?: ""

        // 安全地从 Number 转换为 Long（Dart int 可能传递为 Double）
        val startDateMillis = call.argument<Number>("startDate")?.toLong()
        val endDateMillis = call.argument<Number>("endDate")?.toLong()
        val limit = call.argument<Number>("limit")?.toInt()

        Log.d(TAG, "📖 Reading health data: platform=$platform, dataType=$dataType, " +
                "startDate=$startDateMillis, endDate=$endDateMillis, limit=$limit")

        coroutineScope.launch {
            try {
                val response = healthBridgeService.readHealthData(
                    platform, dataType, startDateMillis, endDateMillis, limit
                )
                Log.d(TAG, "✅ Read health data success: ${response["status"]}, count=${response["count"]}")
                result.success(response)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Read health data failed", e)
                result.success(mapOf(
                    "status" to "error",
                    "message" to (e.message ?: "Unknown error"),
                    "data" to emptyList<Any>()
                ))
            }
        }
    }

    /**
     * 写入健康数据
     */
    private fun handleWriteHealthData(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val dataMap = call.argument<Map<String, Any>>("data") ?: emptyMap()

        coroutineScope.launch {
            try {
                val response = healthBridgeService.writeHealthData(platform, dataMap)
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf(
                    "status" to "error",
                    "message" to (e.message ?: "Unknown error")
                ))
            }
        }
    }

    /**
     * 批量写入健康数据
     */
    private fun handleWriteBatchHealthData(call: MethodCall, result: Result) {
        val platform = call.argument<String>("platform") ?: "samsung_health"
        val dataList = call.argument<List<Map<String, Any>>>("dataList") ?: emptyList()

        coroutineScope.launch {
            try {
                val response = healthBridgeService.writeBatchHealthData(platform, dataList)
                result.success(response)
            } catch (e: Exception) {
                result.success(mapOf(
                    "status" to "error",
                    "message" to (e.message ?: "Unknown error")
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
        healthBridgeService.setActivity(activity)
    }
    
    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        healthBridgeService.setActivity(null)
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        healthBridgeService.setActivity(activity)
    }
    
    override fun onDetachedFromActivity() {
        activity = null
        healthBridgeService.setActivity(null)
    }
}
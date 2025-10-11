package com.health.bridge.health_bridge.services

import android.app.Activity
import android.content.Context
import android.util.Log
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import com.health.bridge.health_bridge.utils.TimeCompat
import io.flutter.plugin.common.MethodChannel.Result

import com.health.bridge.health_bridge.providers.HealthProviderFactory
import com.health.bridge.health_bridge.providers.HealthDataProvider
import com.health.bridge.health_bridge.utils.ResponseBuilder

/**
 * 健康桥梁服务 - 服务层
 * 负责业务逻辑的处理和协调
 */
class HealthBridgeService(context: Context) {
    
    private val providerFactory = HealthProviderFactory(context)
    private val activeProviders = mutableMapOf<String, HealthDataProvider>()
    private var activity: Activity? = null
    
    companion object {
        private const val TAG = "HealthBridgeService"
    }
    
    /**
     * 设置Activity实例
     */
    fun setActivity(activity: Activity?) {
        this.activity = activity
        providerFactory.setActivity(activity)
        // 更新已存在的提供者
        activeProviders.values.forEach { provider ->
            if (provider is com.health.bridge.health_bridge.providers.SamsungHealthProvider) {
                provider.setActivity(activity)
            }
        }
    }
    
    /**
     * 获取可用的健康平台
     */
    fun getAvailableHealthPlatforms(): List<String> {
        return try {
            providerFactory.getAvailablePlatforms()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting available platforms", e)
            emptyList()
        }
    }
    
    /**
     * 初始化健康平台
     */
    suspend fun initializeHealthPlatform(platform: String): Map<String, Any> = withContext(Dispatchers.IO) {
        try {
            val provider = getOrCreateProvider(platform)
                ?: return@withContext ResponseBuilder.buildPlatformNotSupportedResponse(platform)
            
            val success = provider.initialize()
            if (success) {
                Log.d(TAG, "Platform $platform initialized successfully")
                mapOf(
                    "status" to "connected",
                    "platform" to platform,
                    "message" to "Platform initialized successfully",
                    "hasPermissions" to true
                )
            } else {
                ResponseBuilder.buildErrorResponse(
                    platform,
                    "Failed to initialize platform",
                    "initialization_failed"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error initializing platform $platform", e)
            ResponseBuilder.buildErrorResponse(platform, e.message ?: "Unknown error")
        }
    }
    
    /**
     * 读取步数数据 - 统一入口
     */
    suspend fun readStepCount(
        platform: String,
        startDateMillis: Long?,
        endDateMillis: Long?
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        try {
            val provider = getOrCreateProvider(platform)
                ?: return@withContext ResponseBuilder.buildPlatformNotSupportedResponse(platform)
            
            val result = when {
                // 今日查询
                startDateMillis == null && endDateMillis == null -> {
                    Log.d(TAG, "Reading today's step count for $platform")
                    provider.readTodayStepCount()
                }
                // 指定日期查询
                startDateMillis != null && endDateMillis == null -> {
                    val date = TimeCompat.millisToLocalDate(startDateMillis)
                    Log.d(TAG, "Reading step count for date $date on $platform")
                    provider.readStepCountForDate(date)
                }
                // 日期范围查询
                startDateMillis != null && endDateMillis != null -> {
                    val startDate = TimeCompat.millisToLocalDate(startDateMillis)
                    val endDate = TimeCompat.millisToLocalDate(endDateMillis)
                    Log.d(TAG, "Reading step count for range $startDate to $endDate on $platform")
                    provider.readStepCountForDateRange(startDate, endDate)
                }
                else -> {
                    return@withContext ResponseBuilder.buildInvalidParametersResponse(platform)
                }
            }
            
            result?.let { stepCountResult ->
                ResponseBuilder.buildSuccessResponse(platform, stepCountResult)
            } ?: ResponseBuilder.buildErrorResponse(
                platform,
                "Failed to read step count data",
                "data_read_failed"
            )
            
        } catch (e: Exception) {
            Log.e(TAG, "Error reading step count for platform $platform", e)
            ResponseBuilder.buildErrorResponse(platform, e.message ?: "Unknown error")
        }
    }
    
    /**
     * 检查权限状态
     */
    suspend fun checkPermissions(
        platform: String,
        dataTypes: List<String>,
        operation: String
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        try {
            val provider = getOrCreateProvider(platform)
                ?: return@withContext emptyMap()

            provider.checkPermissions(dataTypes, operation)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking permissions for platform $platform", e)
            emptyMap()
        }
    }

    /**
     * 申请权限
     */
    suspend fun requestPermissions(
        platform: String,
        dataTypes: List<String>,
        operations: List<String>,
        reason: String?
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        try {
            val provider = getOrCreateProvider(platform)
                ?: return@withContext ResponseBuilder.buildPlatformNotSupportedResponse(platform)

            // 总是先初始化provider（如果已初始化则快速返回）
            Log.d(TAG, "Ensuring provider is initialized before requesting permissions...")
            val initSuccess = provider.initialize()
            if (!initSuccess) {
                Log.e(TAG, "Failed to initialize provider before requesting permissions")
                return@withContext ResponseBuilder.buildErrorResponse(
                    platform,
                    "Failed to initialize platform before requesting permissions",
                    "initialization_failed"
                )
            }
            Log.d(TAG, "Provider initialization check passed")

            val success = provider.requestPermissions(dataTypes, operations, reason)
            if (success) {
                mapOf(
                    "status" to "success",
                    "message" to "Permissions requested successfully"
                )
            } else {
                ResponseBuilder.buildErrorResponse(
                    platform,
                    "Failed to request permissions",
                    "permission_request_failed"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting permissions for platform $platform", e)
            ResponseBuilder.buildErrorResponse(platform, e.message ?: "Unknown error")
        }
    }

    /**
     * 获取支持的数据类型
     */
    fun getSupportedDataTypes(platform: String, operation: String?): List<String> {
        return try {
            val provider = activeProviders[platform] ?: providerFactory.createProvider(platform)
            provider?.getSupportedDataTypes(operation) ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting supported data types for $platform", e)
            emptyList()
        }
    }

    /**
     * 检查是否支持某个数据类型
     */
    fun isDataTypeSupported(platform: String, dataType: String, operation: String): Boolean {
        return try {
            val provider = activeProviders[platform] ?: providerFactory.createProvider(platform)
            provider?.isDataTypeSupported(dataType, operation) ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking if data type supported for $platform", e)
            false
        }
    }

    /**
     * 获取平台能力
     */
    fun getPlatformCapabilities(platform: String): List<Map<String, Any>> {
        return try {
            val provider = activeProviders[platform] ?: providerFactory.createProvider(platform)
            provider?.getPlatformCapabilities() ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting platform capabilities for $platform", e)
            emptyList()
        }
    }

    /**
     * 读取健康数据（通用方法）
     */
    suspend fun readHealthData(
        platform: String,
        dataType: String,
        startDateMillis: Long?,
        endDateMillis: Long?,
        limit: Int?
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        try {
            val provider = getOrCreateProvider(platform)
                ?: return@withContext ResponseBuilder.buildPlatformNotSupportedResponse(platform)

            val startDate = startDateMillis?.let { TimeCompat.millisToLocalDate(it) }
            val endDate = endDateMillis?.let { TimeCompat.millisToLocalDate(it) }

            val result = provider.readHealthData(dataType, startDate, endDate, limit)
            result?.let {
                ResponseBuilder.buildHealthDataSuccessResponse(platform, it)
            } ?: ResponseBuilder.buildErrorResponse(
                platform,
                "Failed to read health data for type: $dataType",
                "data_read_failed"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error reading health data for platform $platform", e)
            ResponseBuilder.buildErrorResponse(platform, e.message ?: "Unknown error")
        }
    }

    /**
     * 写入健康数据
     */
    suspend fun writeHealthData(
        platform: String,
        dataMap: Map<String, Any>
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        try {
            val provider = getOrCreateProvider(platform)
                ?: return@withContext ResponseBuilder.buildPlatformNotSupportedResponse(platform)

            val success = provider.writeHealthData(dataMap)
            if (success) {
                mapOf(
                    "status" to "success",
                    "message" to "Health data written successfully"
                )
            } else {
                ResponseBuilder.buildErrorResponse(
                    platform,
                    "Failed to write health data",
                    "data_write_failed"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error writing health data for platform $platform", e)
            ResponseBuilder.buildErrorResponse(platform, e.message ?: "Unknown error")
        }
    }

    /**
     * 批量写入健康数据
     */
    suspend fun writeBatchHealthData(
        platform: String,
        dataList: List<Map<String, Any>>
    ): Map<String, Any> = withContext(Dispatchers.IO) {
        try {
            val provider = getOrCreateProvider(platform)
                ?: return@withContext ResponseBuilder.buildPlatformNotSupportedResponse(platform)

            val success = provider.writeBatchHealthData(dataList)
            if (success) {
                mapOf(
                    "status" to "success",
                    "message" to "Batch health data written successfully",
                    "count" to dataList.size
                )
            } else {
                ResponseBuilder.buildErrorResponse(
                    platform,
                    "Failed to write batch health data",
                    "batch_write_failed"
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error writing batch health data for platform $platform", e)
            ResponseBuilder.buildErrorResponse(platform, e.message ?: "Unknown error")
        }
    }

    /**
     * 断开连接
     */
    fun disconnect() {
        activeProviders.values.forEach { provider ->
            try {
                provider.cleanup()
            } catch (e: Exception) {
                Log.e(TAG, "Error cleaning up provider ${provider.platformKey}", e)
            }
        }
        activeProviders.clear()
        Log.d(TAG, "All providers disconnected")
    }
    
    /**
     * 获取或创建提供者
     */
    private fun getOrCreateProvider(platform: String): HealthDataProvider? {
        return activeProviders[platform] ?: run {
            // 确保factory有最新的Activity
            providerFactory.setActivity(activity)
            val provider = providerFactory.createProvider(platform)
            provider?.let {
                activeProviders[platform] = it
            }
            provider
        }
    }
    
}
package com.health.bridge.health_bridge.services

import android.content.Context
import android.util.Log
import kotlinx.coroutines.withContext
import kotlinx.coroutines.Dispatchers
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
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
    
    companion object {
        private const val TAG = "HealthBridgeService"
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
                    val date = millisToLocalDate(startDateMillis)
                    Log.d(TAG, "Reading step count for date $date on $platform")
                    provider.readStepCountForDate(date)
                }
                // 日期范围查询
                startDateMillis != null && endDateMillis != null -> {
                    val startDate = millisToLocalDate(startDateMillis)
                    val endDate = millisToLocalDate(endDateMillis)
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
            val provider = providerFactory.createProvider(platform)
            provider?.let {
                activeProviders[platform] = it
            }
            provider
        }
    }
    
    /**
     * 毫秒转LocalDate
     */
    private fun millisToLocalDate(millis: Long): LocalDate {
        return Instant.ofEpochMilli(millis)
            .atZone(ZoneId.systemDefault())
            .toLocalDate()
    }
}
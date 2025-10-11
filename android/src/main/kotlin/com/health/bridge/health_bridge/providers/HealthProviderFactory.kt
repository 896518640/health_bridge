package com.health.bridge.health_bridge.providers

import android.app.Activity
import android.content.Context
import android.os.Build
import android.util.Log

/**
 * 健康数据提供者工厂 - 工厂模式
 * 负责创建和管理不同的健康平台提供者
 */
class HealthProviderFactory(
    private val context: Context,
    private var activity: Activity? = null
) {

    companion object {
        private const val TAG = "HealthProviderFactory"
        private const val SAMSUNG_HEALTH = "samsung_health"
        private const val HUAWEI_HEALTH = "huawei_health"
        private const val GOOGLE_FIT = "google_fit"
    }
    
    /**
     * 设置Activity实例
     */
    fun setActivity(activity: Activity?) {
        this.activity = activity
    }
    
    /**
     * 创建健康数据提供者
     */
    fun createProvider(platformKey: String): HealthDataProvider? {
        return when (platformKey) {
            SAMSUNG_HEALTH -> SamsungHealthProvider(context, activity)
            HUAWEI_HEALTH -> HuaweiHealthProvider(context, activity)
            GOOGLE_FIT -> {
                // TODO: 实现Google Fit提供者
                // GoogleFitProvider(context, activity)
                null
            }
            else -> null
        }
    }
    
    /**
     * 获取所有可用的健康平台
     * 优先级：根据设备制造商智能排序
     */
    fun getAvailablePlatforms(): List<String> {
        val availablePlatforms = mutableListOf<String>()
        val manufacturer = Build.MANUFACTURER.lowercase()

        Log.d(TAG, "Device manufacturer: $manufacturer")

        // 根据设备制造商决定检测顺序
        val platformsToCheck = when {
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> {
                // 华为/荣耀设备：优先华为
                Log.d(TAG, "Detected Huawei/Honor device, prioritizing Huawei Health")
                listOf(HUAWEI_HEALTH, SAMSUNG_HEALTH, GOOGLE_FIT)
            }
            manufacturer.contains("samsung") -> {
                // 三星设备：优先三星
                Log.d(TAG, "Detected Samsung device, prioritizing Samsung Health")
                listOf(SAMSUNG_HEALTH, HUAWEI_HEALTH, GOOGLE_FIT)
            }
            else -> {
                // 其他设备：按通用顺序
                Log.d(TAG, "Other device, using default order")
                listOf(SAMSUNG_HEALTH, HUAWEI_HEALTH, GOOGLE_FIT)
            }
        }

        // 按优先级检测可用平台
        for (platformKey in platformsToCheck) {
            createProvider(platformKey)?.let { provider ->
                if (provider.isAvailable()) {
                    Log.d(TAG, "✅ Platform available: $platformKey")
                    availablePlatforms.add(platformKey)
                } else {
                    Log.d(TAG, "❌ Platform not available: $platformKey")
                }
                provider.cleanup()
            }
        }

        Log.d(TAG, "Available platforms: $availablePlatforms")
        return availablePlatforms
    }
}
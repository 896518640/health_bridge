package com.health.bridge.health_bridge.providers

import io.flutter.plugin.common.MethodChannel.Result
import com.health.bridge.health_bridge.utils.TimeCompat

/**
 * 健康数据提供者接口 - 策略模式
 * 为不同的健康平台提供统一的接口
 */
interface HealthDataProvider {

    /**
     * 获取平台标识
     */
    val platformKey: String

    /**
     * 检查平台是否可用
     */
    fun isAvailable(): Boolean

    /**
     * 初始化平台
     */
    suspend fun initialize(): Boolean

    /**
     * 读取今日步数
     */
    suspend fun readTodayStepCount(): StepCountResult?

    /**
     * 读取指定日期步数
     */
    suspend fun readStepCountForDate(date: TimeCompat.LocalDate): StepCountResult?

    /**
     * 读取日期范围步数
     */
    suspend fun readStepCountForDateRange(startDate: TimeCompat.LocalDate, endDate: TimeCompat.LocalDate): StepCountResult?

    /**
     * 检查权限状态
     */
    suspend fun checkPermissions(dataTypes: List<String>, operation: String): Map<String, Any>

    /**
     * 申请权限
     */
    suspend fun requestPermissions(dataTypes: List<String>, operations: List<String>, reason: String?): Boolean

    /**
     * 获取支持的数据类型
     */
    fun getSupportedDataTypes(operation: String?): List<String>

    /**
     * 检查是否支持某个数据类型
     */
    fun isDataTypeSupported(dataType: String, operation: String): Boolean

    /**
     * 获取平台能力
     */
    fun getPlatformCapabilities(): List<Map<String, Any>>

    /**
     * 读取健康数据（通用方法）
     */
    suspend fun readHealthData(
        dataType: String,
        startDate: TimeCompat.LocalDate?,
        endDate: TimeCompat.LocalDate?,
        limit: Int?
    ): HealthDataResult?

    /**
     * 写入健康数据
     */
    suspend fun writeHealthData(dataMap: Map<String, Any>): Boolean

    /**
     * 批量写入健康数据
     */
    suspend fun writeBatchHealthData(dataList: List<Map<String, Any>>): Boolean

    /**
     * 清理资源
     */
    fun cleanup()
}

/**
 * 步数查询结果数据类
 */
data class StepCountResult(
    val totalSteps: Int,
    val data: List<StepData>,
    val isRealData: Boolean = true,
    val dataSource: String,
    val metadata: Map<String, Any> = emptyMap()
)

/**
 * 单个步数数据
 */
data class StepData(
    val steps: Int,
    val timestamp: Long,
    val date: String? = null
)

/**
 * 健康数据查询结果
 */
data class HealthDataResult(
    val data: List<Map<String, Any?>>,
    val dataSource: String,
    val metadata: Map<String, Any> = emptyMap()
)
package com.health.bridge.health_bridge.providers

import java.time.LocalDate
import io.flutter.plugin.common.MethodChannel.Result

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
    suspend fun readStepCountForDate(date: LocalDate): StepCountResult?
    
    /**
     * 读取日期范围步数
     */
    suspend fun readStepCountForDateRange(startDate: LocalDate, endDate: LocalDate): StepCountResult?
    
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
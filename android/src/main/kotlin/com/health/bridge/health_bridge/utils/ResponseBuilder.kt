package com.health.bridge.health_bridge.utils

import com.health.bridge.health_bridge.providers.StepCountResult
import com.health.bridge.health_bridge.providers.HealthDataResult

/**
 * 响应构建器 - 建造者模式
 * 负责构建统一格式的Flutter响应数据
 */
object ResponseBuilder {

    /**
     * 构建成功响应
     */
    fun buildSuccessResponse(
        platform: String,
        result: StepCountResult
    ): Map<String, Any> {
        val responseData = result.data.map { stepData ->
            mapOf(
                "type" to "steps",
                "value" to stepData.steps.toDouble(),
                "timestamp" to stepData.timestamp,
                "unit" to "steps",
                "platform" to platform,
                "date" to stepData.date
            ).filterValues { it != null }
        }

        return mapOf(
            "status" to "success",
            "platform" to platform,
            "data" to responseData,
            "totalSteps" to result.totalSteps,
            "count" to responseData.size,
            "isRealData" to result.isRealData,
            "dataSource" to result.dataSource
        ) + result.metadata
    }

    /**
     * 构建健康数据成功响应
     */
    fun buildHealthDataSuccessResponse(
        platform: String,
        result: HealthDataResult
    ): Map<String, Any> {
        return mapOf(
            "status" to "success",
            "platform" to platform,
            "data" to result.data,
            "count" to result.data.size,
            "message" to "Health data retrieved successfully"
        )
    }

    /**
     * 构建错误响应
     */
    fun buildErrorResponse(
        platform: String,
        message: String,
        errorType: String = "unexpected_error"
    ): Map<String, Any> {
        return mapOf(
            "status" to "error",
            "platform" to platform,
            "message" to message,
            "errorType" to errorType
        )
    }

    /**
     * 构建平台不支持响应
     */
    fun buildPlatformNotSupportedResponse(platform: String): Map<String, Any> {
        return mapOf(
            "status" to "platform_not_supported",
            "platform" to platform,
            "message" to "Platform $platform not supported"
        )
    }

    /**
     * 构建参数无效响应
     */
    fun buildInvalidParametersResponse(
        platform: String,
        message: String = "Invalid date parameters"
    ): Map<String, Any> {
        return mapOf(
            "status" to "error",
            "platform" to platform,
            "message" to message,
            "errorType" to "invalid_parameters"
        )
    }
}
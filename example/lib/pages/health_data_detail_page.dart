import 'package:flutter/cupertino.dart';
import 'package:health_bridge/health_bridge.dart';

/// 健康数据详情页面 - iOS风格
class HealthDataDetailPage extends StatelessWidget {
  final HealthDataType dataType;
  final List<HealthData> dataList;
  final HealthPlatform platform;
  final bool isGroupedByDay;

  const HealthDataDetailPage({
    super.key,
    required this.dataType,
    required this.dataList,
    required this.platform,
    this.isGroupedByDay = false,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(dataType.displayName),
        backgroundColor: CupertinoColors.systemBackground,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getDataTypeColor().withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${dataList.length} 条',
            style: TextStyle(
              fontSize: 13,
              color: _getDataTypeColor(),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: dataList.isEmpty
            ? _buildEmptyView()
            : (isGroupedByDay 
                ? _buildGroupedByDayView(context)
                : _buildListView(context)),
      ),
    );
  }

  /// 空数据视图
  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getDataTypeIcon(),
            size: 80,
            color: CupertinoColors.systemGrey3,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无${dataType.displayName}数据',
            style: const TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建普通列表视图
  Widget _buildListView(BuildContext context) {
    return CupertinoScrollbar(
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dataList.length,
        itemBuilder: (context, index) {
          final data = dataList[index];
          return _buildDataCard(data);
        },
      ),
    );
  }

  /// 构建按天分组的视图
  Widget _buildGroupedByDayView(BuildContext context) {
    final groupedData = _groupDataByDay();
    
    return CupertinoScrollbar(
      child: CustomScrollView(
        slivers: [
          ...groupedData.entries.map((entry) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日期标题
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.secondaryLabel,
                        ),
                      ),
                    ),
                    // 该天的数据
                    ...entry.value.map((data) => _buildDataCard(data)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建数据卡片
  Widget _buildDataCard(HealthData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getDataTypeColor().withOpacity(0.08),
            _getDataTypeColor().withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getDataTypeColor().withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 图标
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _getDataTypeColor().withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              _getDataTypeIcon(),
              color: _getDataTypeColor(),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // 数据信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 数值
                Text(
                  _formatValue(data),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // 时间
                Text(
                  _formatDateTime(DateTime.fromMillisecondsSinceEpoch(data.timestamp)),
                  style: const TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                // 数据来源
                if (data.source != null)
                  Text(
                    data.source!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: CupertinoColors.tertiaryLabel,
                    ),
                  ),
              ],
            ),
          ),
          // 来源标识
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              platform.displayName,
              style: const TextStyle(
                fontSize: 11,
                color: CupertinoColors.secondaryLabel,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 按天分组数据
  Map<String, List<HealthData>> _groupDataByDay() {
    final Map<String, List<HealthData>> grouped = {};
    
    for (final data in dataList) {
      final dateTime = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
      final dateKey = _formatDate(dateTime);
      grouped.putIfAbsent(dateKey, () => []).add(data);
    }
    
    return grouped;
  }

  /// 格式化数值
  String _formatValue(HealthData data) {
    switch (dataType) {
      case HealthDataType.steps:
        return '${data.value?.toInt() ?? 0} 步';
      case HealthDataType.glucose:
        return '${data.value?.toStringAsFixed(1) ?? '0.0'} mmol/L';
      case HealthDataType.bloodPressure:
        // 血压数据存储在metadata中
        final systolic = data.metadata['systolic'] as num?;
        final diastolic = data.metadata['diastolic'] as num?;
        if (systolic != null && diastolic != null) {
          return '${systolic.toInt()}/${diastolic.toInt()} mmHg';
        }
        return '${data.value?.toStringAsFixed(0) ?? '0'} mmHg';
      case HealthDataType.height:
        return '${data.value?.toStringAsFixed(1) ?? '0.0'} cm';
      case HealthDataType.weight:
        return '${data.value?.toStringAsFixed(1) ?? '0.0'} kg';
      default:
        return data.value?.toStringAsFixed(2) ?? '0.00';
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// 格式化日期
  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dataDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (dataDate == today) {
      return '今天';
    } else if (dataDate == yesterday) {
      return '昨天';
    } else {
      return '${dateTime.month}月${dateTime.day}日';
    }
  }

  /// 获取数据类型图标
  IconData _getDataTypeIcon() {
    switch (dataType) {
      case HealthDataType.steps:
        return CupertinoIcons.flame_fill;
      case HealthDataType.glucose:
        return CupertinoIcons.drop_fill;
      case HealthDataType.bloodPressure:
        return CupertinoIcons.heart_fill;
      case HealthDataType.height:
        return CupertinoIcons.arrow_up_down;
      case HealthDataType.weight:
        return CupertinoIcons.chart_bar_alt_fill;
      default:
        return CupertinoIcons.heart;
    }
  }

  /// 获取数据类型颜色
  Color _getDataTypeColor() {
    switch (dataType) {
      case HealthDataType.steps:
        return CupertinoColors.systemOrange;
      case HealthDataType.glucose:
        return CupertinoColors.systemPurple;
      case HealthDataType.bloodPressure:
        return CupertinoColors.systemRed;
      case HealthDataType.height:
        return CupertinoColors.systemBlue;
      case HealthDataType.weight:
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.systemGrey;
    }
  }
}

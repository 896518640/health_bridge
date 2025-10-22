import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';

/// 健康数据详情页面
class HealthDataDetailPage extends StatelessWidget {
  final HealthDataType dataType;
  final List<HealthData> dataList;
  final HealthPlatform platform;
  final bool isGroupedByDay; // 是否按天分组显示

  const HealthDataDetailPage({
    super.key,
    required this.dataType,
    required this.dataList,
    required this.platform,
    this.isGroupedByDay = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(dataType.displayName),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(
                isGroupedByDay 
                    ? '共 ${dataList.length} 条 (按天分组)'
                    : '共 ${dataList.length} 条',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        ],
      ),
      body: isGroupedByDay 
          ? _buildGroupedByDayView(context)
          : _buildListView(context),
    );
  }

  /// 构建普通列表视图
  Widget _buildListView(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: dataList.length,
      itemBuilder: (context, index) {
        final data = dataList[index];
        return _buildDataCard(context, data, index);
      },
    );
  }

  /// 构建按天分组的视图
  Widget _buildGroupedByDayView(BuildContext context) {
    // 按天分组数据
    final groupedData = _groupDataByDay(dataList);
    
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: groupedData.length,
      itemBuilder: (context, index) {
        final entry = groupedData[index];
        final date = entry['date'] as String;
        final dayData = entry['data'] as List<HealthData>;
        
        return _buildDayGroupCard(context, date, dayData);
      },
    );
  }

  /// 按天分组数据
  List<Map<String, dynamic>> _groupDataByDay(List<HealthData> data) {
    final Map<String, List<HealthData>> grouped = {};
    
    for (final item in data) {
      final date = DateTime.fromMillisecondsSinceEpoch(item.timestamp);
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(item);
    }
    
    // 转换为列表并按日期降序排序
    final result = grouped.entries.map((entry) {
      return {
        'date': entry.key,
        'data': entry.value,
      };
    }).toList();
    
    result.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));
    
    return result;
  }

  /// 构建每天的分组卡片
  Widget _buildDayGroupCard(BuildContext context, String date, List<HealthData> dayData) {
    // 计算当天的统计信息
    double? total;
    double? average;
    double? min;
    double? max;
    
    final values = dayData
        .where((d) => d.value != null)
        .map((d) => d.value!)
        .toList();
    
    if (values.isNotEmpty) {
      total = values.reduce((a, b) => a + b);
      average = total / values.length;
      min = values.reduce((a, b) => a < b ? a : b);
      max = values.reduce((a, b) => a > b ? a : b);
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 3,
      child: ExpansionTile(
        title: Row(
          children: [
            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              date,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('记录数: ${dayData.length} 条'),
              if (average != null) ...[
                const SizedBox(height: 4),
                Text(
                  '平均值: ${average.toStringAsFixed(2)} ${dayData.first.unit}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (min != null && max != null) ...[
                const SizedBox(height: 2),
                Text(
                  '范围: ${min.toStringAsFixed(2)} - ${max.toStringAsFixed(2)} ${dayData.first.unit}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: dayData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                return _buildDataCard(context, data, index);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单条数据卡片
  Widget _buildDataCard(BuildContext context, HealthData data, int index) {
    final time = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
    final isCompositeData = data.value == null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          child: Text('${index + 1}'),
        ),
        title: _buildDataTitle(data, isCompositeData),
        subtitle: _buildDataSubtitle(time, data),
        children: [
          _buildExpandedDetails(context, data, isCompositeData),
        ],
      ),
    );
  }

  /// 构建数据标题
  Widget _buildDataTitle(HealthData data, bool isCompositeData) {
    if (isCompositeData) {
      // 复合数据类型（如血压）
      if (data.metadata.containsKey('systolic') &&
          data.metadata.containsKey('diastolic')) {
        return Text(
          '${data.metadata['systolic']}/${data.metadata['diastolic']} ${data.unit}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        );
      } else {
        return const Text(
          '复合数据 (查看详情)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
      }
    } else {
      // 简单数值型数据
      return Text(
        '${data.value?.toStringAsFixed(2) ?? 'N/A'} ${data.unit}',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }
  }

  /// 构建数据副标题
  Widget _buildDataSubtitle(DateTime time, HealthData data) {
    // 检查是否是聚合数据
    final isStatistics = data.metadata['queryType'] == 'statistics';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.access_time, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              _formatDateTime(time),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        if (isStatistics) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                '聚合数据 (${data.metadata['interval'] ?? 'daily'})',
                style: const TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ],
          ),
        ],
        if (data.source != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.source, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                '来源: ${data.source}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 构建展开的详细信息
  Widget _buildExpandedDetails(
    BuildContext context,
    HealthData data,
    bool isCompositeData,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 基本信息
          _buildInfoSection(
            context,
            '基本信息',
            Icons.info_outline,
            [
              _buildInfoRow('数据类型', dataType.displayName),
              _buildInfoRow('单位', data.unit),
              _buildInfoRow('平台', platform.displayName),
              if (data.value != null)
                _buildInfoRow('主值', data.value.toString()),
              _buildInfoRow('时间戳', data.timestamp.toString()),
            ],
          ),

          // Metadata 信息
          if (data.metadata.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoSection(
              context,
              'SDK 原始数据 (Metadata)',
              Icons.code,
              data.metadata.entries.map((entry) {
                return _buildInfoRow(entry.key, entry.value.toString());
              }).toList(),
            ),
          ],

          // 如果是血压数据，显示标准化字段说明
          if (isCompositeData &&
              data.metadata.containsKey('systolic') &&
              data.metadata.containsKey('diastolic'))
            ..._buildBloodPressureInfo(context, data),
          
          // 如果是聚合数据，显示说明
          if (data.metadata['queryType'] == 'statistics')
            ..._buildStatisticsInfo(context, data),
        ],
      ),
    );
  }

  /// 构建血压标准化字段说明
  List<Widget> _buildBloodPressureInfo(BuildContext context, HealthData data) {
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.favorite, size: 16, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '血压标准化字段',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '收缩压 (systolic): ${data.metadata['systolic']} ${data.unit}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '舒张压 (diastolic): ${data.metadata['diastolic']} ${data.unit}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '这些字段是跨平台统一的标准字段',
              style: TextStyle(
                fontSize: 11,
                color: Colors.blue.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ];
  }
  
  /// 构建聚合数据说明
  List<Widget> _buildStatisticsInfo(BuildContext context, HealthData data) {
    final interval = data.metadata['interval'] ?? 'daily';
    final aggregation = data.metadata['aggregation'];
    
    return [
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '聚合统计数据',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '统计周期: ${interval == 'daily' ? '每日' : interval}',
              style: const TextStyle(fontSize: 12),
            ),
            if (aggregation != null)
              Text(
                '聚合方式: ${_getAggregationText(aggregation)}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 4),
            Text(
              '这是按时间段统计的汇总数据，不是原始记录',
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// 构建信息区块
  Widget _buildInfoSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取聚合方式文本
  String _getAggregationText(String aggregation) {
    switch (aggregation) {
      case 'average':
        return '平均值';
      case 'sum':
        return '总和';
      case 'minimum':
        return '最小值';
      case 'maximum':
        return '最大值';
      default:
        return aggregation;
    }
  }

  /// 格式化日期时间
  String _formatDateTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';

/// 健康数据详情页面
class HealthDataDetailPage extends StatelessWidget {
  final HealthDataType dataType;
  final List<HealthData> dataList;
  final HealthPlatform platform;

  const HealthDataDetailPage({
    super.key,
    required this.dataType,
    required this.dataList,
    required this.platform,
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
                '共 ${dataList.length} 条',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: dataList.length,
        itemBuilder: (context, index) {
          final data = dataList[index];
          return _buildDataCard(context, data, index);
        },
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

  /// 格式化日期时间
  String _formatDateTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-'
        '${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}';
  }
}

import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';

/// 云侧数据读取页面
/// 通过华为账号 OAuth 授权后，读取云端健康数据
class CloudDataReadingPage extends StatefulWidget {
  final String? accessToken;
  final String? clientId;

  const CloudDataReadingPage({
    super.key,
    this.accessToken,
    this.clientId,
  });

  @override
  State<CloudDataReadingPage> createState() => _CloudDataReadingPageState();
}

class _CloudDataReadingPageState extends State<CloudDataReadingPage> {
  bool _isLoading = false;
  String? _accessToken;
  String? _clientId;
  final Map<String, dynamic> _cloudData = {};

  // 常量提示信息
  static const String _noStepsDeltaDataHint = '⚠️ 查询成功，但暂无步数增量明细数据\n\n'
      '说明：华为智能穿戴设备（手表/手环）可能只上传汇总数据，\n'
      '不包含每个时间段的详细增量。\n\n'
      '建议：使用统计查询查看汇总数据';

  @override
  void initState() {
    super.initState();
    _accessToken = widget.accessToken;
    _clientId = widget.clientId;
    _checkAuthStatus();
  }

  /// 检查授权状态并设置插件凭证
  Future<void> _checkAuthStatus() async {
    if (_accessToken != null && _clientId != null) {
      debugPrint(
          '[云侧数据] 已获取 Access Token: ${_accessToken!.substring(0, 20)}...');
      // 设置插件凭证
      await HealthBridge.setHuaweiCloudCredentials(
        accessToken: _accessToken!,
        clientId: _clientId!,
      );
    } else {
      debugPrint('[云侧数据] 未获取到 Access Token');
    }
  }

  // ==================== 工具方法 ====================

  /// 格式化日期显示（M月D日）
  String _formatDateDisplay(DateTime date) {
    return '${date.month}月${date.day}日';
  }

  /// 格式化时间显示（HH:MM）
  String _formatTimeDisplay(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// 通用查询执行器 - 统一处理授权检查、loading状态和错误处理
  Future<void> _executeQuery(
    String logPrefix,
    Future<void> Function() queryFn,
  ) async {
    if (_accessToken == null || _clientId == null) {
      _showError('请先完成 OAuth 授权');
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('[云侧数据] $logPrefix');
      await queryFn();
    } catch (e) {
      debugPrint('[云侧数据] 错误: $e');
      _showError('查询失败: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ==================== 查询方法 ====================

  /// 【查询1】读取最近一周每天的步数总数
  /// 使用插件API：readCloudHealthData with queryType='daily'
  Future<void> _readWeeklySteps() async {
    await _executeQuery('📅 开始查询最近7天每日步数总数', () async {
      // 计算日期范围
      final now = DateTime.now();
      final endDay = DateTime(now.year, now.month, now.day);
      final startDay = endDay.subtract(const Duration(days: 6));

      // 使用插件API查询（统计模式）
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.steps,
        startTime: startDay.millisecondsSinceEpoch,
        endTime: endDay.millisecondsSinceEpoch,
        queryType: 'daily',
      );

      if (result.isSuccess) {
        setState(() => _cloudData['weeklySteps'] = result);

        // 处理响应数据
        int totalSteps = 0;
        final dailySteps = <String>[];

        for (final data in result.data) {
          final steps = data.value?.toInt() ?? 0;
          totalSteps += steps;
          final date = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
          dailySteps.add('${_formatDateDisplay(date)}: $steps步');
        }

        if (dailySteps.isNotEmpty) {
          _showSuccess('✅ 最近一周步数查询成功\n'
              '查询天数: ${dailySteps.length} 天\n'
              '总步数: $totalSteps 步\n'
              '${dailySteps.join('\n')}');
        } else {
          _showSuccess('✅ 查询成功，但暂无步数数据');
        }
      } else {
        _showError('查询失败: ${result.message}');
      }
    });
  }

  /// 【查询2】读取今天的步数增量明细
  /// 使用插件API：readCloudHealthData with queryType='detail'
  Future<void> _readTodayStepsDelta() async {
    await _executeQuery('📊 开始查询今天的步数增量明细', () async {
      // 计算今天的时间范围（从0点到现在）
      final now = DateTime.now();
      final startTime = DateTime(now.year, now.month, now.day);

      // 使用插件API查询（原子模式）
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.steps,
        startTime: startTime.millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
        queryType: 'detail',
      );

      if (result.isSuccess) {
        setState(() => _cloudData['todayDelta'] = result);

        // 处理响应数据
        int totalSteps = 0;
        int recordCount = result.data.length;

        for (final data in result.data) {
          totalSteps += data.value?.toInt() ?? 0;
        }

        if (recordCount > 0) {
          _showSuccess('✅ 今天步数增量查询成功\n'
              '记录条数: $recordCount 条\n'
              '总步数: $totalSteps 步');
        } else {
          _showSuccess(_noStepsDeltaDataHint);
        }
      } else {
        _showError('查询失败: ${result.message}');
      }
    });
  }

  /// 【查询3】读取昨天的步数总数
  /// 使用插件API：readCloudHealthData with queryType='daily'
  Future<void> _readYesterdayTotal() async {
    await _executeQuery('📈 开始查询昨天的步数总数', () async {
      // 计算昨天的日期
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final startDay = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final endDay = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);

      // 使用插件API查询（统计模式）
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.steps,
        startTime: startDay.millisecondsSinceEpoch,
        endTime: endDay.millisecondsSinceEpoch,
        queryType: 'daily',
      );

      if (result.isSuccess && result.data.isNotEmpty) {
        setState(() => _cloudData['yesterdayTotal'] = result);
        
        final steps = result.data[0].value?.toInt() ?? 0;
        _showSuccess('✅ 昨天步数总数查询成功\n'
            '日期: ${_formatDateDisplay(yesterday)}\n'
            '总步数: $steps 步');
      } else {
        _showSuccess('✅ 查询成功，但昨天暂无步数数据');
      }
    });
  }

  /// 【查询4】读取昨天的步数分段增量
  /// 使用插件API：readCloudHealthData with queryType='detail'
  Future<void> _readYesterdayDelta() async {
    await _executeQuery('🔍 开始查询昨天的步数分段增量', () async {
      // 计算昨天的时间范围
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final startTime = DateTime(yesterday.year, yesterday.month, yesterday.day);
      final endTime = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);

      // 使用插件API查询（原子模式）
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.steps,
        startTime: startTime.millisecondsSinceEpoch,
        endTime: endTime.millisecondsSinceEpoch,
        queryType: 'detail',
      );

      if (result.isSuccess) {
        setState(() => _cloudData['yesterdayDelta'] = result);

        int totalSteps = 0;
        final details = <String>[];

        for (final data in result.data) {
          final steps = data.value?.toInt() ?? 0;
          totalSteps += steps;
          
          final startTimeStr = data.metadata['startTime'] ?? '';
          final endTimeStr = data.metadata['endTime'] ?? '';
          final start = DateTime.parse(startTimeStr);
          final end = DateTime.parse(endTimeStr);
          
          details.add('${_formatTimeDisplay(start)} - ${_formatTimeDisplay(end)}: $steps步');
        }

        if (details.isNotEmpty) {
          final preview = details.take(10).join('\n');
          final moreInfo =
              details.length > 10 ? '\n...还有 ${details.length - 10} 条记录' : '';

          _showSuccess('✅ 昨天步数分段增量查询成功\n'
              '日期: ${_formatDateDisplay(yesterday)}\n'
              '记录条数: ${details.length} 条\n'
              '总步数: $totalSteps 步\n'
              '\n前10条明细:\n$preview$moreInfo');
        } else {
          _showSuccess(_noStepsDeltaDataHint);
        }
      } else {
        _showError('查询失败: ${result.message}');
      }
    });
  }

  /// 【血糖明细查询】读取最近7天的血糖明细数据
  /// 使用插件API：readCloudHealthData with queryType='detail'
  Future<void> _readBloodGlucoseDetail() async {
    await _executeQuery('🩸 开始查询血糖明细数据', () async {
      // 计算时间范围（最近7天）
      final now = DateTime.now();

      // 使用插件API查询
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.glucose,
        startTime: now.subtract(const Duration(days: 6)).millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
        queryType: 'detail',
      );

      if (result.isSuccess) {
        setState(() => _cloudData['bloodGlucoseDetail'] = result);

        final details = <String>[];
        for (final data in result.data) {
          final glucoseValue = data.value;
          if (glucoseValue != null) {
            final measureTime = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
            details.add(
                '${measureTime.month}/${measureTime.day} ${_formatTimeDisplay(measureTime)} - $glucoseValue mmol/L');
          }
        }

        if (details.isNotEmpty) {
          final preview = details.take(10).join('\n');
          final moreInfo =
              details.length > 10 ? '\n...还有 ${details.length - 10} 条记录' : '';

          _showSuccess('✅ 血糖明细数据查询成功\n'
              '记录条数: ${details.length} 条\n'
              '\n前10条明细:\n$preview$moreInfo');
        } else {
          _showSuccess('✅ 查询成功，但暂无血糖明细数据');
        }
      } else {
        _showError('查询失败: ${result.message}');
      }
    });
  }

  /// 【血压明细查询】读取最近7天的血压明细数据
  /// 使用插件API：readCloudHealthData with queryType='detail'
  Future<void> _readBloodPressureDetail() async {
    await _executeQuery('🩺 开始查询血压明细数据', () async {
      // 计算时间范围（最近7天）
      final now = DateTime.now();

      // 使用插件API查询
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.bloodPressure,
        startTime: now.subtract(const Duration(days: 6)).millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
        queryType: 'detail',
      );

      if (result.isSuccess) {
        setState(() => _cloudData['bloodPressureDetail'] = result);

        final details = <String>[];
        for (final data in result.data) {
          // 血压值在metadata中
          final systolic = data.metadata['systolic_pressure'] as double?;
          final diastolic = data.metadata['diastolic_pressure'] as double?;
          
          if (systolic != null && diastolic != null) {
            final measureTime = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
            details.add(
                '${measureTime.month}/${measureTime.day} ${_formatTimeDisplay(measureTime)} - ${systolic.toInt()}/${diastolic.toInt()} mmHg');
          }
        }

        if (details.isNotEmpty) {
          final preview = details.take(10).join('\n');
          final moreInfo =
              details.length > 10 ? '\n...还有 ${details.length - 10} 条记录' : '';

          _showSuccess('✅ 血压明细数据查询成功\n'
              '记录条数: ${details.length} 条\n'
              '\n前10条明细:\n$preview$moreInfo');
        } else {
          _showSuccess('✅ 查询成功，但暂无血压明细数据');
        }
      } else {
        _showError('查询失败: ${result.message}');
      }
    });
  }

  /// 【血糖统计查询】读取最近7天的每日血糖统计
  /// 使用插件API：readCloudHealthData with queryType='daily'
  Future<void> _readBloodGlucoseStats() async {
    await _executeQuery('📊 开始查询血糖统计数据', () async {
      // 计算日期范围
      final now = DateTime.now();
      final endDay = DateTime(now.year, now.month, now.day);
      final startDay = endDay.subtract(const Duration(days: 6));

      // 使用插件API查询（统计模式）
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.glucose,
        startTime: startDay.millisecondsSinceEpoch,
        endTime: endDay.millisecondsSinceEpoch,
        queryType: 'daily',
      );

      if (result.isSuccess) {
        setState(() => _cloudData['bloodGlucoseStats'] = result);

        final dailyStats = <String>[];
        for (final data in result.data) {
          // 从metadata中获取统计值
          final avg = data.metadata['avg'] as double?;
          final max = data.metadata['max'] as double?;
          final min = data.metadata['min'] as double?;

          if (avg != null && max != null && min != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
            dailyStats.add(
                '${_formatDateDisplay(date)}: 平均${avg.toStringAsFixed(1)} / 最高${max.toStringAsFixed(1)} / 最低${min.toStringAsFixed(1)} mmol/L');
          }
        }

        if (dailyStats.isNotEmpty) {
          _showSuccess('✅ 血糖统计数据查询成功\n'
              '统计天数: ${dailyStats.length} 天\n'
              '\n每日统计:\n${dailyStats.join('\n')}');
        } else {
          _showSuccess('✅ 查询成功，但暂无血糖统计数据');
        }
      } else {
        _showError('查询失败: ${result.message}');
      }
    });
  }


  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云侧数据读取'),
        backgroundColor: Colors.purple,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 平台支持说明
                  Card(
                    color: Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '平台支持',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '✅ 华为运动健康（需 OAuth 授权）',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.cancel,
                                color: Colors.grey.shade500,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '❌ 其他平台（暂不支持云侧）',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 授权状态
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _accessToken != null
                                    ? Icons.check_circle
                                    : Icons.warning_amber,
                                color: _accessToken != null
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _accessToken != null ? '已授权' : '未授权',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _accessToken != null
                                      ? Colors.green.shade900
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_accessToken == null) ...[
                            const Text(
                              '您还未完成华为账号授权，请先前往 "OAuth 授权管理" 完成授权。',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('返回授权'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              '您已完成授权，可以读取云端健康数据。',
                              style: TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Access Token: ${_accessToken!.substring(0, 20)}...',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 数据读取功能
                  Text(
                    '步数查询（4种方式）',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '根据不同需求选择对应的查询方式',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),

                  // 【查询1】最近一周每天的步数
                  _buildStepQueryCard(
                    icon: Icons.calendar_view_week,
                    color: Colors.blue,
                    title: '①  最近一周每天步数',
                    subtitle: '查询最近7天的每日步数总数',
                    apiType: 'v2 dailyPolymerize (steps.total)',
                    onRead: _readWeeklySteps,
                  ),
                  const SizedBox(height: 10),

                  // 【查询2】今天的步数增量
                  _buildStepQueryCard(
                    icon: Icons.show_chart,
                    color: Colors.green,
                    title: '② 今天的步数增量明细',
                    subtitle: '查询今天每个时间段的步数变化',
                    apiType: 'v2 polymerize 明细 (steps.delta)',
                    onRead: _readTodayStepsDelta,
                  ),
                  const SizedBox(height: 10),

                  // 【查询3】昨天的步数总数
                  _buildStepQueryCard(
                    icon: Icons.today,
                    color: Colors.orange,
                    title: '③ 昨天的步数总数',
                    subtitle: '查询昨天全天的步数统计',
                    apiType: 'v2 dailyPolymerize (steps.total)',
                    onRead: _readYesterdayTotal,
                  ),
                  const SizedBox(height: 10),

                  // 【查询4】昨天的分段增量
                  _buildStepQueryCard(
                    icon: Icons.access_time,
                    color: Colors.purple,
                    title: '④ 昨天的分段步数增量',
                    subtitle: '查询昨天每个时间段的步数增量',
                    apiType: 'v2 polymerize 明细 (steps.delta)',
                    onRead: _readYesterdayDelta,
                  ),
                  const SizedBox(height: 24),

                  // 其他健康数据
                  Text(
                    '血糖查询（2种方式）',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '根据不同需求选择对应的查询方式',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),

                  // 血糖明细查询
                  _buildStepQueryCard(
                    icon: Icons.water_drop,
                    color: Colors.red,
                    title: '① 最近7天血糖明细',
                    subtitle: '查询每次测量的详细血糖数据',
                    apiType: 'v2 polymerize 明细 (instantaneous.blood_glucose)',
                    onRead: _readBloodGlucoseDetail,
                  ),
                  const SizedBox(height: 10),

                  // 血糖统计查询
                  _buildStepQueryCard(
                    icon: Icons.analytics,
                    color: Colors.red,
                    title: '② 最近7天血糖统计',
                    subtitle: '查询每日血糖平均值、最大最小值',
                    apiType: 'v2 dailyPolymerize (cgm_blood_glucose.statistics)',
                    onRead: _readBloodGlucoseStats,
                  ),
                  const SizedBox(height: 24),

                  // 血压查询
                  Text(
                    '血压查询',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '查询血压明细数据',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),

                  // 血压明细查询
                  _buildStepQueryCard(
                    icon: Icons.favorite,
                    color: Colors.pink,
                    title: '最近7天血压明细',
                    subtitle: '查询每次测量的详细血压数据',
                    apiType: 'v2 polymerize 明细 (instantaneous.blood_pressure)',
                    onRead: _readBloodPressureDetail,
                  ),
                  const SizedBox(height: 24),

                  // 使用说明
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '使用说明',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. 云侧数据存储在华为健康云端\n'
                            '2. 需要通过 OAuth 授权才能访问\n'
                            '3. 数据包括步数、血糖、血压等健康记录\n'
                            '4. 与端侧数据相比，云侧数据可跨设备同步',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// 构建步数查询卡片
  Widget _buildStepQueryCard({
    required IconData icon,
    required MaterialColor color,
    required String title,
    required String subtitle,
    required String apiType,
    required VoidCallback onRead,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: _accessToken != null ? onRead : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              // 文字信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.shade200),
                      ),
                      child: Text(
                        apiType,
                        style: TextStyle(
                          fontSize: 10,
                          color: color.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 按钮
              Icon(
                Icons.arrow_forward_ios,
                color: _accessToken != null ? color : Colors.grey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

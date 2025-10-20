import 'package:flutter/material.dart';
import 'package:health_bridge/health_bridge.dart';

/// 云侧数据读取示例 - 使用新的插件API
/// 
/// 展示如何使用HealthBridge插件API读取华为云侧健康数据
class CloudDataReadingExample extends StatefulWidget {
  final String accessToken;
  final String clientId;

  const CloudDataReadingExample({
    super.key,
    required this.accessToken,
    required this.clientId,
  });

  @override
  State<CloudDataReadingExample> createState() => _CloudDataReadingExampleState();
}

class _CloudDataReadingExampleState extends State<CloudDataReadingExample> {
  bool _isLoading = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _initializeCloudAPI();
  }

  /// 初始化云侧API
  Future<void> _initializeCloudAPI() async {
    try {
      // 设置插件凭证
      await HealthBridge.setHuaweiCloudCredentials(
        accessToken: widget.accessToken,
        clientId: widget.clientId,
      );
      _showMessage('✅ 云侧API初始化成功');
    } catch (e) {
      _showMessage('❌ 初始化失败: $e');
    }
  }

  /// 示例1：原子查询 - 读取步数详细数据
  Future<void> _readStepsDetail() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.steps,
        startTime: now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
        queryType: 'detail', // 原子查询
      );

      if (result.isSuccess) {
        final buffer = StringBuffer();
        buffer.writeln('✅ 查询成功');
        buffer.writeln('记录数: ${result.data.length}');
        
        int total = 0;
        for (final data in result.data) {
          total += (data.value?.toInt() ?? 0);
          
          // 访问原始metadata
          final startTime = data.metadata['startTime'];
          final endTime = data.metadata['endTime'];
          buffer.writeln('$startTime → $endTime: ${data.value} steps');
        }
        buffer.writeln('总步数: $total');
        
        setState(() => _result = buffer.toString());
      } else {
        setState(() => _result = '❌ 查询失败: ${result.message}');
      }
    } catch (e) {
      setState(() => _result = '❌ 异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 示例2：统计查询 - 读取每日步数汇总
  Future<void> _readStepsDaily() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.steps,
        startTime: now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
        queryType: 'daily', // 统计查询
      );

      if (result.isSuccess) {
        final buffer = StringBuffer();
        buffer.writeln('✅ 查询成功');
        buffer.writeln('统计天数: ${result.data.length}');
        
        for (final data in result.data) {
          final date = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
          buffer.writeln('${date.month}/${date.day}: ${data.value?.toInt()} steps');
        }
        
        setState(() => _result = buffer.toString());
      } else {
        setState(() => _result = '❌ 查询失败: ${result.message}');
      }
    } catch (e) {
      setState(() => _result = '❌ 异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 示例3：读取血糖数据
  Future<void> _readGlucose() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.glucose,
        startTime: now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
        queryType: 'detail',
      );

      if (result.isSuccess) {
        final buffer = StringBuffer();
        buffer.writeln('✅ 查询成功');
        buffer.writeln('记录数: ${result.data.length}');
        
        for (final data in result.data) {
          final time = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
          buffer.writeln('${time.month}/${time.day} ${time.hour}:${time.minute}: ${data.value} mmol/L');
          
          // 访问所有原始字段
          debugPrint('完整metadata: ${data.metadata}');
        }
        
        setState(() => _result = buffer.toString());
      } else {
        setState(() => _result = '❌ 查询失败: ${result.message}');
      }
    } catch (e) {
      setState(() => _result = '❌ 异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 示例4：读取血压数据（复合数据）
  Future<void> _readBloodPressure() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final result = await HealthBridge.readCloudHealthData(
        dataType: HealthDataType.bloodPressure,
        startTime: now.subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        endTime: now.millisecondsSinceEpoch,
        queryType: 'detail',
      );

      if (result.isSuccess) {
        final buffer = StringBuffer();
        buffer.writeln('✅ 查询成功');
        buffer.writeln('记录数: ${result.data.length}');
        
        for (final data in result.data) {
          final time = DateTime.fromMillisecondsSinceEpoch(data.timestamp);
          // 血压数据在metadata中
          final systolic = data.metadata['systolic_pressure'];
          final diastolic = data.metadata['diastolic_pressure'];
          buffer.writeln('${time.month}/${time.day} ${time.hour}:${time.minute}: $systolic/$diastolic mmHg');
          
          // 所有原始字段都在metadata中
          debugPrint('完整metadata: ${data.metadata}');
        }
        
        setState(() => _result = buffer.toString());
      } else {
        setState(() => _result = '❌ 查询失败: ${result.message}');
      }
    } catch (e) {
      setState(() => _result = '❌ 异常: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('云侧数据读取示例'),
      ),
      body: Column(
        children: [
          // 按钮区域
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _readStepsDetail,
                  child: const Text('步数详细数据'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _readStepsDaily,
                  child: const Text('每日步数汇总'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _readGlucose,
                  child: const Text('血糖数据'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _readBloodPressure,
                  child: const Text('血压数据'),
                ),
              ],
            ),
          ),
          
          // 结果展示区域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Text(_result),
                  ),
          ),
        ],
      ),
    );
  }
}


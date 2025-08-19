import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:health_bridge/health_bridge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Health Bridge Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HealthBridgeDemo(),
    );
  }
}

class HealthBridgeDemo extends StatefulWidget {
  const HealthBridgeDemo({super.key});

  @override
  State<HealthBridgeDemo> createState() => _HealthBridgeDemoState();
}

class _HealthBridgeDemoState extends State<HealthBridgeDemo> {
  String _platformVersion = '未知';
  List<HealthPlatform> _availablePlatforms = [];
  HealthPlatform? _selectedPlatform;
  String _initStatus = '未初始化';
  String _stepsData = '无步数数据';
  String _dateStepsData = '无日期步数数据';
  String _rangeStepsData = '无范围步数数据';
  DateTime _selectedDate = DateTime.now();
  DateTime _rangeStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _rangeEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    List<HealthPlatform> platforms = [];
    
    try {
      platformVersion = await HealthBridge.getPlatformVersion() ?? '未知平台版本';
      platforms = await HealthBridge.getAvailableHealthPlatforms();
    } on PlatformException {
      platformVersion = '获取平台版本失败';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _availablePlatforms = platforms;
      if (platforms.isNotEmpty) {
        _selectedPlatform = platforms.first;
      }
    });
  }

  Future<void> _initializeHealthPlatform() async {
    if (_selectedPlatform == null) return;
    
    try {
      final result = await HealthBridge.initializeHealthPlatform(_selectedPlatform!);
      setState(() {
        if (result.isSuccess) {
          _initStatus = '平台 ${_selectedPlatform!.displayName} 初始化成功';
        } else {
          _initStatus = result.message ?? '初始化平台失败';
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _initStatus = '初始化失败: ${e.message}';
      });
    }
  }

  Future<void> _getTodaySteps() async {
    if (_selectedPlatform == null) return;
    
    try {
      // 使用新的统一API - 不提供日期参数，读取今日步数
      final result = await HealthBridge.readStepCount(platform: _selectedPlatform!);
      setState(() {
        if (result.isSuccess) {
          final totalSteps = result.totalCount ?? 0;
          _stepsData = '今日步数: $totalSteps 步';
        } else {
          _stepsData = result.message ?? '获取步数数据失败';
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _stepsData = '获取步数失败: ${e.message}';
      });
    }
  }

  Future<void> _getStepsForDate() async {
    if (_selectedPlatform == null) return;
    
    try {
      // 使用新的统一API - 提供startDate读取指定日期步数
      final result = await HealthBridge.readStepCount(
        platform: _selectedPlatform!,
        startDate: _selectedDate,
      );
      setState(() {
        if (result.isSuccess) {
          final totalSteps = result.totalCount ?? 0;
          final dateStr = _selectedDate.toString().split(' ')[0]; // 只显示日期部分
          _dateStepsData = '$dateStr 的步数: $totalSteps 步';
        } else {
          _dateStepsData = result.message ?? '获取所选日期的步数数据失败';
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _dateStepsData = '获取日期步数失败: ${e.message}';
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _getStepsForDate(); // 自动获取新选择日期的步数
    }
  }

  Future<void> _getStepsForDateRange() async {
    if (_selectedPlatform == null) return;
    
    try {
      // 使用新的统一API - 提供startDate和endDate读取日期范围步数
      final result = await HealthBridge.readStepCount(
        platform: _selectedPlatform!,
        startDate: _rangeStartDate,
        endDate: _rangeEndDate,
      );
      setState(() {
        if (result.isSuccess) {
          final totalSteps = result.totalCount ?? 0;
          final days = _rangeEndDate.difference(_rangeStartDate).inDays + 1;
          final startStr = _rangeStartDate.toString().split(' ')[0];
          final endStr = _rangeEndDate.toString().split(' ')[0];
          _rangeStepsData = '$startStr 到 $endStr ($days天)\n总步数: $totalSteps 步\n平均: ${(totalSteps / days).round()} 步/天';
        } else {
          _rangeStepsData = result.message ?? '获取日期范围步数数据失败';
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _rangeStepsData = '获取日期范围步数失败: ${e.message}';
      });
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _rangeStartDate, end: _rangeEndDate),
    );
    if (picked != null) {
      setState(() {
        _rangeStartDate = picked.start;
        _rangeEndDate = picked.end;
      });
      _getStepsForDateRange(); // 自动获取新选择日期范围的步数
    }
  }

  Future<void> _disconnect() async {
    try {
      await HealthBridge.disconnect();
      setState(() {
        _initStatus = '已断开连接';
        _stepsData = '无步数数据';
        _dateStepsData = '无日期步数数据';
        _rangeStepsData = '无范围步数数据';
      });
      
      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已成功断开所有健康平台连接'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('断开连接失败: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Health Bridge Demo'),
          backgroundColor: Colors.blue[600],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '平台信息',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('运行在: $_platformVersion'),
                      const SizedBox(height: 8),
                      Text('可用平台: ${_availablePlatforms.map((p) => p.displayName).join(', ')}'),
                      if (_availablePlatforms.isEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '当前设备不支持 Samsung Health 功能。\n需要 Android 10 (API 29) 或更高版本',
                                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_availablePlatforms.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '健康平台设置',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<HealthPlatform>(
                          value: _selectedPlatform,
                          isExpanded: true,
                          items: _availablePlatforms
                              .map((platform) => DropdownMenuItem(
                                    value: platform,
                                    child: Text(platform.displayName),
                                  ))
                              .toList(),
                          onChanged: (platform) {
                            setState(() {
                              _selectedPlatform = platform;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(_initStatus),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _selectedPlatform != null ? _initializeHealthPlatform : null,
                          child: const Text('初始化所选平台'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '步数数据',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(_stepsData),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _selectedPlatform != null ? _getTodaySteps : null,
                          child: const Text('获取今日步数'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '指定日期的步数',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _selectDate,
                                icon: const Icon(Icons.calendar_today),
                                label: Text(_selectedDate.toString().split(' ')[0]),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _selectedPlatform != null ? _getStepsForDate : null,
                                child: const Text('获取步数'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_dateStepsData),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '日期范围步数',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _selectDateRange,
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  '${_rangeStartDate.toString().split(' ')[0]} - ${_rangeEndDate.toString().split(' ')[0]}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _selectedPlatform != null ? _getStepsForDateRange : null,
                                child: const Text('获取范围步数'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_rangeStepsData),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '连接管理',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _disconnect,
                          icon: const Icon(Icons.logout),
                          label: const Text('断开所有健康平台连接'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[400],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
    );
  }
}

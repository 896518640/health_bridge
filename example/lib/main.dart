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
  DateTime _selectedDate = DateTime.now();

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
      final result = await HealthBridge.readStepCountForDate(
        date: _selectedDate,
        platform: _selectedPlatform!,
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
              ],
            ],
          ),
        ),
    );
  }
}

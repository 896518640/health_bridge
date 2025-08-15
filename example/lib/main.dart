import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:dnurse_health_plugin/dnurse_health_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  List<HealthPlatform> _availablePlatforms = [];
  HealthPlatform? _selectedPlatform;
  String _initStatus = 'Not initialized';
  String _stepsData = 'No steps data';
  String _dateStepsData = 'No date steps data';
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
      platformVersion = await DnurseHealthPlugin.getPlatformVersion() ?? 'Unknown platform version';
      platforms = await DnurseHealthPlugin.getAvailableHealthPlatforms();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
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
      final result = await DnurseHealthPlugin.initializeHealthPlatform(_selectedPlatform!);
      setState(() {
        if (result.isSuccess) {
          _initStatus = 'Platform ${_selectedPlatform!.displayName} initialized successfully';
        } else {
          _initStatus = result.message ?? 'Failed to initialize platform';
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _initStatus = 'Failed to initialize: ${e.message}';
      });
    }
  }

  Future<void> _getTodaySteps() async {
    if (_selectedPlatform == null) return;
    
    try {
      final result = await DnurseHealthPlugin.readStepCount(platform: _selectedPlatform!);
      setState(() {
        if (result.isSuccess) {
          final totalSteps = result.totalCount;
          _stepsData = 'Today\'s steps: $totalSteps';
        } else {
          _stepsData = result.message ?? 'Failed to get steps data';
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _stepsData = 'Failed to get steps: ${e.message}';
      });
    }
  }

  Future<void> _getStepsForDate() async {
    if (_selectedPlatform == null) return;
    
    try {
      final result = await DnurseHealthPlugin.readStepCountForDate(
        date: _selectedDate,
        platform: _selectedPlatform!,
      );
      setState(() {
        if (result.isSuccess) {
          final totalSteps = result.totalCount;
          final dateStr = _selectedDate.toString().split(' ')[0]; // 只显示日期部分
          _dateStepsData = 'Steps on $dateStr: $totalSteps';
        } else {
          _dateStepsData = result.message ?? 'Failed to get steps data for selected date';
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _dateStepsData = 'Failed to get steps for date: ${e.message}';
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
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('DNurse Health Plugin Demo'),
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
                        'Platform Info',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Running on: $_platformVersion'),
                      const SizedBox(height: 8),
                      Text('Available platforms: ${_availablePlatforms.map((p) => p.displayName).join(', ')}'),
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
                          'Health Platform Setup',
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
                          child: const Text('Initialize Selected Platform'),
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
                          'Steps Data',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(_stepsData),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _selectedPlatform != null ? _getTodaySteps : null,
                          child: const Text('Get Today\'s Steps'),
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
                          'Steps for Specific Date',
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
                                child: const Text('Get Steps'),
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
      ),
    );
  }
}

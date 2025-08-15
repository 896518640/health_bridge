Pod::Spec.new do |s|
  s.name             = 'dnurse_health_plugin'
  s.version          = '1.0.0'
  s.summary          = 'Multi-platform health data integration plugin for DNurse'
  s.description      = <<-DESC
A Flutter plugin that provides unified access to health data across multiple platforms:
- Samsung Health (Android)
- Apple Health (iOS)
- Google Fit (Android)
- Huawei Health (Android)
                       DESC
  s.homepage         = 'https://www.dnurse.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'DNurse Team' => 'dev@dnurse.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  
  # HealthKit framework dependency
  s.frameworks = ['HealthKit']
end
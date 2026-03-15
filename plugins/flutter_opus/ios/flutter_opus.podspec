Pod::Spec.new do |s|
  s.name             = 'flutter_opus'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project that provides Opus decoding using FFI.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }

  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '12.0'
  s.ios.deployment_target = '12.0'

  s.dependency 'Flutter'

  # Use XCFramework to support both physical devices and simulators
  s.vendored_frameworks = 'lib/libopus.xcframework'
  s.preserve_paths = 'include/*/'
  
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/include',
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-all_load'
  }

  s.swift_version = '5.0'
end
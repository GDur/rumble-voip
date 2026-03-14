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

  # 简单直接的配置
  s.vendored_libraries = 'lib/libopus.a'
  s.preserve_paths = 'include/*/'
  
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/include',
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load $(PODS_TARGET_SRCROOT)/lib/libopus.a'
  }

  s.swift_version = '5.0'
end
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
  s.platform         = :osx, '10.14'
  s.osx.deployment_target = '10.14'

  s.dependency 'FlutterMacOS'

  # 静态库和头文件
  s.vendored_libraries = 'lib/libopus.a'
  s.preserve_paths = 'include/**'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '$(PODS_TARGET_SRCROOT)/include',
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load $(PODS_TARGET_SRCROOT)/lib/libopus.a'
  }

  s.swift_version = '5.0'
end

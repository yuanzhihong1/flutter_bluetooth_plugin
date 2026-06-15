#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_bluetooth_plugin.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_bluetooth_plugin'
  s.version          = '0.0.1'
  s.summary          = 'Native Android and iOS Bluetooth APIs for Flutter.'
  s.description      = <<-DESC
Flutter Bluetooth plugin backed by CoreBluetooth on iOS and native Bluetooth APIs on Android.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'flutter_bluetooth_plugin/Sources/flutter_bluetooth_plugin/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'flutter_bluetooth_plugin_privacy' => ['flutter_bluetooth_plugin/Sources/flutter_bluetooth_plugin/PrivacyInfo.xcprivacy']}
end

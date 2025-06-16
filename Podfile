# Uncomment the next line to define a global platform for your project
platform :ios, '15'

target 'MW Watcher' do
    # Comment the next line if you don't want to use dynamic frameworks
    use_frameworks!

    # Pods for MW Watcher
    pod 'SwiftSoup'
    pod 'SwiftyOnboard'
#    pod 'AMPopTip'
    pod 'Firebase/Analytics'
    pod 'Firebase/Crashlytics'
    pod 'DGCharts'
    pod 'TinyConstraints'
    pod 'SwiftyJSON', '~> 4.0'


post_install do |installer|
      installer.pods_project.targets.each do |target|
          target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
          xcconfig_path = config.base_configuration_reference.real_path
          xcconfig = File.read(xcconfig_path)
          xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
          File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
          end
      end
  end

end

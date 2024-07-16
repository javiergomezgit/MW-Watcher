# Uncomment the next line to define a global platform for your project
platform :ios, '14.5'

target 'MW Watcher' do
    # Comment the next line if you don't want to use dynamic frameworks
    use_frameworks!

    # Pods for MW Watcher
    pod 'SwiftSoup'
    pod 'SwiftyOnboard'
    pod 'AMPopTip'
    pod 'Firebase/Analytics'
    pod 'Firebase/Crashlytics'
    #pod 'Charts'
    # pod 'Charts', :git => 'https://github.com/danielgindi/Charts.git', :branch => 'master'
    pod 'DGCharts'
#    pod 'ChartsRealm'
    pod 'TinyConstraints'
    pod 'SwiftyJSON', '~> 4.0'


    # post_install do |installer|
    #     installer.generated_projects.each do |project|
    #           project.targets.each do |target|
    #               target.build_configurations.each do |config|
    #                   config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    #                end
    #           end
    #    end
    # end

post_install do |installer|
      installer.pods_project.targets.each do |target|
          target.build_configurations.each do |config|
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
          xcconfig_path = config.base_configuration_reference.real_path
          xcconfig = File.read(xcconfig_path)
          xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
          File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
          end
      end
  end

end

target 'WidgetExtension' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'SwiftSoup'

end

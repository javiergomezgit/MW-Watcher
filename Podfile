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

    post_install do |installer|
        installer.generated_projects.each do |project|
              project.targets.each do |target|
                  target.build_configurations.each do |config|
                      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
                   end
              end
       end
    end

end

target 'WidgetExtension' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'SwiftSoup'

end

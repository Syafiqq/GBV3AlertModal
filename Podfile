source 'https://bitbucket.org/beautyfu/ios-pod-specs.git'
source 'https://cdn.cocoapods.org/'

workspace 'GBV3AlertModal'
# Uncomment the next line to define a global platform for your project

def dev_pods
  pod 'SwiftLint', '~> 0.51'
end

def lib_pods
  pod 'LanguageManager-iOS', '~> 1.2.6-beta.2'
  pod 'SnapKit', '~> 5.6'
end

def lib_test_pods
  pod 'Cuckoo', '~> 1.10'
  pod 'Quick', '~> 6.1'
  pod 'Nimble', '~> 12.0'
end

def example_lib_pods
  pod 'GBV3AlertModal', :path => './'
end

target 'GBV3AlertModal' do
  project 'Sources/GBV3AlertModal/GBV3AlertModal.xcodeproj'
  platform :ios, '13.0'

  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for GBV3AlertModal
  dev_pods

  lib_pods

  target 'GBV3AlertModalTests' do
    platform :ios, '13.0'

    inherit! :complete
    # Pods for testing

    lib_test_pods
  end
end

target 'GBV3AlertModalExample' do
  project 'Examples/GBV3AlertModalExample/GBV3AlertModalExample.xcodeproj'
  platform :ios, '13.0'

  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for GBV3AlertModalExample
  example_lib_pods

  target 'GBV3AlertModalExampleTests' do
    platform :ios, '13.0'

    inherit! :search_paths
    # Pods for testing

    lib_test_pods
  end

  target 'GBV3AlertModalExampleUITests' do
    # Pods for testing
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |t|
    t.build_configurations.each do |config|
      case t.name
      when "Cuckoo", "Quick", "Nimble"
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      else
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end
end

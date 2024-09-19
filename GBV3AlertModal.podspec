Pod::Spec.new do |s|
  s.name                    = "GBV3AlertModal"
  s.version                 = "3.0.1"
  s.summary                 = "Summary"
  s.description             = <<-DESC
General Multipurpose Alert Modal
                            DESC
  s.homepage                = "https://geniebook.com"
  s.license                 = 'MIT'
  s.author                  = { "Geniebook" => "developer@geniebook.com" }
  s.source                  = { :git => "https://bitbucket.org/beautyfu/ios-gb-v3-alert-modal.git", :tag => s.version.to_s }

  s.requires_arc            = true

  s.ios.deployment_target   = '13.0'

  s.source_files            = 'Sources/GBV3AlertModal/GBV3AlertModal/**/*.swift'

  s.swift_version = '5.6'

  s.dependency 'LanguageManager-iOS', '~> 1.2.9-beta.1'
  s.dependency 'SnapKit', '~> 5.7'
end

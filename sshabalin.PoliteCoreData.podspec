Pod::Spec.new do |s|

    s.name             = 'sshabalin.HTTPClient'
    s.version          = '1.0.0'
    s.summary          = 'PoliteCoreData client for iOS'
    s.homepage         = 'https://github.com/shakurocom/PoliteCoreData'
    s.license          = { :type => "MIT", :file => "LICENSE.md" }
    s.authors          = {'sshabalin1984' => 'sshabalin@shakuro.com', 'sshabalin' => 'sshabalin@shakuro.com'}
    s.source           = { :git => 'https://github.com/sshabalin/PoliteCoreData.git', :tag => s.version }
    s.swift_versions   = ['5.1', '5.2', '5.3', '5.4']
    s.source_files     = 'Source/*'
    s.ios.deployment_target = '10.0'
  
end

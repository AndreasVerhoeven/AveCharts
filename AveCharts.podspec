Pod::Spec.new do |s|
    s.name             = 'AveCharts'
    s.version          = '1.0.0'
    s.summary          = 'A collection of common swift helpers'
    s.homepage         = 'https://github.com/AndreasVerhoeven/AveCharts'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Andreas Verhoeven' => 'cocoapods@aveapps.com' }
    s.source           = { :git => 'https://github.com/AndreasVerhoeven/AveCharts.git', :tag => s.version.to_s }
    s.module_name      = 'AveCharts'

    s.swift_versions = ['5.5']
    s.ios.deployment_target = '13.0'
    s.source_files = 'Sources/*.swift'
    
    s.dependency 'AveCommonHelperViews'
    s.dependency 'AutoLayoutConvenience'
    s.dependency 'AveDataSource'
    s.dependency 'GeometryHelpers'
    s.dependency 'UIKitAnimations'
    
end

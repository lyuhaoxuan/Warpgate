Pod::Spec.new do |s|
  s.name             = 'Warpgate'
  s.version          = '0.1.2'
  s.summary          = 'Warpgate 空间之门'

  s.description      = <<-DESC
TODO: 作用于 APP 的路由相关。
                       DESC

  s.homepage         = 'https://github.com/confidenthaoxuan/Warpgate'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { '吕浩轩' => 'lyuhaoxuan@aliyun.com' }
  s.source           = { :git => 'https://github.com/confidenthaoxuan/Warpgate.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'

  s.source_files = 'Warpgate/Classes/**/*'
  
  # s.resource_bundles = {
  #   'Warpgate' => ['Warpgate/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
end

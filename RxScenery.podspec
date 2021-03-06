Pod::Spec.new do |s|
  s.name             = 'RxScenery'
  s.version          = '1.1.2'
	s.summary 				 = 'Scene transition library written in Swift'
  s.homepage         = 'https://github.com/martindaum/RxScenery'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'martindaum' => 'office@martindaum.com' }
  s.source           = { :git => 'https://github.com/martindaum/RxScenery.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.swift_version = '5.0'
  s.source_files = 'RxScenery/Classes/**/*'
  
  s.dependency 'RxCocoa', '~> 6.0'
end

Pod::Spec.new do |spec|
    spec.name             = 'MBDocCapture'
    spec.version          = '0.1.2'
    spec.summary          = 'MBDocCapture makes it easy to add document scanning functionalities to your iOS.'
    
    spec.description      = <<-DESC
    MBDocCapture makes it easy to add document scanning functionalities to your iOS app but also image editing (Cropping and contrast enhacement).
    DESC
    
    
    spec.ios.deployment_target = '10.0'
    
    spec.homepage         = 'https://github.com/iMhdi/MBDocCapture'
    spec.swift_version    = '4.2'
    spec.license          = { :type => 'MIT', :file => 'LICENSE' }
    spec.author           = { 'El Mahdi BOUKHRIS' => 'm.boukhris@gmail.com' }
    spec.source           = { :git => 'https://github.com/iMhdi/MBDocCapture.git', :tag => spec.version.to_s }
    
    spec.source_files = 'MBDocCapture/Classes/**/*'
    spec.resources = 'MBDocCapture/**/*.{strings,png}'
    
    spec.frameworks = 'CoreGraphics', 'CoreImage'
end

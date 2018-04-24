Pod::Spec.new do |s|
  s.name         = "ZipUtilities"
  s.version      = "1.11.0"
  s.summary      = "Zip Archiving, Unarchiving and Utilities in Objective-C"
  s.description  = <<-DESC
					ZipUtilities, prefixed with NOZ for Nolan O'Brien ZipUtilities, is a library of zipping and unzipping utilities for iOS and Mac OS X.
                   DESC
  s.homepage     = "https://github.com/NSProgrammer/ZipUtilities"
  s.license      = { :type => "MIT", :file => "LICENSE" }
  s.author       = "Nolan O'Brien"
  s.social_media_url = "https://twitter.com/NolanOBrien"
  s.ios.deployment_target = "6.0"
  s.osx.deployment_target = "10.9"
  s.source        = { :git => "https://github.com/NSProgrammer/ZipUtilities.git", :tag => s.version }
  s.source_files  = "ZipUtilities/*.{h,m}"
  s.exclude_files = "ZipUtilities/ZipUtilities.h", "ZipUtilities/*Info.plist"
  s.library       = "z"
  s.requires_arc  = true
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wasd/version'

Gem::Specification.new do |spec|
  spec.name          = "wasd"
  spec.version       = Wasd::VERSION
  spec.authors       = ["Dan Brown"]
  spec.email         = ["dan@madebymany.co.uk"]
  spec.summary       = %q{Unicast DNS-SD client}
  spec.description   = %q{A client for an RFC 6763 compliant service-discovery platform. }
  spec.homepage      = "https://github.com/madebymany/ruby-wasd"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end

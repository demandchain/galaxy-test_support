# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'galaxy/test_support/version'

Gem::Specification.new do |spec|
  spec.name          = "galaxy-test_support"
  spec.version       = Galaxy::TestSupport::VERSION
  spec.authors       = ["RealNobody"]
  spec.email         = ["Erik.Littell@Deem.com"]
  spec.description   = %q{This gem provides some diagnostic tools and supporting code that I think will be useful for
 finding and diagnosing bugs and issues in tests.}
  spec.summary       = %q{A gem for providing common diagnostic and testing tools for galaxy projects.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end

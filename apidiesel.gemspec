# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'apidiesel/version'

Gem::Specification.new do |spec|
  spec.name          = "apidiesel"
  spec.version       = Apidiesel::VERSION
  spec.authors       = ["Jan-Christian Foeh"]
  spec.email         = ["jan@programmanstalt.de"]

  spec.summary       = %q{Build API clients through an expressive DSL}
  spec.homepage      = "https://github.com/janfoeh/apidiesel"
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '~> 2.0'

  spec.add_runtime_dependency "activesupport", ">= 5.2.6", "< 7"
  spec.add_runtime_dependency "activemodel", ">= 5.2.6", "< 7"
  spec.add_runtime_dependency 'httpi', '>= 2.4.1'

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "rspec-collection_matchers", "~> 1.2.0"
  spec.add_development_dependency "yard", "~> 0.8"
  spec.add_development_dependency "pry", "~> 0.13"
  spec.add_development_dependency 'pry-byebug', '~> 3.9'
  spec.add_development_dependency 'pry-rescue', '~> 1.4'
  spec.add_development_dependency 'pry-stack_explorer', '~> 0.6'
end

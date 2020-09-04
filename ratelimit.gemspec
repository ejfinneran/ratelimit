# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ratelimit/version'

Gem::Specification.new do |spec|
  spec.name          = "ratelimit"
  spec.version       = Ratelimit::VERSION
  spec.authors       = ["E.J. Finneran"]
  spec.email         = ["ej.finneran@gmail.com"]
  spec.summary       = "Rate limiting backed by redis"
  spec.description   = "This library uses Redis to track the number of actions for a given subject over a flexible time frame."
  spec.homepage      = "https://github.com/ejfinneran/ratelimit"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency             "redis", ">= 2.0.0"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "fakeredis"
  spec.add_development_dependency "timecop"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "maruku"
  spec.add_development_dependency "rdoc"
end

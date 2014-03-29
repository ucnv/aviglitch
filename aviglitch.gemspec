# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aviglitch'

Gem::Specification.new do |spec|
  spec.name          = "aviglitch"
  spec.version       = AviGlitch::VERSION
  spec.authors       = ["ucnv"]
  spec.email         = ["ucnvvv@gmail.com"]
  spec.description   = %q{AviGlitch to destroys your AVI files.
    This library provides ways to manipulate data in each AVI frames.
    It can easily generate keyframes-removed video known as "datamoshing".
  }
  spec.summary       = %q{A Ruby library to destroy your AVI files.}
  spec.homepage      = "http://ucnv.github.com/aviglitch/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", ">= 2.0.0"
  spec.add_development_dependency "rspec"
end

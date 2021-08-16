# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'aviglitch'

Gem::Specification.new do |spec|
  spec.name          = "aviglitch"
  spec.version       = AviGlitch::VERSION
  spec.authors       = ["ucnv"]
  spec.email         = ["ucnvvv@gmail.com"]
  spec.summary       = %q{A Ruby library to destroy your AVI files.}
  spec.description   = spec.summary
  spec.homepage      = "http://ucnv.github.com/aviglitch/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.has_rdoc = true
  spec.extra_rdoc_files = ["README.md", "LICENSE"]
  spec.rdoc_options << "-m" << "README.md"

  spec.add_development_dependency "bundler", ">= 2.2.10"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec"
end

# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{aviglitch}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["ucnv"]
  s.date = %q{2009-08-02}
  s.default_executable = %q{datamosh}
  s.email = %q{ucnvvv@gmail.com}
  s.executables = ["datamosh"]
  s.extra_rdoc_files = [
    "ChangeLog",
     "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    "ChangeLog",
     "README.rdoc",
     "Rakefile",
     "VERSION",
     "bin/datamosh",
     "lib/aviglitch.rb",
     "lib/aviglitch/frame.rb",
     "lib/aviglitch/frames.rb",
     "spec/aviglitch_spec.rb",
     "spec/files/sample.avi",
     "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/ucnv/aviglitch}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.4}
  s.summary = %q{A Ruby library to destroy your AVI files.}
  s.test_files = [
    "spec/aviglitch_spec.rb",
     "spec/spec_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

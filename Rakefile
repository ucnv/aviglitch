require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  rdoc.main = "README.md"
  rdoc.rdoc_dir = 'rdoc'
  rdoc.rdoc_files.include(%w{LICENSE *.md lib/**/*.rb})
end

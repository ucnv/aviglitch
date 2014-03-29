require 'rspec'
require 'aviglitch'
require 'pathname'
require 'fileutils'

FILES_DIR = Pathname.new(File.dirname(__FILE__)).realpath + 'files'
OUTPUT_DIR = FILES_DIR + 'output'

RSpec.configure do |config|
  config.filter_run_excluding :skip => true
end

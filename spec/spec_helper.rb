require 'spec'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'aviglitch'
require 'pathname'
require 'fileutils'

FILES_DIR = Pathname.new(File.dirname(__FILE__)).realpath + 'files'
OUTPUT_DIR = FILES_DIR + 'output'

Spec::Runner.configure do |config|
  
end

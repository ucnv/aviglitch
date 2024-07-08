require 'rspec'
require 'aviglitch'
require 'pathname'
require 'fileutils'
require 'net/http'

FILES_DIR = Pathname.new(File.dirname(__FILE__)).realpath + 'files'
OUTPUT_DIR = FILES_DIR + 'output'

RSpec.configure do |config|
  config.filter_run_excluding :skip => true
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.before(:all) do
    FileUtils.mkdir FILES_DIR unless File.exist? FILES_DIR
    FileUtils.mkdir OUTPUT_DIR unless File.exist? OUTPUT_DIR
    @in = FILES_DIR + 'sample1.avi'
    @in2 = FILES_DIR + 'sample2.avi'
    @out = OUTPUT_DIR + 'out.avi'
    [
      [@in2, 'http://a.ucnv.org/sample2.avi'], [@in, 'http://a.ucnv.org/sample1.avi']
    ].each do |file, url|
      unless File.exist? file
        if file == @in2
          puts 'At first test it needs to download a file over 1GB. It will take a while.'
        end
        puts 'Downloading ' + url
        $stdout.sync = true
        u = URI.parse url
        Net::HTTP.start(u.host, u.port) do |http|
          res = http.request_head u.path
          max = res['content-length'].to_i
          len = 0
          bl = 75
          File.open(file, 'w') do |file|
            http.get(u.path) do |chunk|
              file.write chunk
              len += chunk.length
              pct = '%3.1f' % (100.0 * len / max)
              bar = ('#' * (bl * len / max)).ljust(bl)
              print "\r#{bar} #{'%5s' % pct}%" unless ENV['CI']
            end
          end
        end
        puts
      end
    end
  end

  config.after(:each) do
    begin
      FileUtils.rm_r Dir.glob((OUTPUT_DIR + '*').to_s)
    rescue => e
      # Sometimes windows can't remove files.
    end
  end
end

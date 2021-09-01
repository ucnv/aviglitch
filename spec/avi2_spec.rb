require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AviGlitch, 'AVI2.0' do

  before :all do
    FileUtils.mkdir OUTPUT_DIR unless File.exist? OUTPUT_DIR
    @in1 = FILES_DIR + 'sample.avi'
    @in2 = FILES_DIR + 'sample2.avi'
    @out = OUTPUT_DIR + 'out.avi'

    url = 'http://a.ucnv.org/sample2.avi'
    unless File.exist? @in2
      puts 'At first test it needs to download a file over 1GB. It will take a while.'
      puts 'Downloading ' + url
      $stdout.sync = true
      u = URI.parse url
      Net::HTTP.start(u.host, u.port) do |http|
        res = http.request_head u.path
        max = res['content-length'].to_i
        len = 0
        bl = 75
        File.open(@in2, 'w') do |file|
          http.get(u.path) do |chunk|
            file.write chunk
            len += chunk.length
            pct = '%3.1f' % (100.0 * len / max)
            bar = ('#' * (bl * len / max)).ljust(bl)
            print "\r#{bar} #{'%5s' % pct}%"
          end
        end
      end
      puts
    end
  end

  after :each do
    FileUtils.rm Dir.glob((OUTPUT_DIR + '*').to_s)
  end

  it 'should save same file when nothing has changed' do
    avi = AviGlitch.open @in2
    avi.glitch do |d|
      d
    end
    avi.output @out
    FileUtils.cmp(@in2, @out).should be true
  end

  it 'should be AVI1.0 when its size has reduced less than 1GB' do
    a = AviGlitch.open @in2
    size = 0
    a.glitch do |d|
      size += d.size
      size < 1024 ** 3 ? d : nil
    end
    a.output @out
    b = AviGlitch.open @out
    b.avi.was_avi2?.should be false
    b.close
  end

  it 'should be AVI2.0 when its size has increased over 1GB' do
    a = AviGlitch.open @in1
    n = 1
    while a.frames.data_size * n < 1024 ** 3
      n += 1
    end
    f = a.frames[0..-1]
    n.times do
      f.concat a.frames
    end
    f.to_avi.output @out
    b = AviGlitch.open @out
    b.avi.was_avi2?.should be true
    b.close
  end
end
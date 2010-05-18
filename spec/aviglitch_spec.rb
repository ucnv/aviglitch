require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AviGlitch do

  before :all do
    FileUtils.mkdir OUTPUT_DIR unless File.exist? OUTPUT_DIR
    @in = FILES_DIR + 'sample.avi'
    @out = OUTPUT_DIR + 'out.avi'
  end

  after :each do
    FileUtils.rm Dir.glob((OUTPUT_DIR + '*').to_s)
  end

  after :all do
    FileUtils.rmdir OUTPUT_DIR
  end

  it 'raise an error against unsupported files' do
    lambda {
      avi = AviGlitch.open __FILE__
    }.should raise_error
  end

  it 'returns AviGlitch::Base object through the method #open' do
    avi = AviGlitch.open @in
    avi.should be_kind_of AviGlitch::Base
  end

  it 'saves the same file when nothing is changed' do
    avi = AviGlitch.open @in
    avi.glitch do |d|
      d
    end
    avi.output @out
    FileUtils.cmp(@in, @out).should be true
  end

  it 'can glitch each keyframe' do
    avi = AviGlitch.open @in
    n = 0
    avi.glitch :keyframe do |kf|
      n += 1
      kf.slice(10..kf.size)
    end
    avi.output @out
    i_size = File.stat(@in).size
    o_size = File.stat(@out).size
    o_size.should == i_size - (10 * n)
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can glitch each keyframe with index' do
    avi = AviGlitch.open @in
    avi.glitch_with_index :keyframe do |kf, idx|
      if idx < 25
        kf.slice(10..kf.size)
      else
        kf
      end
    end
    avi.output @out
    i_size = File.stat(@in).size
    o_size = File.stat(@out).size
    o_size.should == i_size - (10 * 25)
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'has some alias methods' do
    lambda {
      avi = AviGlitch.open @in
      avi.write @out
    }.should_not raise_error
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can glitch with :*frames instead of :*frame' do
    avi = AviGlitch.open @in
    count = 0
    avi.glitch :keyframes do |kf|
      count += 1
      kf
    end
    avi.close
    count.should > 0
  end

  it 'should close file when output' do
    avi = AviGlitch.open @in
    avi.output @out
    lambda {
      avi.glitch do |f|
        f
      end
    }.should raise_error(IOError)
  end

  it 'can explicit close file' do
    avi = AviGlitch.open @in
    avi.close
    lambda {
      avi.glitch do |f|
        f
      end
    }.should raise_error(IOError)
  end

  it 'offers one liner style coding' do
    lambda {
      AviGlitch.open(@in).glitch(:keyframe){|d| '0' * d.size}.output(@out)
    }.should_not raise_error
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end
end

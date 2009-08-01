require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AviGlitch do

  before :all do
    FileUtils.mkdir OUTPUT_DIR unless File.exist? OUTPUT_DIR
    @in = FILES_DIR + 'sample.avi'
    @out = OUTPUT_DIR + 'out.avi'
  end

  after :each do
    FileUtils.rm Dir.glob(OUTPUT_DIR + '*')
  end

  after :all do
    FileUtils.rmdir OUTPUT_DIR
  end

  it 'raise an error against unsupported files' do
    lambda {
      avi = AviGlitch.new __FILE__
    }.should raise_error
  end

  it 'saves the same file when nothing is changed' do
    avi = AviGlitch.new @in
    avi.frames.each do |f|
      ;
    end
    avi.write @out
    FileUtils.cmp(@in, @out).should be true

    avi = AviGlitch.new @in
    avi.glitch do |d|
      d
    end
    avi.write @out
    FileUtils.cmp(@in, @out).should be true
  end

  it 'can manipulate each frame' do
    avi = AviGlitch.new @in
    f = avi.frames
    f.should be_kind_of Enumerable
    avi.frames.each do |f|
      if f.is_keyframe?
        f.data = f.data.gsub(/\d/, '0')
      end
    end
    avi.write @out
    AviGlitch.surely_formatted?(@out, true).should be true
  end

  it 'can glitch each keyframe' do
    avi = AviGlitch.new @in
    n = 0
    avi.glitch :keyframe do |kf|
      n += 1
      kf.slice(10..kf.size)
    end
    avi.write @out
    i_size = File.stat(@in).size
    o_size = File.stat(@out).size
    o_size.should == i_size - (10 * n)
    AviGlitch.surely_formatted?(@out, true).should be true
  end

  it 'can glitch each keyframe with index' do
    avi = AviGlitch.new @in
    avi.glitch_with_index :keyframe do |kf, idx|
      if idx < 25
        kf.slice(10..kf.size)
      else
        kf
      end
    end
    avi.write @out
    i_size = File.stat(@in).size
    o_size = File.stat(@out).size
    o_size.should == i_size - (10 * 25)
    AviGlitch.surely_formatted?(@out, true).should be true
  end

  it 'can remove a frame with returning nil' do
    avi = AviGlitch.new @in
    in_frame_size = avi.frames.size
    rem_count = 0
    avi.glitch :keyframe do |kf|
      rem_count += 1
      nil
    end
    avi.write @out
    AviGlitch.surely_formatted?(@out, true).should be true

    # frames length in the output file is correct
    avi = AviGlitch.new @out
    out_frame_size = avi.frames.size
    out_frame_size.should == in_frame_size - rem_count
  end

  it 'has some alias methods' do
    lambda {
      avi = AviGlitch.open @in
      avi.output @out
    }.should_not raise_error
    AviGlitch.surely_formatted?(@out, true).should be true
  end

end

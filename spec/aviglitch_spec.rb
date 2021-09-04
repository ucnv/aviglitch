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

  it 'should raise an error against unsupported files' do
    lambda {
      avi = AviGlitch.open __FILE__
    }.should raise_error
  end

  it 'should return AviGlitch::Base object through the method #open' do
    avi = AviGlitch.open @in
    avi.should be_kind_of AviGlitch::Base
  end

  it 'should save the same file when nothing is changed' do
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

    a_size = 0
    avi.glitch :keyframe do |f|
      a_size += 1
      f
    end

    b_size = 0
    avi.glitch_with_index :keyframe do |kf, idx|
      b_size += 1
      if idx < 25
        kf.slice(10..kf.size)
      else
        kf
      end
    end
    expect(a_size).to be == b_size

    avi.output @out
    i_size = File.stat(@in).size
    o_size = File.stat(@out).size
    o_size.should == i_size - (10 * 25)
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'should have some alias methods' do
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

  it 'should offer one liner style coding' do
    lambda {
      AviGlitch.open(@in).glitch(:keyframe){|d| '0' * d.size}.output(@out)
    }.should_not raise_error
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'should not raise error in multiple glitches' do
    lambda {
      avi = AviGlitch.open @in
      avi.glitch(:keyframe) do |d|
        d.gsub(/\d/, '')
      end
      avi.glitch(:keyframe) do |d|
        nil
      end
      avi.glitch(:audioframe) do |d|
        d * 2
      end
      avi.output @out
    }.should_not raise_error
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can work with another frames instance' do
    a = AviGlitch.open @in
    a.glitch :keyframe do |d|
      nil
    end
    a.output(@out.to_s + 'x.avi')
    b = AviGlitch.open @in
    c = AviGlitch.open(@out.to_s + 'x.avi')
    b.frames = c.frames
    b.output @out

    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'should mutate keyframes into deltaframes' do
    a = AviGlitch.open @in
    a.mutate_keyframes_into_deltaframes!
    a.output @out
    a = AviGlitch.open @out
    a.frames.each do |f|
      f.is_keyframe?.should be false
    end

    a = AviGlitch.open @in
    a.mutate_keyframes_into_deltaframes! 0..50
    a.output @out
    a = AviGlitch.open @out
    a.frames.each_with_index do |f, i|
      if i <= 50
        f.is_keyframe?.should be false
      end
    end
  end

  it 'should check if keyframes exist.' do
    a = AviGlitch.open @in
    a.has_keyframe?.should be true
    a.glitch :keyframe do |f|
      nil
    end
    a.has_keyframe?.should be false
  end

  it 'should #remove_all_keyframes!' do
    a = AviGlitch.open @in
    a.has_keyframe?.should be true
    a.remove_all_keyframes!
    a.has_keyframe?.should be false
  end

  it 'should count same number of specific frames' do
    a = AviGlitch.open @in
    dc1 = 0
    dc2 = 0
    a.frames.each do |f|
      dc1 += 1 if f.is_deltaframe?
    end
    a.glitch(:deltaframe) do |d|
      dc2 += 1
      d
    end

    expect(dc1).to eq(dc2)
  end
  
end

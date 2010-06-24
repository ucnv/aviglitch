require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AviGlitch::Frames do

  before :all do
    AviGlitch::Frames.class_eval do
      define_method(:get_real_id_with) do |frame|
        pos = @io.pos
        @io.pos -= frame.data.size
        @io.pos -= 8
        id = @io.read 4
        @io.pos = pos
        id
      end
    end

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

  it 'should save the same file when nothing is changed' do
    avi = AviGlitch.open @in
    avi.frames.each do |f|
      ;
    end
    avi.output @out
    FileUtils.cmp(@in, @out).should be true
  end

  it 'can manipulate each frame' do
    avi = AviGlitch.open @in
    f = avi.frames
    f.should be_kind_of Enumerable
    avi.frames.each do |f|
      if f.is_keyframe?
        f.data = f.data.gsub(/\d/, '0')
      end
    end
    avi.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'should remove a frame when returning nil' do
    avi = AviGlitch.open @in
    in_frame_size = avi.frames.size
    rem_count = 0
    avi.glitch :keyframe do |kf|
      rem_count += 1
      nil
    end
    avi.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true

    # frames length in the output file is correct
    avi = AviGlitch.open @out
    out_frame_size = avi.frames.size
    out_frame_size.should == in_frame_size - rem_count
  end

  it 'should read correct positions in #each' do
    avi = AviGlitch.open @in
    frames = avi.frames
    frames.each do |f|
      real_id = frames.get_real_id_with f
      real_id.should == f.id
    end
    avi.close
  end

  it 'should promise the read frame data is not nil' do
    avi = AviGlitch.open @in
    frames = avi.frames
    frames.each do |f|
      f.data.should_not == nil
    end
    avi.close
  end

  it 'should hide the inner variables' do
    avi = AviGlitch.open @in
    frames = avi.frames
    lambda { frames.meta }.should raise_error(NoMethodError)
    lambda { frames.io }.should raise_error(NoMethodError)
    lambda { frames.frames_data_as_io }.should raise_error(NoMethodError)
    avi.close
  end

  it 'should save video frames count in header' do
    avi = AviGlitch.open @in
    c = 0
    avi.frames.each do |f|
      c += 1 if f.is_videoframe?
    end
    avi.output @out
    open(@out) do |f|
      f.pos = 48
      f.read(4).unpack('V').first.should == c
    end
  end

  it 'can generate AviGlitch::Base instance' do
    a = AviGlitch.open @in
    b = a.frames.slice(0, 10)
    c = b.to_avi
    c.should be_kind_of AviGlitch::Base
    c.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can concat with other Frames instance with #concat, destructively' do
    a = AviGlitch.open @in
    b = AviGlitch.open @in
    asize = a.frames.size
    bsize = b.frames.size
    lambda {
      a.frames.concat([1,2,3])
    }.should raise_error(TypeError)
    a.frames.concat(b.frames)
    a.frames.size.should == asize + bsize
    b.frames.size.should == bsize
    a.output @out
    b.close

    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can concat with other Frames instance with +' do
    a = AviGlitch.open @in
    b = AviGlitch.open @in
    asize = a.frames.size
    bsize = b.frames.size
    c = a.frames + b.frames
    a.frames.size.should == asize
    b.frames.size.should == bsize
    c.should be_kind_of AviGlitch::Frames
    c.size.should == asize + bsize
    a.close
    b.close
    d = AviGlitch.open c
    d.output @out

    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can slice frames using start pos and length' do
    avi = AviGlitch.open @in
    a = avi.frames
    asize = a.size
    c = (a.size / 3).floor
    b = a.slice(1, c)
    b.should be_kind_of AviGlitch::Frames
    b.size.should == c
    lambda {
      b.each {|x| x }
    }.should_not raise_error

    a.size.should == asize  # make sure a is not destroyed
    lambda {
      a.each {|x| x }
    }.should_not raise_error

    avi.frames.concat b
    avi.output @out

    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can slice frames using Range' do
    avi = AviGlitch.open @in
    a = avi.frames
    asize = a.size
    c = (a.size / 3).floor
    spos = 3
    range = spos..(spos + c)
    b = a.slice(range)
    b.should be_kind_of AviGlitch::Frames
    b.size.should == c
    lambda {
      b.each {|x| x }
    }.should_not raise_error
  end

  it 'can concat repeatedly the same sliced frames' do
    a = AviGlitch.open @in
    b = a.frames.slice(0, 5)
    c = a.frames.slice(0, 10)
    10.times do
      b.concat(c)
    end
    b.size.should == 5 + (10 * 10)
  end

  it 'should implement other Array like methods' do
    # slice(n) slice! at first last push insert << delete_at [] ...
    pending("later") {
      violate "not implemented."
    }
  end

end

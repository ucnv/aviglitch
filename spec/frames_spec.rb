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

  it 'should evaluate the equality with owned contents' do
    a = AviGlitch.open @in
    b = AviGlitch.open @in
    a.frames.should == b.frames
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
    b.size.should == c + 1
    lambda {
      b.each {|x| x }
    }.should_not raise_error

    range = spos..-1
    d = a.slice(range)
    d.should be_kind_of AviGlitch::Frames
    d.size.should == asize - spos
    lambda {
      d.each {|x| x }
    }.should_not raise_error

    x = -5
    range = spos..x
    e = a.slice(range)
    e.should be_kind_of AviGlitch::Frames
    e.size.should == asize - spos + x + 1
    lambda {
      e.each {|x| x }
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

  it 'can get one single frame using slice(n)' do
    a = AviGlitch.open @in
    pos = 10
    b = nil
    a.frames.each_with_index do |f, i|
      b = f if i == pos
    end
    c = a.frames.slice(pos)
    c.should be_kind_of AviGlitch::Frame
    c.data.should == b.data
  end

  it 'can get one single frame using at(n)' do
    a = AviGlitch.open @in
    pos = 10
    b = nil
    a.frames.each_with_index do |f, i|
      b = f if i == pos
    end
    c = a.frames.at(pos)
    c.should be_kind_of AviGlitch::Frame
    c.data.should == b.data
  end

  it 'can get a first frame ussing first, a last frame using last' do
    a = AviGlitch.open @in
    b0 = c0 = nil
    a.frames.each_with_index do |f, i|
      b0 = f if i == 0
      c0 = f if i == a.frames.size - 1
    end
    b1 = a.frames.first
    c1 = a.frames.last

    b1.data.should == b0.data
    c1.data.should == c0.data
  end

  it 'can add a frame at last using push' do
    a = AviGlitch.open @in
    s = a.frames.size
    b = a.frames[10]
    lambda {
      a.frames.push 100
    }.should raise_error(TypeError)
    c = a.frames + a.frames.slice(10, 1)

    x = a.frames.push b
    a.frames.size.should == s + 1
    x.should == a.frames
    a.frames.should == c
    a.frames.last.data.should == c.last.data
    x = a.frames.push b
    a.frames.size.should == s + 2
    x.should == a.frames

    a.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can add a frame at last using <<' do
    a = AviGlitch.open @in
    s = a.frames.size
    b = a.frames[10]

    x = a.frames << b
    a.frames.size.should == s + 1
    x.should == a.frames

    a.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can delete all frames using clear' do
    a = AviGlitch.open @in
    a.frames.clear
    a.frames.size.should == 0
  end

  it 'can delete one frame using delete_at' do
    a = AviGlitch.open @in
    l = a.frames.size
    b = a.frames[10]
    c = a.frames[11]
    x = a.frames.delete_at 10

    x.data.should == b.data
    a.frames[10].data.should == c.data
    a.frames.size.should == l - 1

    a.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can insert one frame into other frames using insert' do
    a = AviGlitch.open @in
    l = a.frames.size
    b = a.frames[10]
    x = a.frames.insert 5, b

    x.should == a.frames
    a.frames[5].data.should == b.data
    a.frames[11].data.should == b.data
    a.frames.size.should == l + 1

    a.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'can slice frames destructively using slice!' do
    a = AviGlitch.open @in
    l = a.frames.size

    b = a.frames.slice!(10)
    b.should be_kind_of AviGlitch::Frame
    a.frames.size.should == l - 1

    c = a.frames.slice!(0, 10)
    c.should be_kind_of AviGlitch::Frames
    a.frames.size.should == l - 1 - 10

    d = a.frames.slice!(0..9)
    d.should be_kind_of AviGlitch::Frames
    a.frames.size.should == l - 1 - 10 - 10
  end

  it 'can swap frame(s) using []=' do
    a = AviGlitch.open @in
    l = a.frames.size
    lambda {
      a.frames[10] = "xxx"
    }.should raise_error(TypeError)

    b = a.frames[20]
    a.frames[10] = b
    a.frames.size.should == l
    a.frames[10].data.should == b.data

    a.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true

    a = AviGlitch.open @in
    pl = 5
    pp = 3
    b = a.frames[20, pl]
    a.frames[10..(10 + pp)] = b
    a.frames.size.should == l - pp + pl - 1
    pp.times do |i|
      a.frames[10 + i].data.should == b[i].data
    end

    lambda {
      a.frames[10] = a.frames.slice(100, 1)
    }.should raise_error(TypeError)

    a.output @out
    AviGlitch::Base.surely_formatted?(@out, true).should be true
  end

  it 'should manipulate frames like array does' do
    avi = AviGlitch.open @in
    a = avi.frames
    x = Array.new a.size

    fa = a.slice(0, 100)
    fx = x.slice(0, 100)
    fa.size.should == fx.size

    fa = a.slice(100..-1)
    fx = x.slice(100..-1)
    fa.size.should == fx.size

    fa = a.slice(100..-10)
    fx = x.slice(100..-10)
    fa.size.should == fx.size

    fa = a.slice(-200, 10)
    fx = x.slice(-200, 10)
    fa.size.should == fx.size

    a[100] = a.at 200
    x[100] = x.at 200
    a.size.should == x.size

    a[100..150] = a.slice(100, 100)
    x[100..150] = x.slice(100, 100)
    a.size.should == x.size
  end

  it 'should have the method alias to slice as []' do
    a = AviGlitch.open @in

    b = a.frames[10]
    b.should be_kind_of AviGlitch::Frame

    c = a.frames[0, 10]
    c.should be_kind_of AviGlitch::Frames
    c.size.should == 10

    d = a.frames[0..9]
    d.should be_kind_of AviGlitch::Frames
    d.size.should == 10
  end


end

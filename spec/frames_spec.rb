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

  it 'saves the same file when nothing is changed' do
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

  it 'should remove a frame with returning nil' do
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
end

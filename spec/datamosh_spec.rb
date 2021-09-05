require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AviGlitch, 'datamosh cli' do

  before :all do
    here = File.dirname(__FILE__)
    lib = Pathname.new(File.join(here, '..', 'lib')).realpath
    datamosh = Pathname.new(File.join(here, '..', 'bin/datamosh')).realpath
    @cmd = "ruby -I%s %s -o %s " % [lib, datamosh, @out]
  end

  it 'should correctly process files' do
    a = AviGlitch.open @in
    keys = a.frames.inject(0) do |c, f|
      c += 1 if f.is_keyframe?
      c
    end
    total = a.frames.size
    first_keyframe = a.frames.index(a.frames.first_of(:keyframe))
    a.close

    system [@cmd, @in].join(' ')
    o = AviGlitch.open @out
    o.frames.size.should == total
    o.frames[first_keyframe].is_keyframe?.should be true
    o.has_keyframe?.should be true
    o.close
    AviGlitch::Base.surely_formatted?(@out, true).should be true

    system [@cmd, '-a', @in].join(' ')
    o = AviGlitch.open @out
    o.frames.size.should == total
    o.frames[first_keyframe].is_keyframe?.should be false
    o.has_keyframe?.should be false
    o.close
    AviGlitch::Base.surely_formatted?(@out, true).should be true

    system [@cmd, @in, @in, @in].join(' ')
    o = AviGlitch.open @out
    o.frames.size.should == total * 3
    o.frames[first_keyframe].is_keyframe?.should be true
    o.close
    AviGlitch::Base.surely_formatted?(@out, true).should be true

    system [@cmd, '--fake', @in].join(' ')
    o = AviGlitch.open @out
    o.has_keyframe?.should be false
    o.close

  end
end

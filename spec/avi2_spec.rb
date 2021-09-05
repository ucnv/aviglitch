require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe AviGlitch, 'AVI2.0' do

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
    a = AviGlitch.open @in
    n = Math.log(1024.0 ** 3 / a.frames.data_size.to_f, 2).ceil
    f = a.frames[0..-1]
    n.times do
      fx = f[0..-1]
      f.concat fx
    end
    f.to_avi.output @out
    b = AviGlitch.open @out
    b.avi.was_avi2?.should be true
    b.close
  end
end
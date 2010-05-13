require 'tempfile'
require 'fileutils'
require 'aviglitch/frame'
require 'aviglitch/frames'

# AviGlitch provides the ways to glitch AVI formatted video files.
#
# == Synopsis:
#
# You can manipulate each frame, like:
#
#   avi = Aviglitch.new '/path/to/your.avi'
#   avi.frames.each |frame|
#     if frame.is_keyframe?
#       frame.data = frame.data.gsub(/\d/, '0')
#     end
#   end
#   avi.write '/path/to/broken.avi'
#
# Using the method glitch, it can be written like:
#
#   avi = AviGlitch.new '/path/to/your.avi'
#   avi.glitch(:keyframe) do |data|
#     data.gsub(/\d/, '0')
#   end
#   avi.write '/path/to/broken.avi'
#
#--
# It does not support AVI2, interleave format.
#
class AviGlitch

  VERSION = '0.0.1'

  # AviGlitch::Frames object generated from the +file+.
  attr_reader :frames
  # The input file (copied tempfile).
  attr_reader :file

  ##
  # Create a new instance of AviGlitch, open the file and 
  # make it ready to manipulate.
  # It requires +path+ as String or Pathname.
  def initialize path
    File.open(path) do |f|
      # copy as tempfile
      @file = Tempfile.open 'aviglitch'
      f.rewind
      while d = f.read(1024) do
        @file.print d
      end
    end

    unless AviGlitch.surely_formatted? @file
      raise 'Unsupported file passed.'
    end
    @frames = Frames.new @file
    # I believe Ruby's GC to close and remove the Tempfile..
  end

  ##
  # Output the glitched file to +path+, and close the file.
  def write path
    FileUtils.cp @file.path, path
    close
  end

  ##
  # An explicit file close.
  def close
    @file.close!
  end

  ##
  # Glitch each frame data.
  # It is a convent method to iterate each frame.
  #
  # The argument +target+ takes symbols listed below:
  # [<tt>:keyframe</tt> or <tt>:iframe</tt>]   select video key frames (aka I-frame)
  # [<tt>:deltaframe</tt> or <tt>:pframe</tt>] select video delta frames (difference frames)
  # [<tt>:videoframe</tt>] select both of keyframe and deltaframe
  # [<tt>:audioframe</tt>] select audio frames
  # [<tt>:all</tt>]        select all frames
  #
  # It also requires a block. In the block, you take the frame data
  # as a String parameter.
  # To modify the data, simply return a modified data.
  def glitch target = :all, &block  # :yield: data
    frames.each do |frame|
      if valid_target? target, frame
        frame.data = yield frame.data
      end
    end
  end

  ##
  # Do glitch with index.
  def glitch_with_index target = :all, &block  # :yield: data, index
    i = 0
    frames.each do |frame|
      if valid_target? target, frame
        frame.data = yield(frame.data, i)
        i += 1
      end
    end
  end

  alias :output :write

  def valid_target? target, frame # :nodoc:
    return true if target == :all
    begin
      frame.send "is_#{target.to_s}?"
    rescue
      false
    end
  end

  private_instance_methods :valid_target?
  class << self

    ##
    # Check if the +file+ is a correctly formetted AVI file.
    # +file+ can be String or Pathname or IO.
    def surely_formatted? file, debug = false
      answer = true
      is_io = file.respond_to?(:seek)  # Probably IO.
      file = File.open(file) unless is_io
      begin
        file.seek 0, IO::SEEK_END
        eof = file.pos
        file.rewind
        unless file.read(4) == 'RIFF'
          answer = false
          warn 'RIFF sign is not found' if debug
        end
        len = file.read(4).unpack('V').first
        unless file.read(4) == 'AVI '
          answer = false
          warn 'AVI sign is not found' if debug
        end
        while file.read(4) =~ /^(?:LIST|JUNK)$/ do
          s = file.read(4).unpack('V').first
          file.pos += s
        end
        file.pos -= 4
        # we require idx1
        unless file.read(4) == 'idx1'
          answer = false
          warn 'idx1 is not found' if debug
        end
        s = file.read(4).unpack('V').first
        file.pos += s
      rescue => err
        warn err.message if debug
        answer = false
      ensure
        file.close unless is_io
      end
      answer
    end

    alias :open :new

  end
end

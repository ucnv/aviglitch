require 'tempfile'
require 'pathname'
require 'stringio'
require 'aviglitch/avi'
require 'aviglitch/base'
require 'aviglitch/frame'
require 'aviglitch/frames'

# AviGlitch provides the ways to glitch AVI formatted video files.
#
# == Synopsis:
#
# You can manipulate each frame, like:
#
#   avi = AviGlitch.open '/path/to/your.avi'
#   avi.frames.each do |frame|
#     if frame.is_keyframe?
#       frame.data = frame.data.gsub(/\d/, '0')
#     end
#   end
#   avi.output '/path/to/broken.avi'
#
# Using the method glitch, it can be written like:
#
#   avi = AviGlitch.open '/path/to/your.avi'
#   avi.glitch(:keyframe) do |data|
#     data.gsub(/\d/, '0')
#   end
#   avi.output '/path/to/broken.avi'
#
# Since v0.2.2, it allows to specify the temporary directory. This library
# duplicates and processes a input file in the temporary directory, which
# by default is +Dir.tmpdir+. To specify the custom temporary directory, use 
# +tmpdir:+ option, like:
#
#   avi = AviGlitch.open '/path/to/your.avi', tmpdir: '/path/to/tmpdir'
#
module AviGlitch

  VERSION = '0.2.2'

  BUFFER_SIZE = 2 ** 24

  class << self
    ##
    # Returns AviGlitch::Base instance.
    # It requires +path_or_frames+ as String or Pathname, or Frames instance.
    # Additionally, it allows +tmpdir:+ as the internal temporary directory.
    def open path_or_frames, tmpdir: nil
      if path_or_frames.kind_of?(Frames)
        path_or_frames.to_avi
      else
        AviGlitch::Base.new(Pathname(path_or_frames), tmpdir: tmpdir)
      end
    end
  end
end

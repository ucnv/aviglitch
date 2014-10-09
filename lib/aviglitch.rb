require 'tempfile'
require 'fileutils'
require 'readline'
require 'pathname'
require 'stringio'
require 'aviglitch/base'
require 'aviglitch/frame'
require 'aviglitch/frames'
require 'aviglitch/tempfile'

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
module AviGlitch

  VERSION = '0.1.4'

  BUFFER_SIZE = 2 ** 24

  class << self
    ##
    # Returns AviGlitch::Base instance.
    # It requires +path_or_frames+ as String or Pathname, or Frames instance.
    def open path_or_frames
      if path_or_frames.kind_of?(Frames)
        path_or_frames.to_avi
      else
        AviGlitch::Base.new(Pathname(path_or_frames))
      end
    end
  end
end

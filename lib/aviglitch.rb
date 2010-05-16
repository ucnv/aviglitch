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
#   avi.frames.each |frame|
#     if frame.is_keyframe?
#       frame.data = frame.data.gsub(/\d/, '0')
#     end
#   end
#   avi.write '/path/to/broken.avi'
#
# Using the method glitch, it can be written like:
#
#   avi = AviGlitch.open '/path/to/your.avi'
#   avi.glitch(:keyframe) do |data|
#     data.gsub(/\d/, '0')
#   end
#   avi.write '/path/to/broken.avi'
#
#--
# It does not support AVI2, interleave format.
#
module AviGlitch

  VERSION = '0.0.1'

  class << self
    ##
    # Returns AviGlitch::Base instance.
    # It requires +path+ as String or Pathname.
    def AviGlitch.open path
      AviGlitch::Base.new(Pathname(path))
    end
  end
end

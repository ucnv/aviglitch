module AviGlitch
  
  # Frame is the struct of the frame data and meta-data.
  # You can access this class through AviGlitch::Frames.
  # To modify the binary data, operate the +data+ property.
  class Frame

    AVIIF_LIST     = 0x00000001
    AVIIF_KEYFRAME = 0x00000010
    AVIIF_NO_TIME  = 0x00000100

    attr_accessor :data, :id, :flag

    ##
    # Creates a new AviGlitch::Frame object.
    #
    # The arguments are:
    # [+data+] just data, without meta-data
    # [+id+]   id for the stream number and content type code
    #          (like "00dc")
    # [+flag+] flag that describes the chunk type (taken from idx1)
    #
    def initialize data, id, flag
      @data = data
      @id = id
      @flag = flag
    end

    ##
    # Returns if it is a video frame and also a key frame.
    def is_keyframe?
      is_videoframe? && @flag & AVIIF_KEYFRAME != 0
    end

    ##
    # Alias for is_keyframe?
    alias_method :is_iframe?, :is_keyframe?

    ##
    # Returns if it is a video frame and also not a key frame.
    def is_deltaframe?
      is_videoframe? && @flag & AVIIF_KEYFRAME == 0
    end

    ##
    # Alias for is_deltaframe?
    alias_method :is_pframe?, :is_deltaframe?

    ##
    # Returns if it is a video frame.
    def is_videoframe?
      @id[2, 2] == 'db' || @id[2, 2] == 'dc'
    end

    ##
    # Returns if it is an audio frame.
    def is_audioframe?
      @id[2, 2] == 'wb'
    end

    ##
    # Returns if it is a frame in +frame_type+.
    def is? frame_type
      return true if frame_type == :all
      detection = "is_#{frame_type.to_s.sub(/frames$/, 'frame')}?"
      begin 
        self.send detection
      rescue NoMethodError => e
        false
      end
    end

    ##
    # Compares its content.
    def == other
      self.id == other.id &&
      self.flag == other.flag &&
      self.data == other.data
    end

  end
end


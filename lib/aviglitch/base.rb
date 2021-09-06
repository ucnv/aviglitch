module AviGlitch

  # Base is the object that provides interfaces mainly used.
  # To glitch, and save file. The instance is returned through AviGlitch#open.
  #
  class Base

    # AviGlitch::Frames object generated from the +file+.
    attr_reader :frames
    # The input file
    attr_reader :avi

    ##
    # Creates a new instance of AviGlitch::Base, open the file and 
    # make it ready to manipulate.
    # It requires +path+ as Pathname or an instance of AviGlirtch::Avi.
    def initialize path_or_object
      if path_or_object.kind_of?(Avi)
        @avi = path_or_object
      else
        unless AviGlitch::Base.surely_formatted? path_or_object
          raise 'Unsupported file passed.'
        end
        @avi = Avi.new path_or_object
      end
      @frames = Frames.new @avi
    end

    ##
    # Outputs the glitched file to +path+, and close the file.
    def output path, do_file_close = true
      @avi.output path
      close if do_file_close
      self
    end

    ##
    # An explicit file close.
    def close
      @avi.close
    end

    ##
    # Glitches each frame data.
    # It is a convenient method to iterate each frame.
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
    # Without a block it returns Enumerator, with a block it returns +self+.
    def glitch target = :all, &block  # :yield: data
      if block_given?
        @frames.each do |frame|
          if frame.is? target
            frame.data = yield frame.data
          end
        end
        self
      else
        self.enum_for :glitch, target
      end
    end

    ##
    # Do glitch with index.
    def glitch_with_index target = :all, &block  # :yield: data, index
      if block_given?
        self.glitch(target).with_index do |x, i|
          yield x, i
        end
        self
      else
        self.glitch target
      end
    end

    ##
    # Mutates all (or in +range+) keyframes into deltaframes.
    # It's an alias for Frames#mutate_keyframes_into_deltaframes!
    def mutate_keyframes_into_deltaframes! range = nil
      self.frames.mutate_keyframes_into_deltaframes! range
      self
    end

    ##
    # Check if it has keyframes.
    def has_keyframe?
      result = false
      self.frames.each do |f|
        if f.is_keyframe?
          result = true
          break
        end
      end
      result
    end

    ##
    # Removes all keyframes.
    # It is same as +glitch(:keyframes){|f| nil }+
    def remove_all_keyframes!
      self.glitch :keyframe do |f|
        nil
      end
      self
    end

    ##
    # Swaps the frames with other Frames data.
    def frames= other
      raise TypeError unless other.kind_of?(Frames)
      @frames.clear
      @frames.concat other
    end

    alias_method :write, :output
    alias_method :has_keyframes?, :has_keyframe?

    class << self
      ##
      # Checks if the +file+ is a correctly formetted AVI file.
      # +file+ can be String or Pathname or IO.
      def surely_formatted? file, debug = false
        passed = true
        begin
          riff = Avi.rifftree file
          {
            'RIFF-AVI sign': /^RIFF \(\d+\) ’AVI ’$/,
            'movi': /^\s+LIST \(\d+\) ’movi’$/,
            'idx1': /^\s+idx1 \(\d+\)$/
          }.each do |m, r|
            unless riff =~ r
              warn "#{m} is not found." if debug
              passed = false
            end
          end
        rescue => e
          warn e.message if debug
          passed = false
        end
        passed
      end
    end
  end
end

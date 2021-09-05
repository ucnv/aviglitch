module AviGlitch

  # Frames provides the interface to access each frame
  # in the AVI file.
  # It is implemented as Enumerable. You can access this object
  # through AviGlitch#frames, for example:
  #
  #   avi = AviGlitch.new '/path/to/your.avi'
  #   frames = avi.frames
  #   frames.each do |frame|
  #     ## frame is a reference of an AviGlitch::Frame object
  #     frame.data = frame.data.gsub(/\d/, '0')
  #   end
  #
  # In the block passed into iteration method, the parameter is a reference
  # of AviGlitch::Frame object.
  #
  class Frames
    include Enumerable

    attr_reader :avi

    ##
    # Creates a new AviGlitch::Frames object.
    def initialize avi
      @avi = avi
    end

    ##
    # Enumerates the frames.
    # It returns Enumerator if a block is not given.
    def each &block
      if block_given?
        Tempfile.open('temp', binmode: true) do |newmovi|
          @avi.process_movi do |indices, movi|
            newindices = indices.select do |m|
              movi.pos = m[:offset] + 8    # 8 for id and size
              frame = Frame.new(movi.read(m[:size]), m[:id], m[:flag])
              block.call frame
              unless frame.data.nil?
                m[:offset] = newmovi.pos
                m[:size] = frame.data.size
                m[:flag] = frame.flag
                m[:id] = frame.id
                newmovi.print m[:id]
                newmovi.print [frame.data.size].pack('V')
                newmovi.print frame.data
                newmovi.print "\0" if frame.data.size % 2 == 1
                true
              else
                false
              end
            end
            [newindices, newmovi]
          end
        end
      else
        self.enum_for :each
      end
    end

    ##
    # Returns the number of frames.
    def size
      @avi.indices.size
    end

    ##
    # Returns the number of the specific +frame_type+.
    def size_of frame_type
      @avi.indices.select { |m|
        Frame.new(nil, m[:id], m[:flag]).is? frame_type
      }.size
    end

    ##
    # Returns the data size of total frames.
    def data_size
      size = 0
      @avi.process_movi do |indices, movi|
        size = movi.size
        [indices, movi]
      end
      size
    end

    ##
    # Removes all frames and returns self.
    def clear
      @avi.process_movi do |indices, movi|
        [[], StringIO.new]
      end
      self
    end

    ##
    # Appends the frames in the other Frames into the tail of self.
    # It is destructive like Array does.
    def concat other_frames
      raise TypeError unless other_frames.kind_of?(Frames)
      @avi.process_movi do |this_indices, this_movi|
        this_size = this_movi.size
        this_movi.pos = this_size
        other_frames.avi.process_movi do |other_indices, other_movi|
          while d = other_movi.read(BUFFER_SIZE) do
            this_movi.print d
          end
          other_meta = other_indices.collect do |m|
            x = m.dup
            x[:offset] += this_size
            x
          end
          this_indices.concat other_meta
          [other_indices, other_movi]
        end
        [this_indices, this_movi]
      end

      self
    end

    ##
    # Returns a concatenation of the two Frames as a new Frames instance.
    def + other_frames
      r = self.to_avi
      r.frames.concat other_frames
      r.frames
    end

    ##
    # Returns the new Frames as a +times+ times repeated concatenation
    # of the original Frames.
    def * times
      result = self.slice 0, 0
      frames = self.slice 0..-1
      times.times do
        result.concat frames
      end
      result
    end

    ##
    # Returns the Frame object at the given index or
    # returns new Frames object that sliced with the given index and length
    # or with the Range.
    # Just like Array.
    def slice *args
      b, l = get_beginning_and_length *args
      if l.nil?
        self.at b
      else
        e = b + l - 1
        r = self.to_avi
        r.frames.each_with_index do |f, i|
          unless i >= b && i <= e
            f.data = nil
          end
        end
        r.frames
      end
    end

    ##
    # Alias for slice
    alias_method :[], :slice

    ##
    # Removes frame(s) at the given index or the range (same as slice).
    # Returns the new Frames contains removed frames.
    def slice! *args
      b, l = get_beginning_and_length *args
      head, sliced, tail = ()
      sliced = l.nil? ? self.slice(b) : self.slice(b, l)
      head = self.slice(0, b)
      l = 1 if l.nil?
      tail = self.slice((b + l)..-1)
      self.clear
      self.concat head + tail
      sliced
    end

    ##
    # Removes frame(s) at the given index or the range (same as []).
    # Inserts the given Frame or Frames's contents into the removed index.
    def []= *args
      value = args.pop
      b, l = get_beginning_and_length *args
      ll = l.nil? ? 1 : l
      head = self.slice(0, b)
      rest = self.slice((b + ll)..-1)
      if l.nil? || value.kind_of?(Frame)
        head.push value
      elsif value.kind_of?(Frames)
        head.concat value
      else
        raise TypeError
      end
      new_frames = head + rest

      self.clear
      self.concat new_frames
    end

    ##
    # Returns one Frame object at the given index.
    def at n
      frame = nil
      @avi.process_movi do |indices, movi|
        m = indices[n]
        unless m.nil?
          movi.pos = m[:offset] + 8
          frame = Frame.new(movi.read(m[:size]), m[:id], m[:flag])
          movi.rewind
        end
        [indices, movi]
      end
      frame
    end

    ##
    # Returns the first Frame object.
    def first
      self.slice(0)
    end

    ##
    # Returns the last Frame object.
    def last
      self.slice(self.size - 1)
    end

    ##
    # Returns the first Frame object in +frame_type+.
    def first_of frame_type
      frame = nil
      @avi.process_movi do |indices, movi|
        indices.each do |m|
          movi.pos = m[:offset] + 8
          f = Frame.new(movi.read(m[:size]), m[:id], m[:flag])
          if f.is?(frame_type)
            frame = f
            break
          end
        end
        [indices, movi]
      end
      frame
    end

    ##
    # Returns the last Frame object in +frame_type+.
    def last_of frame_type
      frame = nil
      @avi.process_movi do |indices, movi|
        indices.reverse.each do |m|
          movi.pos = m[:offset] + 8
          f = Frame.new(movi.read(m[:size]), m[:id], m[:flag])
          if f.is?(frame_type)
            frame = f
            break
          end
        end
        [indices, movi]
      end
      frame
    end

    ##
    # Returns an index of the first found +frame+.
    def index frame
      n = -1
      @avi.process_movi do |indices, movi|
        indices.each_with_index do |m, i|
          movi.pos = m[:offset] + 8
          f = Frame.new(movi.read(m[:size]), m[:id], m[:flag]) 
          if f == frame
            n = i
            break
          end
        end
        [indices, movi]
      end
      n
    end

    ##
    # Alias for index
    alias_method :find_index, :index

    ##
    # Returns an index of the first found +frame+, starting from the last.
    def rindex frame
      n = -1
      @avi.process_movi do |indices, movi|
        indices.reverse.each_with_index do |m, i|
          movi.pos = m[:offset] + 8
          f = Frame.new(movi.read(m[:size]), m[:id], m[:flag])
          if f == frame
            n = indices.size - 1 - i
            break
          end
        end
        [indices, movi]
      end
      n
    end

    ##
    # Appends the given Frame into the tail of self.
    def push frame
      raise TypeError unless frame.kind_of? Frame
      @avi.process_movi do |indices, movi|
        this_size = movi.size
        movi.pos = this_size
        movi.print frame.id
        movi.print [frame.data.size].pack('V')
        movi.print frame.data
        movi.print "\0" if frame.data.size % 2 == 1
        indices << {
          :id     => frame.id,
          :flag   => frame.flag,
          :offset => this_size,
          :size   => frame.data.size,
        }
        [indices, movi]
      end
      self
    end

    ##
    # Alias for push
    alias_method :<<, :push

    ##
    # Inserts the given Frame objects into the given index.
    def insert n, *args
      new_frames = self.slice(0, n)
      args.each do |f|
        new_frames.push f
      end
      new_frames.concat self.slice(n..-1)

      self.clear
      self.concat new_frames
      self
    end

    ##
    # Deletes one Frame at the given index.
    def delete_at n
      self.slice! n
    end

    ##
    # Mutates keyframes into deltaframes at given range, or all.
    def mutate_keyframes_into_deltaframes! range = nil
      range = 0..self.size if range.nil?
      self.each_with_index do |frame, i|
        if range.include? i
          frame.flag = 0 if frame.is_keyframe?
        end
      end
      self
    end

    ##
    # Returns true if +other+'s frames are same as self's frames.
    def == other
      @avi == other.avi
    end

    ##
    # Generates new AviGlitch::Base instance using self.
    def to_avi
      AviGlitch::Base.new @avi.clone
    end

    def inspect #:nodoc:
      "#<#{self.class.name}:#{sprintf("0x%x", object_id)} size=#{self.size}>"
    end

    def get_beginning_and_length *args #:nodoc:
      b, l = args
      if args.first.kind_of? Range
        r = args.first
        b = r.begin
        e = r.end >= 0 ? r.end : self.size + r.end
        l = e - b + 1
      end
      b = b >= 0 ? b : self.size + b
      [b, l]
    end

    def safe_frames_count? count #:nodoc:
      warn "[DEPRECATION] `safe_frames_count?` is deprecated."
      true
    end

    private :get_beginning_and_length
  end
end

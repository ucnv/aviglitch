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

    # :stopdoc:
    SAFE_FRAMES_COUNT = 150000
    @@warn_if_frames_are_too_large = true
    # :startdoc:

    attr_reader :meta

    ##
    # Creates a new AviGlitch::Frames object.
    def initialize io
      io.rewind
      io.pos = 12 # /^RIFF[\s\S]{4}AVI $/
      while io.read(4) =~ /^(?:LIST|JUNK)$/ do
        s = io.read(4).unpack('V').first
        @pos_of_movi = io.pos - 4 if io.read(4) == 'movi'
        io.pos += s - 4
      end
      @pos_of_idx1 = io.pos - 4 # here must be idx1
      s = io.read(4).unpack('V').first + io.pos
      @meta = []
      while chunk_id = io.read(4) do
        break if io.pos >= s
        @meta << {
          :id     => chunk_id,
          :flag   => io.read(4).unpack('V').first,
          :offset => io.read(4).unpack('V').first,
          :size   => io.read(4).unpack('V').first,
        }
      end
      fix_offsets_if_needed io
      unless safe_frames_count? @meta.size
        io.close!
        exit
      end
      io.rewind
      @io = io
    end

    ##
    # Enumerates the frames.
    # It returns Enumerator if a block is not given.
    def each
      if block_given?
        temp = Tempfile.new 'frames'
        frames_data_as_io(temp, Proc.new)
        overwrite temp
        temp.close!
      else
        self.enum_for :each
      end
    end

    ##
    # Returns the number of frames.
    def size
      @meta.size
    end

    def frames_data_as_io io = nil, block = nil  #:nodoc:
      io = Tempfile.new('tmep') if io.nil?
      @meta = @meta.select do |m|
        @io.pos = @pos_of_movi + m[:offset] + 8   # 8 for id and size
        frame = Frame.new(@io.read(m[:size]), m[:id], m[:flag])
        block.call(frame) if block    # accept the variable block as Proc
        yield frame if block_given?   # or a given block (or do nothing)
        unless frame.data.nil?
          m[:offset] = io.pos + 4   # 4 for 'movi'
          m[:size] = frame.data.size
          m[:flag] = frame.flag
          m[:id] = frame.id
          io.print m[:id]
          io.print [frame.data.size].pack('V')
          io.print frame.data
          io.print "\000" if frame.data.size % 2 == 1
          true
        else
          false
        end
      end
      io
    end

    def overwrite data  #:nodoc:
      unless safe_frames_count? @meta.size
        @io.close!
        exit
      end
      # Overwrite the file
      @io.pos = @pos_of_movi - 4  # 4 for size
      @io.print [data.pos + 4].pack('V')  # 4 for 'movi'
      @io.print 'movi'
      data.rewind
      while d = data.read(BUFFER_SIZE) do
        @io.print d
      end
      @io.print 'idx1'
      @io.print [@meta.size * 16].pack('V')
      idx = @meta.collect { |m|
        m[:id] + [m[:flag], m[:offset], m[:size]].pack('V3')
      }.join
      @io.print idx
      eof = @io.pos
      @io.truncate eof

      # Fix info
      ## file size
      @io.pos = 4
      @io.print [eof - 8].pack('V')
      ## frame count
      @io.pos = 48
      vid_frames = @meta.select do |m|
        id = m[:id]
        id[2, 2] == 'db' || id[2, 2] == 'dc'
      end
      @io.print [vid_frames.size].pack('V')

      @io.pos
    end

    ##
    # Removes all frames and returns self.
    def clear
      @meta = []
      overwrite StringIO.new
      self
    end

    ##
    # Appends the frames in the other Frames into the tail of self.
    # It is destructive like Array does.
    def concat other_frames
      raise TypeError unless other_frames.kind_of?(Frames)
      # data
      this_data = Tempfile.new 'this'
      self.frames_data_as_io this_data
      other_data = Tempfile.new 'other'
      other_frames.frames_data_as_io other_data
      this_data.seek 0, IO::SEEK_END
      this_size = this_data.pos
      other_data.rewind
      while d = other_data.read(BUFFER_SIZE) do
        this_data.print d
      end
      other_data.close!
      # meta
      other_meta = other_frames.meta.collect do |m|
        x = m.dup
        x[:offset] += this_size
        x
      end
      @meta.concat other_meta
      # close
      overwrite this_data
      this_data.close!
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
      m = @meta[n]
      return nil if m.nil?
      @io.pos = @pos_of_movi + m[:offset] + 8
      frame = Frame.new(@io.read(m[:size]), m[:id], m[:flag])
      @io.rewind
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
    # Appends the given Frame into the tail of self.
    def push frame
      raise TypeError unless frame.kind_of? Frame
      # data
      this_data = Tempfile.new 'this'
      self.frames_data_as_io this_data
      this_data.seek 0, IO::SEEK_END
      this_size = this_data.pos
      this_data.print frame.id
      this_data.print [frame.data.size].pack('V')
      this_data.print frame.data
      this_data.print "\000" if frame.data.size % 2 == 1
      # meta
      @meta << {
        :id     => frame.id,
        :flag   => frame.flag,
        :offset => this_size + 4, # 4 for 'movi'
        :size   => frame.data.size,
      }
      # close
      overwrite this_data
      this_data.close!
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
    end

    ##
    # Returns true if +other+'s frames are same as self's frames.
    def == other
      @meta == other.meta
    end

    ##
    # Generates new AviGlitch::Base instance using self.
    def to_avi
      AviGlitch.open @io.path
    end

    def inspect # :nodec:
      "#<#{self.class.name}:#{sprintf("0x%x", object_id)} @io=#{@io.inspect} size=#{self.size}>"
    end

    def get_beginning_and_length *args #:nodoc:
      b, l = args
      if args.first.kind_of? Range
        r = args.first
        b = r.begin
        e = r.end >= 0 ? r.end : @meta.size + r.end
        l = e - b + 1
      end
      b = b >= 0 ? b : @meta.size + b
      [b, l]
    end

    def safe_frames_count? count #:nodoc:
      r = true
      if @@warn_if_frames_are_too_large && count >= SAFE_FRAMES_COUNT
        trap(:INT) do
          @io.close!
          exit
        end
        m = ["WARNING: The avi data has too many frames (#{count}).\n",
          "It may use a large memory to process. ",
          "We recommend to chop the movie to smaller chunks before you glitch.\n",
          "Do you want to continue anyway? [yN] "].join('')
        a = Readline.readline m
        r = a == 'y'
        @@warn_if_frames_are_too_large = !r
      end
      r
    end

    def fix_offsets_if_needed io #:nodoc:
      # rarely data offsets begin from 0 of the file
      return if @meta.empty?
      pos = io.pos
      m = @meta.first
      io.pos = @pos_of_movi + m[:offset]
      unless io.read(4) == m[:id]
        @meta.each do |x|
          x[:offset] -= @pos_of_movi
        end
      end
      io.pos = pos
    end

    protected :frames_data_as_io, :meta
    private :overwrite, :get_beginning_and_length, :fix_offsets_if_needed
  end
end

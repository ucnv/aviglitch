module AviGlitch

  # Frames provides the interface to access each frame
  # in the AVI file.
  # It is implemented as Enumerable. You can access this object
  # through AviGlitch#frames, for example:
  #
  #   avi = AviGlitch.new '/path/to/your.avi'
  #   frames = avi.frames
  #   frames.each do |frame|
  #     ## frame is a reference of a AviGlitch::Frame object
  #     frame.data = frame.data.gsub(/\d/, '0')
  #   end
  #
  # In the block passed into iteration method, the parameter is the reference
  # of AviGlitch::Frame object.
  #
  class Frames
    include Enumerable

    attr_reader :meta

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
      io.rewind
      @io = io
    end

    def each
      temp = Tempfile.new 'frames'
      frames_data_as_io(temp, Proc.new)
      overwrite temp
      temp.close true
    end

    def size
      @meta.size
    end

    def frames_data_as_io(io = nil, block = nil) #:nodoc:
      io = Tempfile.new('tmep') if io.nil?
      @meta = @meta.select do |m|
        @io.pos = @pos_of_movi + m[:offset] + 8   # 8 for id and size
        frame = Frame.new(@io.read(m[:size]), m[:id], m[:flag])
        block.call(frame) if block    # accept the variable block as Proc
        yield frame if block_given?   # or a given block (or do nothing)
        unless frame.data.nil?
          m[:offset] = io.pos + 4   # 4 for 'movi'
          m[:size] = frame.data.size
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
      # Overwrite the file
      data.seek 0, IO::SEEK_END
      @io.pos = @pos_of_movi - 4  # 4 for size
      @io.print [data.pos + 4].pack('V')  # 4 for 'movi'
      @io.print 'movi'
      data.rewind
      while d = data.read(1024) do
        @io.print d
      end
      @io.print 'idx1'
      @io.print [@meta.size * 16].pack('V')
      @meta.each do |m|
        @io.print m[:id]
        @io.print [m[:flag], m[:offset], m[:size]].pack('V3')
      end
      eof = @io.pos
      @io.truncate eof

      # Fix info
      ## file size
      @io.pos = 4
      @io.print [eof - 8].pack('V')
      ## frame count
      @io.pos = 48
      @io.print [@meta.size].pack('V')

      @io.pos
    end

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
      while d = other_data.read(1024) do
        this_data.print d
      end
      other_data.close true
      # meta
      other_meta = other_frames.meta
      other_meta.collect! do |m|
        m[:offset] += this_size
        m
      end
      @meta.concat other_meta
      # close
      overwrite this_data
      this_data.close true
    end

    def + other_frames
      r = AviGlitch.open @io.path
      r.frames.concat other_frames
      r
    end

    def slice *args
      b, l = args
      if args.first.kind_of? Range
        r = args.first
        b = r.begin
        l = r.end - r.begin
      end
      e = b + l - 1

      r = AviGlitch.open @io.path
      r.frames.each_with_index do |f, i|
        unless i >= b && i <= e
          f.data = nil
        end
      end
      r.frames
    end

    protected :frames_data_as_io, :meta
    private :overwrite
  end
end

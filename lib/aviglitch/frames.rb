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
      temp.print 'movi'
      @meta = @meta.select do |m|
        @io.pos = @pos_of_movi + m[:offset] + 8
        frame = Frame.new(@io.read(m[:size]), m[:id], m[:flag])
        yield frame
        unless frame.data.nil?
          m[:offset] = temp.pos
          m[:size] = frame.data.size
          temp.print m[:id]
          temp.print [frame.data.size].pack('V')
          temp.print frame.data
          temp.print "\000" if frame.data.size % 2 == 1
          true
        else
          false
        end
      end

      # Overwrite the file
      @io.pos = @pos_of_movi - 4
      @io.print [temp.pos].pack('V')
      temp.rewind
      while d = temp.read(1024) do
        @io.print d
      end
      temp.close true
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

    end

    def size
      @meta.size
    end

  end
end

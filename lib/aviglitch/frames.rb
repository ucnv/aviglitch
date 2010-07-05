require 'stringio'

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
      vid_frames = @meta.select do |m|
        id = m[:id]
        id[2, 2] == 'db' || id[2, 2] == 'dc'
      end
      @io.print [vid_frames.size].pack('V')

      @io.pos
    end

    def clear
      @meta = []
      overwrite StringIO.new
      self
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
      other_meta = other_frames.meta.collect do |m|
        x = m.dup
        x[:offset] += this_size
        x
      end
      @meta.concat other_meta
      # close
      overwrite this_data
      this_data.close true
    end

    def + other_frames
      r = self.to_avi
      r.frames.concat other_frames
      r.frames
    end

    def * times
      result = self.slice 0, 0
      frames = self.slice 0..-1
      times.times do
        result.concat frames
      end
      result
    end

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

    alias :[] :slice

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

    def []= *args, value
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

    def at n
      m = @meta[n]
      return nil if m.nil?
      @io.pos = @pos_of_movi + m[:offset] + 8
      frame = Frame.new(@io.read(m[:size]), m[:id], m[:flag])
      @io.rewind
      frame
    end

    def first
      self.slice(0)
    end

    def last
      self.slice(self.size - 1)
    end

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
      this_data.close true
      self
    end

    alias :<< :push

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

    def delete_at n
      self.slice! n
    end

    def == other
      @meta == other.meta
    end

    ##
    # Generate new AviGlitch::Base instance using self.
    def to_avi
      AviGlitch.open @io.path
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

    protected :frames_data_as_io, :meta
    private :overwrite, :get_beginning_and_length
  end
end

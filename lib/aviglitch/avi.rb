module AviGlitch

  # Avi parses the passed RIFF-AVI file and maintains binary data as 
  # a structured object.
  # It contains headers, frame's raw data, and indices of frames. 
  # The attribute +movi+ is an IO to handles frames binary and 
  # the +indices+ represents the position of each frame.
  # This library accesses the data through this class internally.
  #
  # This class can parse any RIFF formated file to a ruby object, 
  # though it especially provides a way to handle AVI frame data.
  #
  class Avi

    # :stopdoc:

    # RiffChunk represents a parsed RIFF chunk.
    class RiffChunk

      attr_accessor :id, :list, :value, :size
      
      def initialize id, size, value, list = false
        @size = size
        @is_list = list.kind_of? Array
        unless is_list?
          @id = id
          @value = value
        else
          @id = value
          @list = id
          @value = list
        end 
      end

      def is_list?
        @is_list
      end

      def inspect
        if @is_list
          "{list: \"#{list}\", id: \"#{id}\", size: #{size}, value: #{value}}"
        elsif !value.nil?
          "{id: \"#{id}\", size: #{size}, value: \"#{value}\"}"
        else 
          "{id: \"#{id}\", size: #{size}}"
        end
      end

    end

    # :startdoc:

    MAX_RIFF_SIZE = 1024 ** 3
    # Tempfile instance of "movi" entities.
    attr_accessor :movi
    # List of indices for +movi+ data.
    attr_accessor :indices
    # 
    attr_accessor :riff
    #
    attr_accessor :path
    protected :movi=, :path, :path=

    ##
    # Generates an instance with a necessary structure from the +path+.
    def initialize path = nil
      return if path.nil?
      @path = path
      File.open(path, 'rb') do |io|
        @movi = Tempfile.new 'aviglitch', binmode: true
        @riff = []
        @indices = []
        @movi_offsets = []
        @was_avi2 = false
        io.rewind
        parse_riff io, @riff
      end
    end

    ##
    # Parses the passed RIFF formated file.
    def parse_riff io, target, len = 0, is_movi = false
      offset = io.pos
      binoffset = @movi.pos
      while id = io.read(4) do
        if len > 0 && io.pos >= offset + len
          io.pos -= 4
          break
        end
        size = io.read(4).unpack('V').first
        if id == 'RIFF' || id == 'LIST'
          lid = io.read(4)
          newarr = []
          chunk = RiffChunk.new id, size, lid, newarr
          target << chunk
          parse_riff io, newarr, size, lid == 'movi'
        else
          value = nil
          if is_movi
            if id =~ /^ix/
              v = io.read size
              # TODO: confirm super index surely have infomation
              parse_avi2_indices v, binoffset
            else
              io.pos -= 8
              v = io.read(size + 8)
              @movi.print v
              @movi.print "\000" if size % 2 == 1
            end
          else
            if id =~ /^idx/
              v = io.read size
              parse_avi1_indices v unless was_avi2?
            else
              value = io.read size
            end
            @was_avi2 = true if id == 'indx'
          end
          chunk = RiffChunk.new id, size, value
          target << chunk
          io.pos += 1 if size % 2 == 1
        end
      end
    end

    ##
    # Closes the file.
    def close
      @movi.close
    end

    ##
    # Detects the passed file was an AVI2.0 file.
    def was_avi2?
      @was_avi
    end

    ##
    # Detects the current data will be an AVI2.0 file.
    def is_avi2?
      @movi.size >= MAX_RIFF_SIZE
    end

    ##
    # Saves data to AVI formatted file.
    def output path
      writechunk = Proc.new do |io, chunk|
        offset = io.pos
        if chunk.is_list?
          io.print chunk.list
          io.print [0].pack('V')
          io.print chunk.id
          chunk.value.each do |c|
            writechunk.call io, c
          end
        else
          io.print chunk.id
          io.print [0].pack('V')
          io.print chunk.value
        end
        # rewrite size
        size = io.pos - offset - 8
        io.pos = offset + 4
        io.print [size].pack('V')
        io.seek 0, IO::SEEK_END
        io.print "\000" if size % 2 == 1
      end

      File.open(path, 'w+') do |io|
        io.binmode
        ipos = 0
        @movi.rewind
        # normal AVI
        riff = @riff.first
        # header
        io.print 'RIFF'
        io.print [0].pack('V')
        io.print 'AVI '
        riff.value.each do |chunk|
          break if chunk.id == 'movi'
          writechunk.call io, chunk
        end
        # movi
        data_offset = io.pos
        idx_offset = 0
        vid_frames_size = 0
        io.print 'LIST'
        io.print [0].pack('V')
        io.print 'movi'
        while io.pos - data_offset <= MAX_RIFF_SIZE
          ix = indices[ipos]
          io.print ix[:id]
          vid_frames_size += 1 if ix[:id] =~ /d[dc]$/
          io.print [ix[:size]].pack('V')
          @movi.pos += 8
          io.print @movi.read(ix[:size])
          if ix[:size] % 2 == 1
            io.print "\000"
            @movi.pos += 1  
          end
          ipos += 1
          break if ipos > indices.size - 1
        end
        size = io.pos - data_offset - 8
        io.pos = data_offset + 4
        io.print [size].pack('V')
        io.seek 0, IO::SEEK_END
        io.print "\000" if size % 2 == 1
        # rewrite frame count in avih header
        io.pos = 48
        io.print [vid_frames_size].pack('V')
        io.seek 0, IO::SEEK_END
        # idx1
        io.print 'idx1'
        io.print [ipos * 16].pack('V')
        idx1 = indices[0..(ipos - 1)].collect do |ix|
          ix[:id] + [ix[:flag], ix[:offset] + 4, ix[:size]].pack('V3')
        end
        io.print idx1.join('')
        # rewrite riff chunk size
        avisize = io.pos - 8
        io.pos = 4
        io.print [avisize].pack('V')
        io.seek 0, IO::SEEK_END

        # AVI2.0
        while ipos < @indices.size
          offset = io.pos
          io.print 'RIFF'
          io.print [0].pack('V')
          io.print 'AVIX'

          # TODO: parse AVI2 chunks

          # rewrite total chunk size
          io.pos = offset + 4
          io.print [avisize].pack('V')
          io.seek 0, IO::SEEK_END
        end

      end
    end

    def inspect # :nodec:
      "#<#{self.class.name}:#{sprintf("0x%x", object_id)} @movi=#{@movi.inspect}>"
    end

    def initialize_copy avi # :nodec:
      avi.path = @path.dup
      md = Marshal.dump @indices
      avi.indices = Marshal.load md
      md = Marshal.dump @riff
      avi.riff = Marshal.load md
      newmovi = Tempfile.new 'aviglitch', binmode: true
      movipos = @movi.pos
      @movi.rewind
      newmovi.print @movi.read
      @movi.pos = movipos
      newmovi.rewind
      avi.movi = newmovi
    end

    # ----------------------------------------------------------------

    def parse_avi1_indices data  #:nodoc:
      # The function Frsmes#fix_offsets_if_needed in previous versions is now removed. 
      i = 0
      while i * 16 < data.size do
        indices << {
          :id     => data[i * 16, 4],
          :flag   => data[i * 16 + 4, 4].unpack('V').first,
          :offset => data[i * 16 + 8, 4].unpack('V').first - 4,
          :size   => data[i * 16 + 12, 4].unpack('V').first,
        }
        i += 1
      end
    end

    def parse_avi2_indices data, offset

    end

    private :parse_avi1_indices, :parse_avi2_indices

    class << self

      ##
      # Parses RIFF structured file from +path+ and returns a formatted +String+.
      def rifftree path, out = nil
        returnable = out.nil? 
        out = StringIO.new if returnable 

        parse = Proc.new do |io, depth = 0, len = 0|
          offset = io.pos
          while id = io.read(4) do
            if len > 0 && io.pos >= offset + len
              io.pos -= 4
              break
            end
            size = io.read(4).unpack('V').first
            str = depth > 0 ? '   ' * depth + id : id
            if id =~ /^(?:RIFF|LIST)$/
              lid = io.read(4)
              str << ' (%d)' % size
              str << ' ’' + lid + '’'
              out.print str
              out.print "\n"
              parse.call io, depth + 1, size
            else
              str << ' (%d)' % size
              out.print str
              out.print "\n"
              io.pos += size
              io.pos += 1 if size % 2 == 1
            end
          end
        end
      
        open(path, 'rb') do |io|
          parse.call io
        end
        
        if returnable
          out.rewind
          out.read
        end
      end

      ##
      # Parses RIFF structured file from +path+ and prints the result to stdout.
      def print_rifftree path   
        Avi.rifftree path, $stdout
      end

    end
  end

end
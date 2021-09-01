module AviGlitch

  # Avi parses the passed RIFF-AVI file and maintains binary data as 
  # a structured object.
  # It contains headers, frame's raw data, and indices of frames. 
  # The attribute +movi+ is an IO to handles frames binary and 
  # the +indices+ represents the position of each frame.
  # The AviGlitch library accesses the data through this class internally.
  #
  class Avi

    # :stopdoc:

    # RiffChunk represents a parsed RIFF chunk.
    class RiffChunk

      attr_accessor :id, :list, :value, :binsize
      
      def initialize id, size, value, list = false
        @binsize = size
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

      def children id
        if is_list?
          value.filter do |chk|
            chk.id == id
          end
        else
          []
        end
      end

      def child id
        children(id).first
      end

      def search *args
        a1 = args.shift
        r = value.filter {|v| 
          v.id == a1
        }.collect {|v|
          if args.size > 0
            v.search *args
          else
            v
          end
        }
        r.flatten
      end

      def inspect
        if @is_list
          "{list: \"#{list}\", id: \"#{id}\", binsize: #{binsize}, value: #{value}}"
        elsif !value.nil?
          "{id: \"#{id}\", binsize: #{binsize}, value: \"#{value}\"}"
        else 
          "{id: \"#{id}\", binsize: #{binsize}}"
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
        @superidx = []
        @was_avi2 = false
        io.rewind
        parse_riff io, @riff
        if was_avi2?
          @indices.sort_by! { |ix| ix[:offset] }
        end
      end
    end

    ##
    # Parses the passed RIFF formated file recursively.
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
              # confirm the super index surely has information
              @superidx.each do |sidx|
                nent = sidx[4, 4].unpack('v').first
                cid = sidx[8, 4]
                nent.times do |i|
                  ent = sidx[24 + 16 * i, 16]
                  # we can check other informations thuogh
                  valid = ent[0, 8].unpack('q').first == io.pos - v.size - 8
                  parse_avi2_indices(v, binoffset) if valid
                end
              end
            else
              io.pos -= 8
              v = io.read(size + 8)
              @movi.print v
              @movi.print "\0" if size % 2 == 1
            end
          elsif id == 'idx1'
            v = io.read size
            parse_avi1_indices v unless was_avi2?
          else
            value = io.read size
            if id == 'indx'
              @superidx << value
              @was_avi2 = true
            end
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
      @movi.close!
    end

    ##
    # Detects the passed file was an AVI2.0 file.
    def was_avi2?
      @was_avi2
    end

    ##
    # Detects the current data will be an AVI2.0 file.
    def is_avi2?
      @movi.size >= MAX_RIFF_SIZE
    end
    
    ##
    # Saves data to AVI formatted file.
    def output path
      @index_pos = 0
      # prepare headers
      strl = search 'hdrl', 'strl'
      if is_avi2?
        # indx
        vid_frames_size = 0
        @indexinfo = @indices.collect do |ix|
          vid_frames_size += 1 if ix[:id] =~ /d[bc]$/
          ix[:id]
        end.uniq.sort.collect do |d| 
          [d, {}]
        end.to_h  # should be like: {"00dc"=>{}, "01wb"=>{}}
        strl.each_with_index do |sl, i|
          indx = sl.child 'indx'
          if indx.nil?
            indx = RiffChunk.new('indx', 4120, "\0" * 4120)
            indx.value[0, 8] = [4, 0, 0, 0].pack('vccV')
            sl.value.push indx
          else
            indx.value[4, 4] = [0].pack('V')
            indx.value[24..-1] = "\0" * (indx.value.size - 24)
          end
          preid = indx.value[8, 4]
          info = @indexinfo.find do |key, val|
            # more strict way must exist though..
            if preid == "\0\0\0\0"
              key.start_with? "%02d" % i
            else
              key == preid
            end
          end
          indx.value[8, 4] = info.first if preid == "\0\0\0\0"
          info.last[:indx] = indx
          info.last[:fcc] = 'ix' + info.first[0, 2]
          info.last[:cur] = []
        end
        # odml
        odml = search('hdrl', 'odml').first
        if odml.nil?
          odml = RiffChunk.new 'LIST', 260, 'odml', [RiffChunk.new('dmlh', 248, "\0" * 248)]
          @riff.first.child('hdrl').value.push odml
        end
        odml.child('dmlh').value[0, 4] = [@indices.size].pack('V')
      else
        strl.each do |sl|
          indx = sl.child 'indx'
          unless indx.nil?
            sl.value.delete indx
          end
        end
      end

      # movi
      write_movi = ->(io) do
        vid_frames_size = 0
        io.print 'LIST'
        io.print "\0\0\0\0"
        data_offset = io.pos
        io.print 'movi'
        while io.pos - data_offset <= MAX_RIFF_SIZE
          ix = @indices[@index_pos]
          @indexinfo[ix[:id]][:cur] << {pos: io.pos, size: ix[:size], flag: ix[:flag]} if is_avi2?
          io.print ix[:id]
          vid_frames_size += 1 if ix[:id] =~ /d[bc]$/
          io.print [ix[:size]].pack('V')
          @movi.pos += 8
          io.print @movi.read(ix[:size])
          if ix[:size] % 2 == 1
            io.print "\0"
            @movi.pos += 1
          end
          @index_pos += 1
          break if @index_pos > @indices.size - 1
        end
        # standard index
        if is_avi2?
          @indexinfo.each do |key, info|
            ix_offset = io.pos
            io.print info[:fcc]
            io.print [24 + 8 * info[:cur].size].pack('V')
            io.print [2, 0, 1, info[:cur].size].pack('vccV')
            io.print key
            io.print [data_offset, 0].pack('qV')
            info[:cur].each.with_index do |cur, i|
              io.print [cur[:pos] - data_offset + 8].pack('V') # 8 for LIST####
              sz = cur[:size]
              if cur[:flag] & Frame::AVIIF_KEYFRAME == 0 # is not keyframe
                sz = sz | 0b1000_0000_0000_0000_0000_0000_0000_0000
              end
              io.print [sz].pack('V')
            end
            # rewrite indx
            indx = info[:indx]
            nent = indx.value[4, 4].unpack('V').first + 1
            indx.value[4, 4] = [nent].pack('V')
            indx.value[24 + 16 * (nent - 1), 16] = [ix_offset, io.pos - ix_offset, info[:cur].size].pack('qVV')
            io.pos = expected_position_of(indx) + 8
            io.print indx.value
            # clean up
            info[:cur] = []
            io.seek 0, IO::SEEK_END
          end
        end
        # size of movi
        size = io.pos - data_offset
        io.pos = data_offset - 4
        io.print [size].pack('V')
        io.seek 0, IO::SEEK_END
        io.print "\0" if size % 2 == 1
        vid_frames_size
      end

      File.open(path, 'w+') do |io|
        io.binmode
        @movi.rewind
        # normal AVI
        # header
        io.print 'RIFF'
        io.print "\0\0\0\0"
        io.print 'AVI '
        @riff.first.value.each do |chunk|
          break if chunk.id == 'movi'
          print_chunk io, chunk
        end
        # movi
        vid_size = write_movi.call io
        # rewrite frame count in avih header
        io.pos = 48
        io.print [vid_size].pack('V')
        io.seek 0, IO::SEEK_END
        # idx1
        io.print 'idx1'
        io.print [@index_pos * 16].pack('V')
        @indices[0..(@index_pos - 1)].each do |ix|
          io.print ix[:id] + [ix[:flag], ix[:offset] + 4, ix[:size]].pack('V3')
        end
        # rewrite riff chunk size
        avisize = io.pos - 8
        io.pos = 4
        io.print [avisize].pack('V')
        io.seek 0, IO::SEEK_END

        # AVI2.0
        while @index_pos < @indices.size
          io.print 'RIFF'
          io.print "\0\0\0\0"
          riff_offset = io.pos
          io.print 'AVIX'
          # movi
          write_movi.call io
          # rewrite total chunk size
          avisize = io.pos - riff_offset
          io.pos = riff_offset - 4
          io.print [avisize].pack('V')
          io.seek 0, IO::SEEK_END
        end
      end
    end

    ##
    # Searches and returns RIFF values with the passed search +args+.
    # +args+ should point the ids of the tree structured RIFF data 
    # under the 'AVI ' chunk without omission, like:
    # 
    #   avi.search 'hdrl', 'strl', 'indx'
    #
    # It returns a list of RiffChunk object which can be modified directly.
    # (RiffChunk class which is returned through this method also has a #search
    # method with the same interface as this class.)
    # This method seeks in the first RIFF 'AVI ' tree.
    def search *args
      @riff.first.search *args
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

    def print_chunk io, chunk
      offset = io.pos
      if chunk.is_list?
        io.print chunk.list
        io.print "\0\0\0\0"
        io.print chunk.id
        chunk.value.each do |c|
          print_chunk io, c
        end
      else
        io.print chunk.id
        io.print "\0\0\0\0"
        io.print chunk.value
      end
      # rewrite size
      size = io.pos - offset - 8
      io.pos = offset + 4
      io.print [size].pack('V')
      io.seek 0, IO::SEEK_END
      io.print "\0" if size % 2 == 1
    end

    def expected_position_of chunk
      pos = -1
      cur = 12
      seek = -> (chk) do
        if chk === chunk
          pos = cur
          return
        end
        if chk.is_list?
          cur += 12
          chk.value.each do |c|
            seek.call c
          end
        else
          cur += 8
          cur += chk.value.nil? ? chk.binsize : chk.value.size
        end
      end
      headers = @riff.first.value
      headers.each do |c|
        seek.call c
      end
      pos
    end

    # ----------------------------------------------------------------

    def parse_avi1_indices data  #:nodoc:
      # The function Frsmes#fix_offsets_if_needed in previous versions is now removed. 
      i = 0
      while i * 16 < data.size do
        @indices << {
          :id     => data[i * 16, 4],
          :flag   => data[i * 16 + 4, 4].unpack('V').first,
          :offset => data[i * 16 + 8, 4].unpack('V').first - 4,
          :size   => data[i * 16 + 12, 4].unpack('V').first,
        }
        i += 1
      end
    end

    def parse_avi2_indices data, offset #:nodoc:
      id = data[8, 4]
      nent = data[4, 4].unpack('V').first
      h = 24
      i = 0
      while h + i * 8 < data.size
        of = offset + data[24 + i * 8, 4].unpack('V').first - 12 # 12 for movi + 00dc#### 
        sz = data[h + i * 8 + 4, 4].unpack('V').first
        fl = (sz >> 31 == 1) ? 0 : Frame::AVIIF_KEYFRAME # bit 31 is set if this is NOT a keyframe
        zs = sz & 0b0111_1111_1111_1111_1111_1111_1111_1111
        @indices << {
          :id     => id,
          :flag   => fl,
          :offset => of,
          :size   => zs,
        }
        i += 1
      end
    end

    private :parse_avi1_indices, :parse_avi2_indices

    class << self
      ##
      # Parses RIFF structured file from +path+ and returns a formatted +String+.
      def rifftree path, out = nil
        returnable = out.nil? 
        out = StringIO.new if returnable 

        parse = ->(io, depth = 0, len = 0) do
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
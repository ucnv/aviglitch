module AviGlitch
  class Tempfile < Tempfile
    def initialize *args
      super *args
      self.binmode
    end
  end
end

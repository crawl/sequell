module Henzell
  class Env
    def self.hostname
      @hostname ||= find_hostname
    end

    def self.find_hostname
      ENV['HENZELL_HOST'] || %x{hostname -f 2>/dev/null}.strip || 'localhost'
    end
  end
end

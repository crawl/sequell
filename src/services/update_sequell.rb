module Services
  class UpdateSequell
    def self.run
      STDERR.puts "Updating Sequell"
      system "cd #{ENV['HENZELL_ROOT']} && git pull"
    end
  end
end

module Graph
  class Url
    def self.file_url(filename)
      require 'henzell/env'
      "http://#{Henzell::Env.hostname}/graphs/#{filename}"
    end
  end
end

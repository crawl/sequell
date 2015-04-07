module Services
  class CrawlBuild
    def self.rebuild
      STDERR.puts "Rebuilding Crawl"
      system "cd #{ENV['HENZELL_ROOT']} && ./scripts/update-crawl-source"
    end
  end
end

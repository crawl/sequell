module Henzell
  class Source
    def initialize(config)
      @config = config
    end

    def name
      @name ||= @config['name']
    end

    def aliases
      @aliases ||= (@config['aliases'] || [])
    end

    def morgue_paths
      require 'henzell/server/morgue_path'
      @morgue_paths ||= @config['morgues'].map { |morgue_cfg|
        Henzell::Server::MorguePath.new(self, morgue_cfg)
      }
    end

    def ttyrec_urls
      @ttyrec_urls ||= @config['ttyrecs']
    end

    def utc_epoch
      return nil unless @config['utc-epoch']
      @utc_epoch ||= DateTime.strptime(@config['utc-epoch'], '%Y%m%d%H%M%z')
    end

    def timezone(type)
      return nil unless @config['timezones']
      @config['timezones'][type]
    end
  end
end

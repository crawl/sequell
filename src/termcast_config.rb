require 'crawl/config'

class TermcastConfig
  def self.server
    config['server']
  end

  def self.client_protocols
    config['client-protocols']
  end

  def self.client_urls
    termcast_server = self.server
    client_protocols.map { |proto| "#{proto}://#{termcast_server}" }
  end

  def self.config
    @config ||= Crawl::Config['termcast']
  end
end

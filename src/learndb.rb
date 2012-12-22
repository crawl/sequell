require 'rest-client'

module LearnDB
  DB_URL = 'http://crawl.akrasiac.org/learndb'

  def self.valid_entry_name?(name)
    canonical_name = canonical_entry_name(name)
    canonical_name && !canonical_name.empty?
  end

  def self.canonical_entry_name(name)
    name.downcase.tr(' ', '_').gsub(/^_+|_+$/, '').gsub(/[^a-z0-9_!]+/, '')
  end

  def self.entry(entry_name)
    Entry.new(canonical_entry_name(entry_name))
  end

  class Entry
    def initialize(name)
      @name = name
      @entries = { }
      @size = nil
    end

    def exists?
      self.size > 0
    end

    def size
      @size ||= find_entry_size
    rescue RestClient::ResourceNotFound
      @size = 0
    end

    def [](index)
      return nil if @size && (index < 0 || index >= @size)
      @entries[index] ||= load_entry(index)
    end

  private
    def list_url
      DB_URL + '/' + @name + '/'
    end

    def entry_url(index)
      list_url + (index + 1).to_s
    end

    def find_entry_size
      listing = RestClient.get(list_url)
      listing.scan(/<a\s+href\s*=\s*["'](\d+)["']/i).size
    end

    def load_entry(index)
      RestClient.get(entry_url(index)).strip
    end
  end
end

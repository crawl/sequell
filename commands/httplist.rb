#! /usr/bin/env ruby

# Fetch http directory listings from the web.
module HttpList
  require 'date'
  require 'set'

  require 'pcache'

  def self.urljoin(a, b)
    if a.empty?
      b
    elsif a =~ %r{/$}
      a + b
    else
      a + "/" + b
    end
  end

  class HttpFile
    attr_reader :filename, :baseurl

    def initialize(filename, baseurl)
      @filename = filename
      @baseurl = baseurl
    end

    def <=> (other)
      @filename <=> other.filename
    end

    def url
      HttpList.urljoin(@baseurl, @filename)
    end

    def == (other)
      other_file = other.respond_to?(:filename) ? other.filename : other
      @filename == other_file
    end

    def hash
      @filename.hash
    end

    def to_s
      url
    end
  end

  def self.fetch_raw_html(url)
    %x{curl --max-time 180 #{url} 2>/dev/null}
  end

  def self.each_match(regex, text)
    match = nil
    while true
      text = match ? text[match.end(0) .. -1] : text
      match = regex.match(text)
      yield(match) if match
      break unless match
    end
  end

  def self.files_matching(html, regex)
    files = [ ]
    file_regex = /href\s*=\s*["']([^"']*)["']/is
    self.each_match(file_regex, html) do |m|
      # Remove leading ./
      file = m[1].sub(%r{^[.]/}, '')
      files << file if file =~ regex
    end
    files
  end

  def self.find_files(url, file_regex, timewanted=DateTime.now)
    if url.is_a?(Array)
      fileset = Set.new
      for suburl in url do
        files = self.find_files(suburl, file_regex, timewanted)
        fileset.merge(files)
      end
      return fileset.to_a.sort
    end

    key = "#{file_regex}:#{url}"
    listing = PCache::find(key, timewanted)
    if not listing
      now = DateTime.now
      raw_html = self.fetch_raw_html(url)
      if raw_html !~ %r{/html}is
        raise StandardError.new("Could not fetch directory listing from #{url}")
      end
      listing = self.files_matching(raw_html, file_regex).sort
      PCache::add(key, listing.join('|'), now)
    else
      STDERR.puts("Using cached file listing for #{key}")
      listing = listing.split('|')
    end
    return listing.map { |f| HttpFile.new(f, url) }
  end
end

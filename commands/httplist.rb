#! /usr/bin/ruby

# Fetch http directory listings from the web.
module HttpList
  require 'date'
  require 'commands/pcache'

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
    key = "#{file_regex}:#{url}"
    listing = PCache::find(key, timewanted)
    if not listing
      now = DateTime.now
      STDERR.puts("Fetching file listing for #{file_regex} from #{url}")
      raw_html = self.fetch_raw_html(url)
      STDERR.puts("Listing:\n#{raw_html}")
      if raw_html !~ %r{/html}is
        raise Exception.new("Could not fetch directory listing from #{url}")
      end
      listing = self.files_matching(raw_html, file_regex).sort
      STDERR.puts("Extracted #{listing.size} entries from #{url} for #{file_regex}")
      PCache::add(key, listing.join('|'), now)
    else
      STDERR.puts("Using cached file listing for #{key}")
      listing = listing.split('|')
    end
    return listing
  end
end

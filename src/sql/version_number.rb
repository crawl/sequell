module Sql
  class VersionNumber
    CANONICAL_VERSION_SEGMENTS = 3

    def self.version_number?(text)
      text =~ /^\d+\.\d+(?:\.\d+)*/
    end

    def self.version_numberize(version_string)
      return 0 if version_string.to_s.empty?
      version, qualifier = version_string.split('-', 2)
      qualifier ||= ''

      version_number_score(version) + qualifier_score(qualifier)
    end

    def self.version_base
      1_00_00_0000
    end

    def self.version_number_score(version)
      version_segments = self.segment_version(version)
      base = self.version_base
      score = 0
      version_segments.reverse.each do |segment|
        score += base * segment
        base  *= 1000
      end
      score
    end

    def self.split_qualifier(qualifier)
      if qualifier =~ /^([a-z]+)([0-9]*)(?:-(\d+))?/
        return [$1, $2, $3]
      elsif qualifier =~ /^(\d+)-/
        return ["", "", $1]
      end
      ["", "", ""]
    end

    def self.qualifier_score(qualifier)
      return 99_00_0000 if !qualifier || qualifier.empty?
      prefix, index, rev = split_qualifier(qualifier)
      rev ||= 0
      index ||= 0
      index = index.to_i
      rev = rev.to_i
      return prefix_score(prefix) * 1_00_0000 + index * 10000 + rev
    end

    def self.prefix_score(prefix)
      return 99 if prefix.empty?
      (prefix.ord - 'a'.ord + 1)
    end

    def self.segment_version(version)
      version_pieces = version.split('.')
      if version_pieces.size < CANONICAL_VERSION_SEGMENTS
        version_pieces += ['0'] * (CANONICAL_VERSION_SEGMENTS -
                                   version_pieces.size)
      end
      version_pieces.map { |piece| piece.to_i }
    end
  end
end

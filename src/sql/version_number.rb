module Sql
  class VersionNumber
    CANONICAL_VERSION_SEGMENTS = 3

    def self.version_number?(text)
      text =~ /^\d+\.\d+(?:\.\d+)*(?:-[a-z]+[0-9]*)?$/
    end

    def self.version_numberize(version_string)
      version, qualifier = version_string.split('-')
      qualifier ||= ''

      version_number_score(version) + qualifier_score(qualifier)
    end

    def self.version_base
      100000000
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

    def self.qualifier_score(qualifier)
      return self.version_base - 1 if !qualifier || qualifier.empty?
      if qualifier =~ /^([a-z]+)([0-9]*)(?:-(\d+))?$/
        prefix, index, rev = $1, $2, $3
        rev ||= 0
        index ||= 0
        index = index.to_i
        rev = rev.to_i

        prefix = prefix.ord - 'a'.ord + 1
        return prefix * 1000000 + index * 10000 + rev
      end
      self.version_base - 1
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

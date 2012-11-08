module Sql
  class VersionNumber
    CANONICAL_VERSION_SEGMENTS = 4

    def self.version_number?(text)
      text =~ /^\d+\.\d+(?:\.\d+)*(?:-[a-z]+[0-9]*)?$/
    end

    def self.version_numberize(version_string)
      version, qualifier = version_string.split('-')
      qualifier ||= ''

      version_number_score(version) + qualifier_score(qualifier)
    end

    def self.version_number_score(version)
      version_segments = self.segment_version(version)
      base = 1_000_000
      score = 0
      version_segments.reverse.each do |segment|
        score += base * segment
        base  *= 1000
      end
      score
    end

    def self.qualifier_score(qualifier)
      return 999 * 999 if !qualifier || qualifier.empty?
      if qualifier =~ /^([a-z]+)([0-9]*)$/
        prefix, index = $1, $2
        index ||= 0
        index = index.to_i

        if prefix.respond_to?(:ord)
          prefix = prefix.ord
        else
          prefix = prefix[0]
        end
        return prefix * 1000 + index
      end
      999 * 999
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

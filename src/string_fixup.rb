class StringFixup
  def initialize(fixup_map)
    @map = Hash[fixup_map.map { |key, value|
        value = [value] unless value.is_a?(Array)
        value = value.map { |r|
          r.sub(%r/\$(\d)/, '\\\1')
        }
        [%r/#{key}/i, value]
      }]
  end

  def fixup(text)
    for regex, replacements in @map
      if text =~ regex
        return replacements.map { |r|
          text.sub(regex, r)
        }
      end
    end
    [text]
  end
end

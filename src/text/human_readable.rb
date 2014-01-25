module Text
  class HumanReadable
    def self.format_number(num)
      str = num.to_s
      str.reverse.gsub(/(\d\d\d)(?=\d)(?!\d*\.)/, '\1,').reverse
    end
  end
end

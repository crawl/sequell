require 'query/ast/option'
require 'query/ast/tv_option'
require 'grammar/config'

module Query
  module AST
    class OptionBuilder
      def self.build(name, args)
        name = name.downcase
        reject_unknown_option!(name) unless known_option?(name)
        if name == 'tv'
          TVOption.new(name, args)
        else
          Option.new(name, args)
        end
      end

      def self.known_option?(name)
        ::Grammar::Config.option_names.include?(name.downcase)
      end

      def self.reject_unknown_option!(name)
        raise "Unknown option: #{name}"
      end
    end
  end
end

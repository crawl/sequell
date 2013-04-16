require 'grammar/config'
require 'cmd/user_def'
require 'cmd/user_command_db'

module Cmd
  class UserFunction < UserDef
    @@function_definitions = { }
    def self.function_definition(name)
      return name unless name.is_a?(String)
      name = canonicalize_name(name)
      @@function_definitions[name] ||= find_definition(name)
    end

    def self.expand_definition(name, definition)
      "$(fn #{name} #{definition})"
    end

    def self.define(name, definition)
      assert_name_valid!(name = canonicalize_name(name))
      parsed_def = Tpl::Template.template(expand_definition(name, definition))
      unless parsed_def.is_a?(Tpl::Function)
        raise "Invalid definition: must be parseable as a function"
      end
      existing = self.function(name)
      UserCommandDb.db.define_function(name, definition)
      final = self.function(name)
      if existing
        puts("Redefined function: #{final} (was: #{existing})")
      else
        puts("Defined function: #{final}")
      end
      final
    end

    def self.functions
      UserCommandDb.db.functions.map { |name, definition|
        self.new(name, definition)
      }
    end

    def self.function(name)
      name = canonicalize_name(name)
      definition = UserCommandDb.db.query_function(name)
      return nil unless definition && definition[0]
      self.new(definition[0], definition[1])
    end

    def self.delete(name)
      name = canonicalize_name(name)
      assert_name_valid!(name)
      definition = self.function(name)
      raise "No user function '#{name}'" unless definition
      UserCommandDb.db.delete_function(name)
      definition
    end

    def self.canonicalize_name(name)
      name.strip
    end

    def self.reserved_name?(name)
      ::Grammar::Config['reserved-names'].include?(name)
    end

    def self.builtin?(name)
      Tpl::FunctionDef.builtin?(name)
    end

    def self.valid_name?(name)
      name =~ /^\w[\w+-]*[?]?$/ && !reserved_name?(name) && !builtin?(name)
    end

    def self.assert_name_valid!(name)
      unless valid_name?(name)
        if builtin?(name) || reserved_name?(name)
          raise "Invalid function name: #{name} (#{name} is a built-in)"
        end
        raise "Invalid function name: #{name}"
      end
    end

    def to_s
      "!fn #{name} #{definition}"
    end

  private
    def self.find_definition(name)
      fn = self.function(name)
      return nil unless fn
      Tpl::Template.template(expand_definition(fn.name, fn.definition))
    end
  end
end

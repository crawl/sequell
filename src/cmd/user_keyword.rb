require 'cmd/user_command_db'
require 'cmd/user_def'
require 'query/query_string'
require 'query/query_keyword_parser'
require 'query/listgame_parser'

module Cmd
  class RecursiveKeywordError < StandardError
    attr_reader :name
    def initialize(name)
      super("Recursive definition for '#{name}'")
      @name = name
    end
  end

  class UserKeyword
    KEYWORD_REGEX = /^[\w@_.:+*&#$~`'"-]+$/

    @@tracking_recursion = nil

    def self.define(name, definition)
      name = canonicalize_name(name)
      assert_name_valid!(name)

      UserCommandDb.db.delete_keyword(name)
      assert_definition_parseable!(definition)

      existing_keyword = self.keyword(name)
      UserCommandDb.db.define_keyword(name, definition)
      final_keyword = self.keyword(name)
      if existing_keyword
        puts("Redefined keyword: #{final_keyword} (was: #{existing_keyword})")
      else
        puts("Defined keyword: #{final_keyword}")
      end
      final_keyword
    end

    def self.keywords
      UserCommandDb.db.keywords.map { |name, definition|
        UserDef.new(name, definition)
      }
    end

    def self.each(&block)
      self.keywords.each(&block)
    end

    def self.keyword(name)
      definition = UserCommandDb.db.query_keyword(canonicalize_name(name))
      return nil unless definition
      track_recursion(definition[0])
      UserDef.new(definition[0], definition[1])
    end

    def self.track_recursion(name)
      return unless @@tracking_recursion
      raise RecursiveKeywordError.new(name) if @@tracking_recursion[name]
      @@tracking_recursion[name] = true
    end

    def self.kill_recursive_keyword
      previous = @@tracking_recursion
      begin
        if @@tracking_recursion
          @@tracking_recursion = @@tracking_recursion.dup
        else
          @@tracking_recursion = { }
        end
        yield
      ensure
        @@tracking_recursion = previous
      end
    end

    def self.delete(name)
      name = canonicalize_name(name)
      begin
        assert_name_valid!(name)
      rescue RecursiveKeywordError => ignored
      end
      existing_keyword = self.keyword(name)
      raise "No user keyword '#{name}'" if existing_keyword.nil?
      UserCommandDb.db.delete_keyword(name)
      existing_keyword
    end

    def self.canonicalize_name(name)
      name.downcase.strip
    end

    def self.valid_keyword_name?(name)
      name.downcase =~ KEYWORD_REGEX
    end

  private

    def self.assert_definition_parseable!(definition)
      # Verify that the definition parses:
      CTX_STONE.with do
        Query::ListgameParser.fragment(definition)
      end
    end

    def self.assert_name_valid!(name)
      name = name.downcase
      unless valid_keyword_name?(name)
        raise "Invalid keyword string: #{name}"
      end

      begin
        parse = CTX_STONE.with do
          Query::QueryKeywordParser.parse(name)
        end
        unless self.keyword(name)
          raise "'#{name}' is built-in: #{name} => #{parse.to_query_string}"
        end
      rescue Query::KeywordParseError
      end
    end
  end
end

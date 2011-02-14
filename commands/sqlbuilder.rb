#! /usr/bin/env ruby

require 'rubygems'
require 'treetop'
require 'commands/lg_node'
require 'commands/lg'

module SQLBuilder
  def self.query(params)
    query = SQLQuery.new(params)
    query_executor = SQLQueryExecutor.new(query)
    query_executor.execute
  rescue QueryError
    puts $!
  end

  class QueryError < Exception
    def initialize(message)
      @message = message
    end

    def to_s
      @message
    end
  end

  class QueryParseError < QueryError
    def initialize(cmdline, error_index)
      @cmdline = cmdline
      @error_index = error_index
      super.initialize("Malformed query at `#{cmdline[error_index .. -1]}`")
    end
  end

  class SQLQuery
    def initialize(config)
      @config = config
      @cmdline = strip_command_identifier(config[:cmdline])
      @parser = ListgameQueryParser.new
      @query_ast = @parser.parse(@cmdline)
      if @query_ast.nil?
        raise QueryParseError.new(@cmdline, @parser.failure_index)
      end
      @query = QueryNode.resolve_node(@query_ast)

      validate_query
    end

    def validate_query
      # Check for common problems:
      assert(!@query.has_query_mode?) do
        "#{@query.query_mode} not permitted in top-level query"
      end

      assert(!@query.has_multiple_result_indices?) do
        extra_indexes = @query.result_indices[1 .. -1]
        "Too many result indexes in query (extras: #{extra_indexes.join(', ')})"
      end
    end

    def assert(condition)
      if !condition
        err(yield)
      end
    end

    def err(message)
      raise QueryError.new(message)
    end

    def count_query
      "SELECT COUNT(*) #{query_sql}"
    end

    def select_query
      "SELECT #{query_select_fields.join(', ')} #{query_sql}"
    end

    def query_sql
      query_tables = @query.my_query_tables
    end
  end

  class SQLQueryExecutor
  end

  class QueryNode
    def self.resolve_elements(children)
      return [] if children.nil?
      results = []
      for c in children
        resolved = self.resolve_node(c)
        next if resolved.nil?
        if resolved.is_a?(Array)
          results += resolved
        else
          results << resolved
        end
      end
      results
    end

    def self.resolve_node(syntax_node)
      value =
        if syntax_node.lg_node
          QueryNode.new(syntax_node)
        else
          children = self.resolve_elements(syntax_node.elements)
          if children.size == 1
            children[0]
          else
            children
          end
        end
      if (value.is_a?(QueryNode) &&
          value.elements.size == 1 && value.elements[0].tag == value.tag &&
          value.elements[0].interval == value.interval) then
        return value.elements[0]
      end
      value
    end

    attr_reader :elements, :tag, :interval, :text

    def initialize(syntax_node)
      @tag = syntax_node.lg_node
      @elements = QueryNode.resolve_elements(syntax_node.elements)
      @text = syntax_node.text_value.strip
      @interval = syntax_node.interval
    end

    def has_query_mode?
      !!query_mode
    end

    ##
    # Returns the given query's query_mode (!lg/!lm) without looking at
    # subqueries.

    def query_mode
      node_text(node_tagged(:querymode, :exclude => :subquery))
    end

    def has_subqueries?
      subqueries.size > 0
    end

    def subqueries
      nodes_tagged(:subquery)
    end

    ##
    # Find all subqueries immediately under the current query, i.e. no
    # subsubqueries.

    def immediate_subqueries
      my_nodes_tagged(:subquery)
    end

    ##
    # Return all query keywords, such as DEFE, win, D:22

    def keywords
      my_nodes_tagged(:querykeywordexpr)
    end

    def nick_selector
      my_node_tagged(:nickselector)
    end

    def result_index
      my_node_tagged(:result_index)
    end

    def result_indices
      my_nodes_tagged(:result_index)
    end

    def has_multiple_result_indices?
      result_indices.size > 1
    end

    ##
    # Returns a node's text, or nil if the node is nil

    def node_text(node)
      node && node.text
    end

    ##
    # Returns the first node with the given tag in this query, i.e. not
    # in subqueries.

    def my_node_tagged(tag, options={})
      my_nodes_tagged(tag, options)[0]
    end

    ##
    # Returns all nodes with the given tag in this query, i.e. not in
    # subqueres.

    def my_nodes_tagged(tag, options={})
      options = options.dup
      options[:exclude_descent] = :subquery
      nodes_tagged(tag, options)
    end

    ##
    # Retrieves the first node with the given tag, searching recursively.

    def node_tagged(tag, options={})
      nodes_tagged(tag, options)[0]
    end

    ##
    # Retrieves all nodes with the given tag, searching recursively.

    def nodes_tagged(tag, options={})
      found_nodes = []
      @elements.each do |e|
        if node_included?(e, options) && !node_excluded?(e, options)
          found_nodes << e if e.tag == tag
          unless options[:exclude_match] || node_descent_excluded?(e, options)
            found_nodes += e.nodes_tagged(tag, options)
          end
        end
      end
      found_nodes
    end

    def node_included? (node, options)
      includes = options[:include]
      !includes || node.tag == includes || includes.include?(node.tag)
    end

    def node_excluded? (node, options)
      excludes = options[:exclude]
      node_matches_exclude?(node, excludes)
    end

    def node_descent_excluded? (node, options)
      excludes = options[:exclude_descent]
      node_matches_exclude?(node, excludes)
    end

    def node_matches_exclude? (node, excludes)
      excludes && (node.tag == excludes || excludes.include?(node.tag))
    end

    def to_s
      "#{@tag} (#{@text})"
    end
  end
end

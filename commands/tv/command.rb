require 'sqlhelper'
require 'set'
require 'learndb'
require 'cmd/command'

module TV
  class ChannelQuery
    def self.run(channel_name, ctx)
      TV::ChannelManager.query_channel(channel_name)
    end
  end

  class ChannelDelete
    def self.run(channel_name, ctx)
      TV::ChannelManager.delete_channel(channel_name)
    end
  end

  class ChannelCreate
    MIN_QUERY_RESULTS = 10
    VALID_COMMANDS = Set.new(['!lg', '!lm', '??'])

    def self.run(channel_name, ctx)
      self.new(channel_name, ctx).run
    end

    def initialize(channel_name, ctx)
      @channel_name = channel_name
      @ctx = ctx
      @queries = ctx.argument_string.split(';;').map(&:strip).map { |query|
        Cmd::Command.new(query)
      }
    end

    def run
      assert_queries_valid!
      define_channel
    end

    def define_channel
      TV::ChannelManager.add_channel(@channel_name, @queries.join(' ;; '))
    end

    private
    def assert_queries_valid!
      @queries.each { |q| assert_valid_query!(q) }
      total_results = @queries.map { |q| query_result_count(q) }.inject(:+)
      if !total_results || total_results < MIN_QUERY_RESULTS
        raise StandardError, "Cannot define channel: the query must supply at least #{MIN_QUERY_RESULTS} results."
      end
    end

    def assert_valid_command!(cmd)
      unless VALID_COMMANDS.include?(cmd)
        raise StandardError, "Command (#{cmd}) must be one of #{VALID_COMMANDS.join(',')}"
      end
    end

    def assert_valid_query!(q)
      if q.command == '??'
        assert_valid_learndb_query!(q)
      else
        assert_valid_sql_query!(q)
      end
    end

    def assert_valid_learndb_query!(q)
      unless (LearnDB.valid_entry_name?(q.argument_string) &&
              LearnDB.entry(q.argument_string).exists?)
        raise StandardError, "Invalid entry name: #{q.argument_string}"
      end
    end

    def assert_valid_sql_query!(q)
      query = parse_query(q)
      if query.size > 1
        raise StandardError, "Cannot define TV channel with double query"
      end

      if query.primary_query.summarise?
        raise StandardError, "Cannot define TV channel with summary query"
      end
    end

    def query_result_count(q)
      if q.command == '??'
        learndb_result_count(q)
      else
        sql_query_result_count(q)
      end
    end

    def learndb_result_count(q)
      LearnDB.entry(q.argument_string).size
    end

    def sql_query_result_count(q)
      query = parse_query(q)
      query.with_context {
        q = query.primary_query
        result = sql_exec_query(q.num, q)
        return result.count
      }
    end

    def parse_query(q)
      QueryParser.parse(q)
    end
  end

  class QueryParser
    def self.parse(command)
      self.new(command).parse
    end

    def initialize(command)
      @command = command
    end

    def query_context
      @command.command == '!lg' ? CTX_LOG : CTX_STONE
    end

    def parse
      TV.with_tv_opts(@command.arguments) do |args, tvopt|
        args, opts = extract_options(args, 'game')
        sql_parse_query('???', args, self.query_context)
      end
    end
  end
end

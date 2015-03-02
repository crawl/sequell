require 'formatter/game_text'
require 'formatter/game_json'
require 'libtv'
require 'response'

module Query
  class OptionExecutor
    def self.execute(query_executor)
      self.new(query_executor).execute
    end

    attr_reader :query_executor
    def initialize(query_executor)
      @query_executor = query_executor
    end

    def q
      @q ||= query_executor.primary
    end

    def result
      @result ||= query_executor.query_result
    end

    def first
      result.first
    end

    def option(x)
      q.option(x)
    end

    def execute
      apply_option
    end

  private

    def apply_option
      if q.ctx.milestone?
        apply_milestone_options
      else
        apply_logfile_options
      end
    end

    def apply_logfile_options
      case
      when option(:tv)
        report_game_with(first, tv: execute_tv(first))
      when option(:log)
        report_game_with(first, log: execute_log(first))
      when option(:ttyrec)
        report_game_with(first, ttyrecs: execute_ttyrec(first))
      else
        nil
      end
    end

    def report_game_with(r, opts={})
      game_formatter.format(r, opts)
    end

    def report_mile_game_with(r, game, opts={})
      game_formatter.format_milestone_game(r, game, opts)
    end

    def apply_milestone_options
      if option(:log) && first.game['verb'] == 'crash'
        report_game_with(first, log:
          find_milestone_crash_dump(first.game) || "Can't find crash dump")
      elsif option(:game) || option(:log)
        milestone_game = first.milestone_game
        unless milestone_game
          return report_mile_game_with(first, milestone_game)
        end
        case
        when option(:log)
          report_mile_game_with(
            first, milestone_game,
            log: protect("Can't find morgue") {
              find_game_morgue(milestone_game)
            })
        when option(:ttyrec)
          report_mile_game_with(
            first, milestone_game,
            ttyrecs: protect("Can't find ttyrec") {
              find_game_ttyrecs(milestone_game)
            })
        when option(:tv)
          report_mile_game_with(
            first, milestone_game,
            tv: TV.request_game_verbosely(
              first.game_key, milestone_game, q.nick, option(:tv)))
        else
          report_game_with(Sql::QueryResult.game(milestone_game, first))
        end
      elsif option(:ttyrec)
        report_game_with(first, ttyrecs: execute_ttyrec(first))
      elsif option(:tv)
        game = first.game
        if option(:tv).seek_to_game_end?
          milestone_game = first.milestone_game
          game['end'] = milestone_game && milestone_game['end']
        end
        report_game_with(first, tv: execute_tv(first))
      end
    end

    def execute_tv(r)
      TV.request_game_verbosely(
        r.qualified_index, r.game,
        q.nick, option(:tv))
    end

    def execute_log(r)
      protect("Can't find morgue") {
        find_game_morgue(first.game)
      }
    end

    def execute_ttyrec(r)
      protect("Can't find ttyrec") {
        find_game_ttyrecs(r.game)
      }
    end

    def format(value)
      formatter.format(value)
    end

    def game_formatter
      if query_executor.json?
        Formatter::GameJSON
      else
        Formatter::GameText
      end
    end

    def protect(stub)
      begin
        yield || stub
      rescue
        "#{stub}: #$!"
      end
    end
  end
end

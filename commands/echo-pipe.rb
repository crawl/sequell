#! /usr/bin/env ruby

require 'query/query_string_template'
require 'cmd/executor'
require 'json'
require 'env'
require 'command_context'
require 'timeout'
require 'cmd/user_function'

STDIN.sync = true
STDERR.sync = true
STDOUT.sync = true

TIME_LIMIT = 60

logf = File.open('echo-pipe.log', 'w')
logf.sync = true

begin
  while (line = STDIN.readline)
    begin
      data = JSON.parse(line)
      Timeout.timeout(TIME_LIMIT) {
        Env.with(data['command_env']) do
          Cmd::UserFunction.clear_cache!
          CommandContext.with_default_nick((data['env'] || { })['nick']) do
            Cmd::Executor.with_default_env(data['env']) do
              puts JSON.dump(res: Query::QueryStringTemplate.expand(
                  data['msg'],
                  data['args'] || '',
                  data['env'] || { }))
            end
          end
        end
      }
    rescue Timeout::Error
      puts JSON.dump(err: "Time limit of #{TIME_LIMIT} exceeded")
    rescue
      puts JSON.dump(err: $!.message)
      logf.puts("Failed to evaluate #{line}: #$!")
      logf.puts($!.backtrace.map { |x| "  #{x}" }.join("\n"))
    end
  end
rescue EOFError
  # Normal shutdown
end

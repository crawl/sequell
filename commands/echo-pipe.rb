#! /usr/bin/env ruby

require 'query/query_string_template'
require 'cmd/executor'
require 'json'
require 'env'
require 'command_context'
require 'timeout'
require 'helper'
require 'cmd/user_function'

STDIN.sync = true
STDERR.sync = true
STDOUT.sync = true

TIME_LIMIT = 60

logf = File.open('echo-pipe.log', 'w')
logf.sync = true

ENV['RAISE_AUTH_ERRORS'] = 'y'
begin
  opid = nil
  while (line = STDIN.readline)
    begin
      data = JSON.parse(line)
      opid = data['id']
      Timeout.timeout(TIME_LIMIT) {
        Env.with(data['command_env']) do
          Cmd::UserFunction.clear_cache!
          NickDB.reload!
          CommandContext.with_default_nick((data['env'] || { })['nick']) do
            Cmd::Executor.with_default_env(data['env']) do
              puts JSON.dump(
                id: opid,
                res: Query::QueryStringTemplate.expand(
                  data['msg'],
                  data['args'] || '',
                  data['env'] || { }))
            end
          end
        end
      }
    rescue Timeout::Error
      puts JSON.dump(id: opid, err: "Time limit of #{TIME_LIMIT} exceeded")
    rescue
      puts JSON.dump(id: opid, err: $!.message)
      logf.puts("Failed to evaluate #{line}: #$!")
      logf.puts($!.backtrace.map { |x| "  #{x}" }.join("\n"))
    ensure
      opid = nil
    end
  end
rescue EOFError
  # Normal shutdown
end

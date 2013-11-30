#! /usr/bin/env ruby

require 'query/query_string_template'
require 'json'
require 'env'
require 'command_context'
require 'timeout'

STDIN.sync = true
STDERR.sync = true
STDOUT.sync = true

TIME_LIMIT = 60

begin
  while (line = STDIN.readline)
    begin
      data = JSON.parse(line)
      Timeout.timeout(TIME_LIMIT) {
        Env.with(data['command_env']) do
          CommandContext.with_default_nick((data['env'] || { })['nick']) do
            puts JSON.dump(res: Query::QueryStringTemplate.expand(
                data['msg'],
                data['args'] || '',
                data['env'] || { }))
          end
        end
      }
    rescue Timeout::Error
      puts JSON.dump(err: "Time limit of #{TIME_LIMIT} exceeded")
    rescue
      puts JSON.dump(err: $!.message)
    end
  end
rescue EOFError
  # Normal shutdown
end

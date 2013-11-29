#! /usr/bin/env ruby

require 'query/query_string_template'
require 'json'
require 'env'
require 'command_context'

STDIN.sync = true
STDERR.sync = true
STDOUT.sync = true

begin
  while (line = STDIN.readline)
    begin
      data = JSON.parse(line)
      Env.with(data['command_env']) do
        CommandContext.with_default_nick((data['env'] || { })['nick']) do
          puts JSON.dump(res: Query::QueryStringTemplate.expand(
              data['msg'],
              data['args'] || '',
              data['env'] || { }))
        end
      end
    rescue
      puts JSON.dump(err: $!.message)
    end
  end
rescue EOFError
  # Normal shutdown
end

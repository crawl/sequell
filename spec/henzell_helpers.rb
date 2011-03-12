require 'commands/sql_builder'

module HenzellHelpers
  include SQLBuilder

  def lg(cmdline, context='!lg', nick='nobody')
    SQLQuery.new(:context => context,
                 :nick => nick,
                 :cmdline => cmdline)
  end

  def lg_error(cmdline, context='!lg', nick='nobody')
    lg(cmdline, context, nick)
    raise Exception.new("Expected #{cmdline} parse to fail, but it succeeded")
  rescue SQLBuilder::QueryError
    $!.to_s
  end
end

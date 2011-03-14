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

  ##
  # Calls each_method on object, and recursively on every returned object
  # that responds to the method and returns a list of the returned objects
  # converted to strings.
  def recursive_collect(object, each_method, collection=nil)
    collection ||= []
    object.send(each_method) do |node|
      collection << node
      if node.respond_to?(each_method)
        recursive_collect(node, each_method, collection)
      end
    end
    collection
  end

  def recursive_collect_text(object, each_method)
    recursive_collect(object, each_method).map { |node| node.text }
  end
end

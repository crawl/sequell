require 'commands/sql_builder'

module HenzellHelpers
  include SQLBuilder

  def lg(cmdline, nick='nobody')
    SQLQuery.new(:nick => nick,
                 :cmdline => cmdline)
  end

  def lg_collect_text(cmdline, each_method, nick='nobody')
    recursive_collect_text(lg(cmdline, nick), each_method)
  end

  def lg_error(cmdline, nick='nobody')
    lg(cmdline, nick)
    raise Exception.new("Expected `#{cmdline}` parse to fail, but it succeeded")
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

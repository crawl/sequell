#!/usr/bin/env ruby
require 'commands/sqlbuilder'

parser = ListgameQueryParser.new

def node_name(node)
  node.lg_node.to_s
end

def not_empty?(x)
  x and not x.strip.empty?
end

def indent(level)
  dent = ""
  (level - 1).times do
    dent << "    "
  end
  dent << "|---#{level}-" if level > 0
  dent
end

def string_tree(node, level=0)
  return "ERR" if node.nil?

  base = indent(level) + node.to_s
  elements = node.elements
  if !node.elements.empty?
    estr = elements.map { |e| string_tree(e, level + 1) }.join("\n")
    return base + "\n" + estr
  end
  base
end

while true
  print "Enter text to parse: "
  x = gets
  break unless x
  x.strip!
  tree = parser.parse(x)
  if tree.nil?
    STDERR.puts("Parser error (#{parser.failure_index} :: #{parser.failure_reason}) at:\n#{x}\n" +
                sprintf("%*s", parser.failure_index, "") + "^")
  else
    query_node = SQLBuilder::QueryNode.resolve_node(tree)
    puts "Parsed text: '#{x}' to:\n#{string_tree(query_node)}"
    #puts "Tree: #{tree.inspect}"
  end
end

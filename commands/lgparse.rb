require 'rubygems'
require 'treetop'
require 'lg_node'
require 'lg'

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

  em = node.extension_modules
  elements = node.elements
  if em and not em.empty?
    base = indent(level) + "#{node_name(node)} \"#{node.text_value.strip}\""
    if elements and not elements.empty?
      estr = elements.map { |e| string_tree(e, level + 1) }.find_all { |x| not_empty?(x) }.join("\n")
      if not estr.empty?
        return base + "\n" + estr
      end
    end
    return base
  end
  if not elements or elements.empty?
    nil
  else
    text = elements.map { |e| string_tree(e, level) }.find_all { |x| not_empty?(x) }.join("\n")
    text
  end
end

while true
  print "Enter text to parse: "
  x = gets
  break unless x
  x.strip!
  tree = parser.parse(x)
  if tree.nil?
    STDERR.puts("Parser error at:\n#{x}\n" +
                sprintf("%*s", parser.index - 1, "") + "^")
  else
    puts "Parsed text: '#{x}' to:\n#{string_tree(tree)})"
  end
end

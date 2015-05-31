require 'parslet'
require 'grammar/atom'

module Grammar
  class CommandLine < Parslet::Parser
    root(:command_line)

    rule(:command_line) {
      (space? >> (arg >> space?).repeat).as(:command_line)
    }

    rule(:arg) {
      Atom.new.quoted_string | bareword
    }

    rule(:bareword) {
      (match('\S').repeat(1)).as(:bareword)
    }

    rule(:space) { match('\s').repeat(1) }
    rule(:space?) { space.maybe }
  end

  class CommandLineBuilder < Parslet::Transform
    def self.build(argstr)
      self.new.apply(CommandLine.new.parse(argstr))
    end

    rule(command_line: sequence(:args)) {
      args
    }

    rule(bareword: simple(:word)) {
      word.to_s
    }

    rule(string: sequence(:chars)) {
      chars.join('')
    }

    rule(char: simple(:x)) {
      x.to_s
    }
  end
end

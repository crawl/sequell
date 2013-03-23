require 'query/grammar'

module Query
  class CompactParens
    def self.apply(args)
      open = Regexp.quote(Query::Grammar::OPEN_PAREN)
      close = Regexp.quote(Query::Grammar::CLOSE_PAREN)
      argstr = args.join(' ')
      while argstr =~ /#{open}\s*#{close}/
        argstr = argstr.gsub(/#{open}\s*#{close}/, '')
      end
      argstr.split(' ')
    end
  end
end

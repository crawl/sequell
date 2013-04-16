require 'tpl/template'

module Query
  class TextTemplate
    def self.expand(template, expansion_provider)
      self.new(template).expand(expansion_provider)
    end

    def initialize(template)
      @template = Tpl::Template.template(template)
    end

    def expand(provider=nil, &block)
      provider ||= block
      Tpl::Template.eval_string(@template, provider).gsub(/ +/, ' ').
        gsub(/([\[(])[;,]/, '\1').gsub(/[;,]([\])])/, '\1').
        gsub(/\(\s*\)|\[\s*\]/, '').strip
    end
  end
end

module Graph
  class Template
    TEMPLATE = 'tpl/graph.html.haml'

    def initialize
      require 'json'
      require 'haml'
      @engine = Haml::Engine.new(::File.read(TEMPLATE))
    end

    def render(locals={})
      @engine.render(Object.new, locals)
    end
  end
end

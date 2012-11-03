require 'formatter/json_summary'
require 'time'

module Formatter
  class GraphSummary
    GRAPH_TEMPLATE = 'tpl/graph.html.haml'
    KNOWN_CHART_TYPES = Set.new(%w/Column Area Pie Scatter/)

    attr_reader :file, :title, :query_group, :query

    def initialize(query_group, title, options)
      @query_group = query_group
      @title = title
      @options = options.is_a?(String) ? options.split(':') : []
      @type = chart_type(@options[0])

      check_sanity!
    end

    def scatter?
      @type == 'Scatter'
    end

    def pie?
      @type == 'Pie'
    end

    def query
      @query_group.primary_query
    end

    def qualified_title
      title
    end

    def chart_type(type)
      return nil unless type
      type = type.strip.downcase.capitalize
      unless KNOWN_CHART_TYPES.include?(type)
        raise "Unknown chart type: #{type}"
      end
      type
    end

    def graph_type(json)
      return @type if @type
      'Column'
    end

    def graph_datatype(field)
      return 'string' if self.pie?
      case
      when field.numeric?
        'number'
      when field.date?
        'date'
      else
        'string'
      end
    end

    def summary_key_field
      query.summarise.fields[0]
    end

    def data_types
      [graph_datatype(summary_key_field), 'number']
    end

    def date?
      !pie? && summary_key_field.date?
    end

    def number?
      !pie? && summary_key_field.numeric?
    end

    def continuous?
      date? || number?
    end

    def format(summary)
      @json_reporter = JsonSummary.new(summary)
      json = @json_reporter.format
      graph_json = json.merge(:title => self.qualified_title,
                              :chart_type => self.graph_type(json),
                              :types => self.data_types,
                              :date => self.date?,
                              :number => self.number?)

      with_graph_file { |f|
        f.write(self.graph_template.render(:data => graph_json))
      }

      require 'graph/url'
      @json_reporter.prefix + Graph::Url.file_url(@file.filename)
    end

    def graph_template
      require 'graph/template'
      Graph::Template.new
    end

  private
    def check_sanity!
      if !query.summarise?
        raise "-graph requires an s=<field> term"
      end

      summarise = query.summarise
      if !summarise || summarise.fields.size > 1
        raise "-graph requires single field s=<field> term"
      end

      if scatter? && !continuous?
        raise Graph::Error.new("Scatter plot requires date or numeric grouping")
      end
    end

    def with_graph_file
      require 'graph/file'
      @file = Graph::File.new(@title)
      @file.with { |f|
        yield f
      }
      @file
    end
  end
end

require 'formatter/json_summary'
require 'time'
require 'graph/errors'

module Formatter
  class GraphSummary
    GRAPH_TEMPLATE = 'tpl/graph.html.haml'
    KNOWN_CHART_TYPES = Set.new(%w/Column Area Pie Scatter/)

    attr_reader :file, :title, :query_group, :query

    def initialize(query_group, title, options)
      @query_group = query_group
      @title = title
      @options = options.option_arguments
      @type = chart_type(@options[0])

      check_sanity!
    end

    def scatter?
      @type == 'Scatter'
    end

    def area?
      @type == 'Area'
    end

    def pie?
      @type == 'Pie'
    end

    def column?
      !@type || @type == 'Column'
    end

    def discrete_axis?
      pie? || column?
    end

    def continuous_axis?
      scatter? || area?
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

    def graph_type
      return @type if @type
      'Column'
    end

    def string_only?
      pie?
    end

    def stacked_group?
      query.group_count == 2
    end

    def graph_datatype(field)
      return 'string' if self.string_only?
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
      query.summarise.first
    end

    def data_types(json)
      field_count = json[:fields].size
      [graph_datatype(summary_key_field)] + ['number'] * (field_count - 1)
    end

    def date?
      !string_only? && summary_key_field.date?
    end

    def number?
      !string_only? && summary_key_field.numeric?
    end

    def continuous?
      date? || number?
    end

    def graph_number_format
      return '#,###.##%' if @json_reporter.perc?
      '#,###'
    end

    def sort_data(data)
      sorter = lambda { |a, b| a[0] <=> b[0] }
      sorter = lambda { |a, b| a[0].to_i <=> b[0].to_i } if number?
      data.sort(&sorter)
    end

    def format(summary)
      @json_reporter = JsonSummary.new(summary)
      json = @json_reporter.format

      if continuous?
        json[:data] = sort_data(json[:data])
      end

      graph_json = json.merge(:title => self.qualified_title,
                              :chart_type => self.graph_type,
                              :number_format => self.graph_number_format,
                              :types => self.data_types(json),
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
      if !summarise || summarise.arity > 2
        raise "-graph requires one or two group s=<field> terms"
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

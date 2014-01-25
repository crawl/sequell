module Formatter
  class Summary
    def self.format(summary)
      self.new(summary).format
    end

    def initialize(summary)
      @summary = summary
    end

    def query
      @summary.query
    end

    def default_result_prefix_title
      @default_prefix_title ||= find_default_prefix_title
    end

    def default_join
      query.ast.default_join
    end

    def prefix
      "#{summary_count} #{summary_entities} for #{@summary.query.argstr}: "
    end

    def format
      "#{prefix}#{summary_details}"
    end

    def counts
      @summary.counts
    end

    def count
      @summary.counts[0]
    end

    def summary_count
      if self.counts.size == 1
        self.count == 1 ? "One" : "#{pretty_num(self.count)}"
      else
        self.counts.reverse.map { |x| pretty_num(x) }.join("/")
      end
    end

    def summary_entities
      type = query.ctx.entity_name
      self.count == 1 ? type : type + 's'
    end

    def summary_details
      raise "Unimplemented"
    end

    def template_properties
      ast_props = query.ast.template_properties
      lambda { |key|
        ast_props[key] ||
        case key
        when 'n'
          self.count
        else
          nil
        end
      }
    end

  private
    def find_default_prefix_title
      template = query.ast.result_prefix_title
      return nil unless template
      Tpl::Template.string(
        Tpl::Template.template_eval(template, self.template_properties))
    end
  end
end

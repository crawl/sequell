module Formatter
  class Text
    def self.format(result)
      self.new(result).format
    end

    attr_reader :result

    def initialize(result)
      @result = result
    end

    def query
      result.query
    end

    ##
    # count? returns true if the query requires a specific number of rows.
    def count?
      query.count?
    end

    def format
      return query.stub_message if result.empty?

      if count?
        group_string
      else
        result.first.format_string
      end
    end

  private

    def group_string
      title_prefixed(result.map(&:format_game).join(query.ast.default_join))
    end

    def title_prefixed(text)
      title_text = title()
      return text if !title_text || title_text.empty?
      return "#{title_text}: #{text}"
    end

    def title
      title_tpl = query.ast.result_prefix_title
      return stock_title unless title_tpl
      Tpl::Template.string(
        Tpl::Template.template_eval(title_tpl,
          template_properties.merge(query.ast.template_properties)))
    end

    def stock_title
      "#{result.size}/#{result.total} #{entities} for #{query.argstr}"
    end

    def entities
      query.ctx.entity_name + (result.total == 1 ? "" : "s")
    end

    def template_properties
      base = {
        "n" => result.total,
      }
      unless result.empty?
        base.merge!("first" => result.first.n,
                    "last" => result.last.n)
      end
      base
    end
  end
end

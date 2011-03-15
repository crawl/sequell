module QueryConfig
  require 'commands/henzell_config'
  include HenzellConfig

  class Operators
    OPERATORS = {
      '==' => ['=', '!=='],
      '!==' => ['!=', '=='],
      '=' => ['=', '!='],
      '!=' => ['!=', '='],
      '<' => ['<', '>='],
      '>' => ['>', '<='],
      '<=' => ['<=', '>'],
      '>=' => ['>=', '<'],
      '=~' => ['LIKE', '!~'],
      '!~' => ['NOT LIKE', '=~'],
      '~~' => ['REGEXP', '!~~'],
      '!~~' => ['NOT REGEXP', '~~'],
      'AND' => ['AND', 'OR'],
      'OR' => ['OR', 'AND']
    }

    def self.op_def(query_operator)
      opdef = Operators::OPERATORS[query_operator]
      raise Exception.new("Unknown operator: `#{query_operator}`") unless opdef
      opdef
    end

    def self.equal_op?(operator)
      operator == '=' || operator == '!='
    end

    def self.group_op(operator)
      case operator
      when '='
        'OR'
      when '!='
        'AND'
      else
        raise Exception.new("No natural grouping for operator `#{operator}`")
      end
    end

    def self.sql_operator(query_operator)
      op_def(query_operator)[0]
    end

    def self.negate(query_operator)
      op_def(query_operator)[1]
    end

    def self.negate_cascades?(query_operator)
      ['AND', 'OR'].include?(query_operator)
    end
  end

  require 'commands/query_context_fixups'

  LOG2SQL = CFG['sql-field-names']
  R_FIELD_TYPE = %r{([ID])}

  FIELD_ALIASES = CFG['column-aliases']

  class LGQueryField
    attr_reader :name, :type

    def initialize(decorated_field)
      # Summarisable fields are *not* asterisked
      @summarisable = !decorated_field.index('*')
      @type = nil

      if decorated_field =~ QueryConfig::R_FIELD_TYPE
        @type = $1
      end
      @name = decorated_field.gsub(/[*ID]+$/, '')
    end

    def summarisable?
      @summarisable
    end

    def value(sql_query_result_value)
      case @type
      when 'I'
        sql_query_result_value.to_i
      when 'D'
        sql_date_to_logfile_date(sql_query_result_value)
      else
        sql_query_result_value
      end
    end

    def sql_date_to_logfile_date(v)
      if v.is_a?(DateTime)
        v = v.strftime('%Y-%m-%d %H:%M:%S')
      else
        v = v.to_s
      end
      if v =~ /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/
        # Note we're munging back to POSIX month (0-11) here.
        $1 + sprintf("%02d", $2.to_i - 1) + $3 + $4 + $5 + $6 + 'S'
      else
        v
      end
    end

    def to_s
      name
    end

    def inspect
      summary_qualifier = summarisable? ? '' : '*'
      "#{name}#{type}#{summary_qualifier}"
    end
  end

  ##
  # An LGQueryContext defines the field names and keywords that a
  # listgame-type query recognises. A context is an abstraction for the
  # underlying SQL table.
  #
  # Special-case query logic will inevitably be needed for each context.
  # Such logic may be placed in query_fixups.rb.
  #
  # A query context provides these services:
  # - Given a field name, returns an LGQueryField object, or nil if the field
  #   is not recognised.
  # - Given a keyword argument, translate it into a <field> <operator> <value>
  #   triple, or raise an appropriate error for an unknown keyword.
  #
  # A query context may have an autojoin_context, thus creating an
  # implicit join. i.e. querying !lg-specific fields on an !lm context
  # assumes that the query will be a join of the milestone and
  # logrecord tables.
  #
  # The LGQueryContext class assumes it is used directly with a
  # physical SQL table, but it may be subclassed to support subqueries.
  #
  class LGQueryContext
    @@current_context = nil

    attr_reader :ctx
    def initialize(context, props)
      @ctx = context
      @table = props['table']
      @autojoin_context_name = props['autojoin-context']
      @autojoin_context

      @fields =
           QueryConfig.table_typed_fields("#{@table}-fields-with-type") +
           QueryConfig::FAKE_TYPED_FIELDS
      @field_name_map = Hash[@fields.map { |f| [f.name, f] }]
      @fixups = QueryContextFixups.context_fixups(@ctx)
    end

    def name
      @ctx
    end

    def table(game_type=nil)
      table_name = @table
      if game_type
        prefix = HenzellConfig::GAME_PREFIXES[game_type]
        unless prefix
          raise Exception.new("Unknown game type `#{game_type}`")
        end
        return prefix + table_name
      end
      table_name
    end

    def field(field_name)
      if field_name.is_a?(LGQueryField)
        field_name
      else
        @field_name_map[canonical_field_name(field_name)]
      end
    end

    def canonical_field_name(field_name)
      QueryConfig::FIELD_ALIASES[field_name] || field_name
    end

    def sql_field_name(field_name)
      QueryConfig::LOG2SQL[field_name] || field_name
    end

    def autojoin_context
      @autojoin_context ||= QueryConfig::QUERY_CONTEXTS[@autojoin_context_name]
    end

    def field_has_transform?(field_name)
      field_transform(field_name, nil, nil)
    end

    def field_transform(field_name, operator, field_value)
      @fixups.field_transform(field_name, operator, field_value)
    end

    def keyword_transform(keyword)
      @fixups.keyword_transform(keyword)
    end

    def with
      old_context = @@current_context
      @@current_context = self
      begin
        yield
      ensure
        @@current_context = old_context
      end
    end

    def self.current
      @@current_context
    end
  end

  QUERY_CONTEXT_RAW_MAP = CFG['query-contexts']
  QUERY_CONTEXT_NAMES = QUERY_CONTEXT_RAW_MAP.keys

  def self.table_typed_fields(key)
    decorated_fields = HenzellConfig::CFG[key] || []
    decorated_fields.map { |field| LGQueryField.new(field) }
  end

  FAKE_TYPED_FIELDS = self.table_typed_fields("fake-fields-with-type")

  def self.query_context_pairs
    QUERY_CONTEXT_RAW_MAP.map do |context, props|
      [context, LGQueryContext.new(context, props)]
    end
  end

  ##
  # Mapping of query context names ('lg', 'lm') to LGQueryContext objects.
  QUERY_CONTEXTS = Hash[query_context_pairs]

  def self.context_by_name(context_name)
    QueryConfig::QUERY_CONTEXTS[context_name]
  end
end

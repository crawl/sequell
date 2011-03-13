module QueryConfig
  require 'commands/henzell_config'
  include HenzellConfig

  LOG2SQL = CFG['sql-field-names']
  R_FIELD_TYPE = %r{([ID])$}

  class LGQueryField
    attr_reader :name, :type

    def initialize(decorated_field)
      # Summarisable fields are *not* asterisked
      @summarisable = !decorated_field.index('*')
      @type = nil


      @name = if decorated_field =~ HenzellConfig::R_FIELD_TYPE
                @type = $1
                decorated_field.gsub(/[*ID]+$/, '')
              else
                decorated_field
              end
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
    attr_reader :table, :ctx
    def initialize(context, props)
      @ctx = context
      @table = props['table']
      @autojoin_context_name = props['autojoin-context']
      @autojoin_context

      @fields =
           HenzellConfig.table_typed_fields("#{@table}-fields-with-type") +
           HenzellConfig::FAKE_TYPED_FIELDS
      @field_name_map = Hash[@fields.map { |f| [f.name, f] }]
    end

    def field(field_name)
      @field_name_map[field_name]
    end

    def autojoin_context
      @autojoin_context ||= QueryConfig::QUERY_CONTEXTS[@autojoin_context_name]
    end
  end

  QUERY_CONTEXT_RAW_MAP = CFG['query-contexts']
  QUERY_CONTEXT_NAMES = QUERY_CONTEXT_RAW_MAP.keys

  def self.table_typed_fields(key)
    decorated_fields = HenzellConfig::CFG[key] || []
    decorated_fields.map { |field| LGQueryField.new(field) }
  end

  FAKE_TYPED_FIELDS = self.table_typed_fields("fake-typed-fields")

  ##
  # Mapping of query context names ('lg', 'lm') to LGQueryContext objects.
  QUERY_CONTEXTS = Hash[ QUERY_CONTEXT_RAW_MAP.each { |context, props|
                           [context, LGQueryContext.new(context, props)]
                         }]

  def self.context_by_name(context_name)
    QueryConfig::QUERY_CONTEXTS[context_name]
  end
end

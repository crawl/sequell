module HenzellConfig
  require 'yaml'
  require 'set'

  CONFIG_FILE = 'commands/crawl-data.yml'
  CFG = YAML.load_file(CONFIG_FILE)

  GAME_PREFIXES = CFG['game-type-prefixes']
  GAME_TYPE_DEFAULT = CFG['default-game-type']

  MAX_MEMORY_USED = CFG['memory-use-limit-megabytes'] * 1024 * 1024

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

  class LGQueryContext
    def initialize(context, props)
      @ctx = context
      @table = props['table']
      @autojoin_context_name = props['autojoin-context']

      @fields =
           HenzellConfig.table_typed_fields("#{@table}-fields-with-type") +
           HenzellConfig::FAKE_TYPED_FIELDS
      @field_name_map = Hash[@fields.map { |f| [f.name, f] }]
    end

    def field(field_name)
      @field_name_map[field_name]
    end

    def join_field(field_name)
      if @autojoin_context_name
        autojoin_context.field(field_name)
      end
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
end

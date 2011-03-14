class QueryContextFixups
  MILESTONE_TYPES = HenzellConfig::CFG['milestone-types']

  BRANCHES = QueryConfig::CFG['branches'].map { |b| b.sub(':', '') }
  BRANCHES_WITH_DEPTHS = \
      (QueryConfig::CFG['branches'].find_all { |b| b =~ /:/ }.
                                    map { |b| b.sub(':', '').downcase })

  BRANCH_KEYWORD_REGEXP = %r/^(?:#{BRANCHES.join('|')})$/i
  BRANCH_DEPTH_REGEXP = %r/^(?:#{BRANCHES_WITH_DEPTHS.join('|')}):\d+$/i

  SPECIES_EXACT_MAP = HenzellConfig::CFG['species']
  CLASS_EXACT_MAP = HenzellConfig::CFG['classes']
  SPECIES_MAP = Hash[SPECIES_EXACT_MAP.map { |key, value|
                       [key.downcase, value]
                     }]
  CLASS_MAP = Hash[CLASS_EXACT_MAP.map { |key, value|
                     [key.downcase, value]
                   }]

  PREFIX_FIXUPS = HenzellConfig::CFG['prefix-field-fixups']

  def self.keyword_field_match_map(map, action_name, field_name, exact=false)
    keyword_match(action_name) do |keyword|
      match_word = exact ? keyword : keyword.downcase
      value = map[match_word]
      if value
        SQLExprs.field_op_val(field_name, '=', value)
      end
    end
  end

  context :any do
    # Match simple branches or branches with depths as keywords
    keyword_match("place") do |keyword|
      if keyword =~ BRANCH_KEYWORD_REGEXP || keyword =~ BRANCH_DEPTH_REGEXP
        SQLExprs.field_op_val('place', '=', keyword)
      end
    end

    keyword_match("version") do |keyword|
      if keyword =~ /^[0-9]+[.0-9]+$/
        if keyword =~ /^[0-9]+[.][0-9]+$/
          SQLExprs.field_op_val('cv', '=', keyword)
        else
          SQLExprs.field_op_val('v', '=', keyword)
        end
      end
    end

    keyword_field_match_map(SPECIES_EXACT_MAP, 'species:exact', 'crace', :exact)
    keyword_field_match_map(CLASS_EXACT_MAP, 'class:exact', 'cls', :exact)

    skip_if_predecessor('species:exact', 'class:exact') do
      keyword_field_match_map(SPECIES_MAP, 'species', 'crace')
      keyword_field_match_map(CLASS_MAP, 'class', 'cls')
    end

    field_name_equal_match(['place', 'oplace']) do |field, op, value|
      if value =~ BRANCH_KEYWORD_REGEXP &&
          BRANCHES_WITH_DEPTHS.include?(value.downcase)
        new_op = op == '=' ? '=~' : '!~'
        SQLExprs.field_op_val(field, new_op, "#{value}:*")
      end
    end

    keyword_match('char') do |keyword|
      if keyword.length == 4 &&
          SPECIES_MAP[keyword[0..1].downcase] &&
          CLASS_MAP[keyword[2..3].downcase]
        SQLExprs.field_op_val('char', '=', keyword)
      end
    end

    PREFIX_FIXUPS.find do |field, prefix_map|
      keyword_match("prefix-#{field}") do |keyword|
        value = prefix_map.keys.find { |key| keyword.downcase =~ /^#{key}/ }
        if value
          SQLExprs.field_op_val(field, '=', prefix_map[value])
        end
      end

      field_name_equal_match(field) do |field, op, field_value|
        value = prefix_map.keys.find { |key| field_value.downcase =~ /^#{key}/ }
        value = value && prefix_map[value]
        # Don't spin in an endless loop with the same value
        if value && value != field_value
          SQLExprs.field_op_val(field, op, value)
        end
      end
    end

    field_name_equal_match('cls') do |field, operator, value|
      if CLASS_MAP[value.downcase]
        SQLExprs.field_op_val(field, operator, CLASS_MAP[value.downcase])
      end
    end

    field_name_equal_match(['crace', 'race']) do |field, operator, value|
      if SPECIES_MAP[value.downcase]
        SQLExprs.field_op_val(field, operator, SPECIES_MAP[value.downcase])
      end
    end

    field_name_equal_match('race') do |field, op, value|
      if value.downcase == 'draconian'
        SQLExprs.field_op_val(field, op == '=' ? '=~' : '!~',
                              '*' + value)
      end
    end

    field_name_op_match('cls', '~~') do |field, op, value|
      pieces = value.split('|')
      if pieces.size > 1 &&
          (pieces.find_all { |p| p.length == 2 && p =~ /^[a-z]+$/i }.size ==
           pieces.size)
        equal_op = op == '~~' ? '=' : '!='
        group_op = QueryConfig::Operators.group_op(equal_op)
        piece_checks = pieces.map { |piece|
          piece_class = CLASS_MAP[piece.downcase]
          unless piece_class
            raise QueryError.new("Unknown class `#{piece}` in `#{value}`")
          end
          SQLExprs.field_op_val(field, equal_op, piece_class)
        }
        SQLExprs.group(group_op, *piece_checks)
      end
    end
  end

  context 'lg' do
    field_equal_match("killer") do |field_name, operator, field_value|
      if (['killer', 'ckiller', 'ikiller'].include?(field_name.downcase) &&
          field_value !~ /^an? /i && field_value !~ /^[A-Z]/)
        group_op = QueryConfig::Operators.group_op(operator)
        SQLExprs.group(group_op,
                       SQLExprs.field_op_val(field_name, operator,
                                             field_value, :no_further_xform),
                       SQLExprs.field_op_val(field_name, operator,
                                             'a ' + field_value),
                       SQLExprs.field_op_val(field_name, operator,
                                             'an ' + field_value))
      end
    end
  end

  context 'lm' do
    # Given a query such as `!lm * abyss.enter`, translate the keyword
    # `abyss.enter` into `type=abyss.enter`
    keyword_match("milestone-type") do |keyword|
      if MILESTONE_TYPES.include?(keyword.downcase)
        SQLExprs.field_op_val('type', '=', keyword)
      end
    end
  end
end

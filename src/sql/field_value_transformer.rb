module Sql
  class FieldValueTransformer
    def initialize(transforms)
      @transforms = transforms
    end

    def transform(value, field)
      tmap = @transforms[field.name.downcase]
      return value unless tmap

      matches = []
      for key, mapped_value in tmap
        return mapped_value if value.downcase == key.downcase
        matches << mapped_value if value.downcase.index(key.downcase) == 0
      end
      matches.size == 1 ? matches[0] : value
    end
  end
end

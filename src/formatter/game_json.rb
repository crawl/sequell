require 'json'

module Formatter
  class GameJSON
    def self.format(result, opts)
      ::JSON.generate({
        record: result.as_json
      }.merge(base(result)).merge(opts))
    end

    def self.format_milestone_game(mile, game, opts)
      ::JSON.generate({
        record: mile.as_json,
        game: game && game.as_json
      }.merge(base(mile)).merge(!game ? {msg: "No matching game for milestone"}: opts))
    end

    def self.base(q)
      {
        resultTime: DateTime.now.rfc3339,
        entity: q.ctx.entity_name
      }
    end
  end
end

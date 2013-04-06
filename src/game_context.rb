require 'henzell_config'

class GameContext
  include HenzellConfig

  @@game = HenzellConfig::GAME_TYPE_DEFAULT

  def self.with_game(game)
    begin
      old_game = @@game
      @@game = game
      yield
    ensure
      @@game = old_game
    end
  end

  def self.game=(game)
    @@game = game
  end

  def self.game
    @@game
  end
end

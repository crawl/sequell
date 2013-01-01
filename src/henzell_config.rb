module HenzellConfig
  require 'yaml'
  require 'set'
  require 'crawl/config'

  CFG = Crawl::Config.config

  GAME_PREFIXES = CFG['game-type-prefixes']
  GAME_TYPE_DEFAULT = CFG['default-game-type']

  MAX_MEMORY_USED = CFG['memory-use-limit-megabytes'] * 1024 * 1024
end

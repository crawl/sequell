module HenzellConfig
  require 'yaml'
  require 'set'

  CONFIG_FILE = 'commands/crawl-data.yml'
  SERVER_CONFIG_FILE = 'servers.yml'

  CFG = YAML.load_file(CONFIG_FILE)
  SERVER_CFG = YAML.load_file(SERVER_CONFIG_FILE)

  GAME_PREFIXES = CFG['game-type-prefixes']
  GAME_TYPE_DEFAULT = CFG['default-game-type']

  MAX_MEMORY_USED = CFG['memory-use-limit-megabytes'] * 1024 * 1024
end

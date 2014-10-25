require 'yaml'
require 'henzell/config'

class AuthError < StandardError; end

class IrcAuth
  AUTH_FILE = 'config/auth.yml'

  def self.authorizations
    @authorizations ||= YAML.load_file(
      Henzell::Config.file_path(AUTH_FILE))
  end

  def self.acting_nick
    ENV['HENZELL_ENV_NICK'] || ARGV[1]
  end

  def self.env_channel
    ENV['HENZELL_ENV_CHANNEL'] || 'msg'
  end

  def self.nick_authenticated?
    ENV['IRC_NICK_AUTHENTICATED'] == 'y'
  end

  def self.authorized_users(auth_context)
    self.authorizations[auth_context.to_s]
  end

  def self.display_auths(auths)
    auths.sort { |a, b| a.downcase <=> b.downcase }.join(', ')
  end

  def self.authorized_command_help(auth_context, help_msg, force_help=false)
    auths = self.authorizations[auth_context.to_s]
    help(help_msg + " Authorized users: #{display_auths(auths)}", force_help)
  end

  def self.assert_authorized!(permission)
    assert_not_proxied!
    nick = self.acting_nick
    chan = self.env_channel
    result = nil
    IO.popen("perl scripts/acl-perm.pl -", "r+") { |io|
      begin
        io.puts("#{permission} #{nick} #{chan}")
        result = io.readline.strip
      rescue EOFError
      end
    }
    if $?.exitstatus != 0
      if result =~ /DENY:(.*)/
        raise AuthError.new("Permission #{permission} denied: #$1")
      else
        raise AuthError.new("Permission #{permission} denied.")
      end
    end

    if result == 'authenticated' && !self.nick_authenticated?
      raise AuthError.new("[[[AUTHENTICATE: #{self.acting_nick}]]]")
    end
  rescue ProxyError
    raise AuthError.new("Permission #{permission} denied: proxying not allowed")
  end

  def self.authorize!(permission)
    assert_authorized!(permission)
  rescue AuthError => e
    raise e if ENV['RAISE_AUTH_ERRORS'] == 'y'
    puts e.message
    exit 1
  end
end

require 'yaml'

class IrcAuth
  def self.authorizations
    @authorizations ||= YAML.load_file('commands/auth.yml')
  end

  def self.acting_nick
    ARGV[1]
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

  def self.authorize!(auth_context)
    auths = self.authorizations[auth_context.to_s]
    unless auths.include?(self.acting_nick)
      puts "Ignoring #{auth_context} request from #{acting_nick}: not authorized. Authorized users: #{display_auths(auths)}."
      exit 1
    end

    unless self.nick_authenticated?
      puts "[[[AUTHENTICATE: #{self.acting_nick}]]]"
      exit 1
    end
  end
end

class Env
  def self.with(vars={})
    preserved_values = { }
    for key, value in vars
      preserved_values[key] = ENV[key.to_s.upcase]
      ENV[key.to_s.upcase] = value
    end
    begin
      yield
    ensure
      for key, value in vars
        ENV[key.to_s.upcase] = preserved_values[key]
      end
    end
  end
end

require 'json'

class JsonSerializer
  def write(object)
    JSON.dump(object)
  end

  def read(text)
    JSON.parse(text)
  end
end

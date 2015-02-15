class Response
  attr_reader :result
  attr_accessor :status

  def initialize(result, status=:ok)
    @result = result
    @status = status
  end
end

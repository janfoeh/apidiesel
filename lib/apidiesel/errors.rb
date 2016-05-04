module Apidiesel
  class Error < StandardError; end
  class InputError < Error; end

  class RequestError < Error
    attr_accessor :request

    def initialize(msg = nil, request = nil)
      @request = request
      super(msg)
    end
  end

  class ResponseError < RequestError; end
end
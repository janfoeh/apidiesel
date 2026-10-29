# frozen_string_literal: true

module Apidiesel
  class Error < StandardError; end
  class InputError < Error; end

  class RequestError < Error
    attr_accessor :exchange

    def initialize(msg = nil, exchange = nil)
      @exchange = exchange
      super(msg)
    end
  end

  class ResponseError < RequestError; end

  # Raised by response handlers when a response body can't be parsed in the
  # format the endpoint expects, e.g. an HTML error page where JSON was due.
  # The underlying parser error is available as +#cause+.
  class UnparseableResponseError < ResponseError; end

  # Raised by +Exchange#raise_when_unsuccessful+ for 4xx responses
  class ClientError < ResponseError; end

  # Raised by +Exchange#raise_when_unsuccessful+ specifically for 429 responses
  class RateLimitedError < ClientError; end

  # Raised by +Exchange#raise_when_unsuccessful+ for 5xx responses
  class ServerError < ResponseError; end

  class MalformedResponseError < Error
    attr_reader :content

    def initialize(msg = nil, content = nil)
      @content = content
      super(msg)
    end
  end
end

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

  class MalformedResponseError < Error
    attr_reader :content

    def initialize(msg = nil, content = nil)
      @content = content
      super(msg)
    end
  end
end

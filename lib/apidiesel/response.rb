# frozen_string_literal: true

module Apidiesel
  class Response
    extend Forwardable

    attr_accessor :original
    attr_accessor :exception
    attr_accessor :parsed_body

    def_delegators :original, :body, :headers, :error?, :code

    def initialize(original)
      @original = original
    end

    def successful?
      !error?
    end

    def process
      begin
        @parsed_body = yield(body)
      rescue StandardError => ex
        self.exception = ex
      end
    end
  end
end

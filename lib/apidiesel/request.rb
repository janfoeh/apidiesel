# frozen_string_literal: true

require "forwardable"

module Apidiesel
  class Request
    extend Forwardable

    attr_accessor :original
    attr_accessor :exception

    def_delegators :original, :query, :body, :headers

    def initialize(original)
      @original = original
    end

    def successful?
      exception.blank?
    end
  end
end

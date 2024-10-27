# frozen_string_literal: true

require "forwardable"

module Apidiesel
  class Request
    extend Forwardable

    attr_accessor :original
    attr_accessor :exception

    def_delegators :original, :params, :body, :headers

    def initialize(original)
      @original = original
    end

    def successful?
      exception.blank?
    end

    def query
      params
    end
  end
end

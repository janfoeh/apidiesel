# frozen_string_literal: true

module Apidiesel
  module Handlers
    class Handler
      # This doesn't look like its very useful, but its
      # purpose is to allow the `use ..` method to
      # optionally pass along args and kargs to the handler.
      #
      # Unfortunately, this:
      #
      # ```ruby
      # def method(**kargs)
      #   other_method(**kargs)
      # end
      # ```
      #
      # still produces an `ArgumentError` if `other_method`
      # doesn't expect kargs. Fixed in Ruby 3, see
      # https://bugs.ruby-lang.org/issues/10293
      def initialize(*_args, **_kargs)
      end
    end
  end
end

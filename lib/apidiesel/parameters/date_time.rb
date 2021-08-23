# frozen_string_literal: true

module Apidiesel
  module Parameters
    class DateTime < Parameter
      attr_reader :format

      def after_initialize
        @format = kargs[:format]
      end

      def after_processing(value, parameters:, config:)
        format ? value.try(:strftime, args[:format]) : value
      end
    end
  end
end

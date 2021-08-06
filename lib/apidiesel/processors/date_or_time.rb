# frozen_string_literal: true

module Apidiesel
  module Processors
    class DateOrTime < Attribute
      def process(data, **_kargs)
        if options.has_key?(:on_error)
          options[:klass].strptime(data, options[:format]) rescue options[:on_error]
        else
          options[:klass].strptime(data, options[:format])
        end
      end
    end
  end
end

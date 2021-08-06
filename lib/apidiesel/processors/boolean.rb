# frozen_string_literal: true

module Apidiesel
  module Processors
    class Boolean < Attribute
      def process(data, **_kargs)
        if options[:truthy].include?(data)
          true
        elsif options[:falsy].include?(data)
          false
        else
          nil
        end
      end
    end
  end
end

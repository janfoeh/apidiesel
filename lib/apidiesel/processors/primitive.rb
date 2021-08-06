# frozen_string_literal: true

module Apidiesel
  module Processors
    class Primitive < Attribute
      def process(data, **_kargs)
        data.send(options[:cast])
      end
    end
  end
end

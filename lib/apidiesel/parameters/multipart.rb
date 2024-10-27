# frozen_string_literal: true

module Apidiesel
  module Parameters
    class Multipart < Parameter
      attr_reader :default_mime_type

      def after_initialize
        @default_mime_type = kargs[:mime_type] || "text/plain"
      end

      def after_processing(value, parameters:, config:)
        mime_type = parameters["#{input_name}_mime_type".to_sym] || mime_type

        Faraday::ParamPart.new(value, mime_type)
      end
    end
  end
end

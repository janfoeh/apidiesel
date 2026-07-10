# frozen_string_literal: true

module Apidiesel
  module Parameters
    class MultipartFile < Parameter
      attr_reader :default_mime_type

      def after_initialize
        @default_mime_type = kargs[:mime_type] || "text/plain"
      end

      def after_processing(value, parameters:, config:)
        mime_type = parameters["#{input_name}_mime_type".to_sym] || default_mime_type
        filename  = parameters["#{input_name}_filename".to_sym]

        raise ArgumentError, "provide the filename for :#{input_name} with :#{input_name}_filename" unless filename

        # Faraday's UploadIO checks respond_to?(:read) to distinguish IO from filename.
        # Objects like Pathname satisfy that check but are not proper seekable IOs, so
        # UploadIO treats them as IO-like rather than opening them as files, breaking upload.
        # Convert anything that isn't a String or a seekable IO to a String path.
        value = value.to_s unless value.is_a?(::String) || value.respond_to?(:seek)

        Faraday::FilePart.new(value, mime_type, filename)
      end
    end
  end
end

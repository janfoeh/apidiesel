# frozen_string_literal: true

module Apidiesel
  module Handlers
    class MockResponse < Handler
      def handle_request(exchange)
        endpoint = exchange.endpoint

        return exchange unless endpoint.respond_to?(:mock_response) && endpoint.mock_response

        file_name = endpoint.mock_response[:file]
        parser    = endpoint.mock_response[:parser]
        file      = File.read(file_name)

        exchange.response_body = if parser
          parser.call(file)

        elsif file_name.ends_with?('.json')
          JSON.parse(file)

        elsif file_name.ends_with?('.xml')
          Hash.from_xml(file)

        else
          file
        end

        exchange
      end

      module EndpointExtension
        extend ActiveSupport::Concern

        class_methods do
          def mock_response!(file:, &block)
            @mock_response = {
              file: file,
              parser: block
            }
          end

          def mock_response
            @mock_response
          end
        end

        def mock_response
          self.class.mock_response
        end
      end
    end
  end
end

Apidiesel::Endpoint.send(:include, Apidiesel::Handlers::MockResponse::EndpointExtension)

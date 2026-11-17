# frozen_string_literal: true

module Apidiesel
  module Handlers
    # Records the exception matching a 4xx/5xx response (see {Exchange#status_error})
    # as the Response's exception, so that it shows up in {Exchange#exception}.
    #
    # Without this, an error status is not an exception: the exchange is
    # {Exchange#failed?}, but {Exchange#exception} is `nil`.
    #
    # Register it after the handler which parses the body, so that the
    # status wins over a parse error: an HTML error page where JSON was due is
    # the symptom, the status the cause.
    #
    # A missing response needs no such treatment: the request handlers always record
    # the exception which prevented it as the Request's, and that is in {Exchange#exception}
    # already. Only a custom request handler which neither sends nor fails could produce
    # a response-less exchange without one; {Exchange#raise_when_unsuccessful} still
    # raises a ResponseError for that.
    #
    # Whether the exception is also raised is still up to `raise_response_errors`.
    #
    # ```ruby
    # class MyApi < Apidiesel::Api
    #   use Apidiesel::Handlers::JSON
    #   use Apidiesel::Handlers::HttpStatusErrors
    # end
    # ```
    class HttpStatusErrors < Handler
      # @param exchange [Apidiesel::Exchange]
      # @return [void]
      def handle_response(exchange)
        error = exchange.status_error

        exchange.response.exception = error if error
      end
    end
  end
end

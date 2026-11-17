# frozen_string_literal: true

require "spec_helper"

describe Apidiesel::Handlers::HttpStatusErrors do
  subject(:handler) { described_class.new }

  let(:endpoint) { instance_double("Apidiesel::Endpoint") }

  let(:exchange) do
    Apidiesel::Exchange.new(endpoint: endpoint, endpoint_arguments: {}, parameters: {})
  end

  let(:status) { nil }
  let(:faraday_response) { instance_double("Faraday::Response", status: status, body: "") }

  before { exchange.response = faraday_response if status }

  describe "#handle_response" do
    {
      200 => nil,
      302 => nil,
      400 => Apidiesel::ClientError,
      404 => Apidiesel::ClientError,
      429 => Apidiesel::RateLimitedError,
      500 => Apidiesel::ServerError,
      503 => Apidiesel::ServerError
    }.each do |code, error_class|
      context "with a #{code} response" do
        let(:status) { code }

        before { handler.handle_response(exchange) }

        if error_class
          it "records a #{error_class.name}" do
            expect(exchange.exception).to be_a(error_class)
          end

          it "keeps the exchange on the exception" do
            expect(exchange.exception.exchange).to equal(exchange)
          end

          it "names the status" do
            expect(exchange.exception.message).to include(code.to_s)
          end

        else
          it "records no exception" do
            expect(exchange.exception).to be_nil
          end
        end
      end
    end

    context "when parsing the body already failed" do
      let(:status) { 502 }

      before do
        exchange.response.exception = Apidiesel::UnparseableResponseError.new("not JSON", exchange)

        handler.handle_response(exchange)
      end

      it "lets the status take precedence" do
        expect(exchange.exception).to be_a(Apidiesel::ServerError)
      end
    end

    context "when no response has been received" do
      it "does nothing" do
        expect { handler.handle_response(exchange) }.not_to raise_error
        expect(exchange.exception).to be_nil
      end
    end
  end

  describe "Exchange#raise_when_unsuccessful" do
    let(:status) { 503 }

    it "still raises the status error" do
      expect { exchange.raise_when_unsuccessful }.to raise_error(Apidiesel::ServerError, "HTTP 503")
    end
  end
end

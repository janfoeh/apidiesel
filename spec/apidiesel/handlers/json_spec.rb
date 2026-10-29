# frozen_string_literal: true

require "spec_helper"

describe Apidiesel::Handlers::JSON do
  subject(:handler) { described_class.new }

  let(:config)   { double("Apidiesel::Config", logger: Logger.new(nil)) }
  let(:endpoint) { instance_double("Apidiesel::Endpoint", config: config) }

  let(:exchange) do
    Apidiesel::Exchange.new(endpoint: endpoint, endpoint_arguments: {}, parameters: {})
  end

  let(:faraday_response) { instance_double("Faraday::Response", body: body) }

  before do
    allow(exchange).to receive(:parseable?).and_return(true)
    exchange.response = faraday_response

    handler.handle_response(exchange)
  end

  describe "#handle_response" do
    context "with a valid JSON body" do
      let(:body) { '{"id": 1}' }

      it "parses the body" do
        expect(exchange.response.parsed_body).to eq("id" => 1)
      end

      it "records no exception" do
        expect(exchange.response_exception).to be_nil
      end
    end

    context "with a body that is not JSON" do
      let(:body) { "<!DOCTYPE html><html></html>" }

      it "records an UnparseableResponseError" do
        expect(exchange.response_exception).to be_a(Apidiesel::UnparseableResponseError)
      end

      it "keeps the exchange on the exception" do
        expect(exchange.response_exception.exchange).to be(exchange)
      end

      it "keeps the parser error as the cause" do
        expect(exchange.response_exception.cause).to be_a(::JSON::ParserError)
      end

      it "is a ResponseError" do
        expect(exchange.response_exception).to be_a(Apidiesel::ResponseError)
      end
    end
  end
end

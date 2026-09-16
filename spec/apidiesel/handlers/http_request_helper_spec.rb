# frozen_string_literal: true

require "spec_helper"

describe Apidiesel::Handlers::HttpRequestHelper do
  let(:helper_class) do
    Class.new do
      include Apidiesel::Handlers::HttpRequestHelper

      public :format_params_for_query, :query_params_encoder
    end
  end

  subject(:helper) { helper_class.new }

  let(:config) { Apidiesel::Config.new({ array_parameter_format: array_parameter_format }) }
  let(:params)  { { select: %i(id amount), expand: "none" } }

  describe "#format_params_for_query" do
    subject { helper.format_params_for_query(params, config) }

    context "with :comma" do
      let(:array_parameter_format) { :comma }

      it { is_expected.to eq(select: "id,amount", expand: "none") }
    end

    context "with :brackets" do
      let(:array_parameter_format) { :brackets }

      it "leaves Array values untouched" do
        is_expected.to eq(params)
      end
    end

    context "with :repeat" do
      let(:array_parameter_format) { :repeat }

      it "leaves Array values untouched" do
        is_expected.to eq(params)
      end
    end
  end

  describe "#query_params_encoder" do
    subject { helper.query_params_encoder(config) }

    context "with :comma" do
      let(:array_parameter_format) { :comma }

      it { is_expected.to eq(Faraday::NestedParamsEncoder) }
    end

    context "with :brackets" do
      let(:array_parameter_format) { :brackets }

      it { is_expected.to eq(Faraday::NestedParamsEncoder) }
    end

    context "with :repeat" do
      let(:array_parameter_format) { :repeat }

      it { is_expected.to eq(Faraday::FlatParamsEncoder) }
    end
  end
end

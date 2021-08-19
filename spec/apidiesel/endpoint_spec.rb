# frozen_string_literal: true

require "spec_helper"

describe Apidiesel::Endpoint do
  describe ".config" do
    subject(:config) { described_class.config }

    it { is_expected.to be_a(Apidiesel::Config) }

    context "the default config" do
      subject { config.store.keys }

      it { is_expected.to be_many }
    end
  end

  let(:api_base)      { Mocks::Api.build }
  subject(:instance)  { described_class.new(api_base) }

  describe "#new" do
    subject(:instance) { described_class.new(api_base) }

    context "the instance configurations parent configuration" do
      subject { instance.config.parent.store.keys }

      it "is a clone of the class configuration" do
        is_expected.to match(described_class.config.store.keys)
      end
    end
  end
end

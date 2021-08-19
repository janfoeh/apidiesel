# frozen_string_literal: true

require "spec_helper"

describe Apidiesel::Api do
  describe ".config" do
    subject(:config) { described_class.config }

    it { is_expected.to be_a(Apidiesel::Config) }

    context "the default config" do
      subject { config.store.keys }

      it { is_expected.to be_many }
    end
  end

  describe "#new" do
    subject(:instance) { described_class.new }

    context "the instance configurations parent configuration" do
      subject { instance.config.parent.store.keys }

      it "is a clone of the class configuration" do
        is_expected.to match(described_class.config.store.keys)
      end
    end
  end

  let(:instance_kargs) { {} }

  subject(:instance) { described_class.new(**instance_kargs) }

  describe "#logger" do
    subject { instance.logger }

    it { is_expected.to be_a(Module) }
  end
end

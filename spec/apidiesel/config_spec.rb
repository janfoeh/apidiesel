# frozen_string_literal: true

require "spec_helper"

describe Apidiesel::Config do
  describe Apidiesel::Config::Setter do
    let(:instance) { Apidiesel::Config::Setter.new }

    subject { instance.store }

    context "when setting a nil value" do
      before do
        instance.key nil
      end

      its(:first) { is_expected.to be_a(Struct) }
      its("first.name") { is_expected.to eq(:key) }
      its("first.value") { is_expected.to be_nil }
    end

    context "when setting a string value" do
      let(:value) { "cucumber salad" }

      before do
        instance.key value
      end

      its(:first) { is_expected.to be_a(Struct) }
      its("first.name") { is_expected.to eq(:key) }
      its("first.value") { is_expected.to eq(value) }
    end

    context "when setting an empty hash through :value" do
      let(:value) { {} }

      before do
        instance.key value: value
      end

      its(:first) { is_expected.to be_a(Struct) }
      its("first.name") { is_expected.to eq(:key) }
      its("first.value") { is_expected.to eq(value) }
    end

    context "when giving a Proc to :value" do
      let(:value) { -> { "cucumber salad" } }

      before do
        allow(value).to receive(:call).and_call_original
        instance.key value: value
      end

      its(:first) { is_expected.to be_a(Struct) }
      its("first.name") { is_expected.to eq(:key) }
      its("first.value") { is_expected.to eq("cucumber salad") }
      it { expect(value).to have_received(:call).with(no_args) }
    end
  end

  describe "#new" do
    it "yields a Config::Setter" do
      result = nil

      block =
        ->(_) { result = self.is_a?(Apidiesel::Config::Setter) }

      described_class.new(&block)

      expect(result).to be_truthy
    end
  end

  let(:key)   { :key }
  let(:value) { :value }

  let(:child_values)        { {} }
  let(:parent_values)       { {} }
  let(:grandparent_values)  { {} }

  let(:grandparent) do
    described_class.new(grandparent_values, label: :grandparent) do
      unclonable_attribute Struct.new(:foo), unclonable: true
    end
  end
  let(:parent)      { described_class.new(parent_values, parent: grandparent, label: :parent) }
  let(:child)       { described_class.new(child_values, parent: parent, label: :child) }

  let(:instance) { child }

  describe "#configured?" do
    let(:only_self) { false }

    subject { instance.configured?(key, only_self: only_self) }

    context "when the value isn't configured" do
      it { is_expected.to be_falsy }
    end

    context "when the value is configured on child" do
      let(:child_values) { { key => value } }

      it { is_expected.to be_truthy }

      context "and the value is nil" do
        let(:value) { nil }

        it { is_expected.to be_truthy }
      end
    end

    context "when the value is configured on parent" do
      let(:parent_values) { { key => value } }

      it { is_expected.to be_truthy }

      context "with only_self: true" do
        let(:only_self) { true }

        it { is_expected.to be_falsy }
      end
    end

    context "when the value is configured on grandparent" do
      let(:grandparent_values) { { key => value } }

      it { is_expected.to be_truthy }

      context "with only_self: true" do
        let(:only_self) { true }

        it { is_expected.to be_falsy }
      end
    end
  end

  describe "#present?" do
    let(:only_self) { false }

    subject { instance.present?(key, only_self: only_self) }

    context "when the value isn't configured" do
      it { is_expected.to be_falsy }
    end

    context "when a value is configured on child" do
      let(:child_values) { { key => value } }

      context "and it is not #blank?" do
        it { is_expected.to be_truthy }
      end

      context "and it is nil" do
        let(:value) { nil }

        it { is_expected.to be_falsy }
      end
    end

    context "when the value is configured on parent" do
      let(:parent_values) { { key => value } }

      it { is_expected.to be_truthy }

      context "with only_self: true" do
        let(:only_self) { true }

        it { is_expected.to be_falsy }
      end
    end

    context "when the value is configured on grandparent" do
      let(:grandparent_values) { { key => value } }

      it { is_expected.to be_truthy }

      context "with only_self: true" do
        let(:only_self) { true }

        it { is_expected.to be_falsy }
      end
    end
  end

  describe "#parents" do
    context "on the child" do
      subject { instance.parents }

      it { is_expected.to match([parent, grandparent]) }
    end

    context "on the grandparent" do
      subject { grandparent.parents }

      it { is_expected.to be_empty }
    end
  end

  describe "#fetch" do
    let(:only_self) { false }

    subject { instance.fetch(key, only_self: only_self) }

    context "when the value isn't configured" do
      it { is_expected.to be_nil }
    end

    context "when a value is configured on child" do
      let(:child_values) { { key => value } }

      it { is_expected.to eq(value) }
    end

    context "when the value is configured on parent" do
      let(:parent_values) { { key => value } }

      it { is_expected.to eq(value) }

      context "with only_self: true" do
        let(:only_self) { true }

        it { is_expected.to be_nil }
      end
    end

    context "when the value is configured on grandparent" do
      let(:grandparent_values) { { key => value } }

      it { is_expected.to eq(value) }

      context "with only_self: true" do
        let(:only_self) { true }

        it { is_expected.to be_nil }
      end
    end
  end

  describe "#set" do
    subject { instance.send(key) }

    before do
      instance.set(key, value)
    end

    context "for a value without a special setter" do
      it { is_expected.to eq(value) }
    end

    context "for the key :url" do
      let(:key) { :url }
      let(:value) { "http://example.com" }

      it { is_expected.to be_a(URI) }
    end

    context "for the key :base_url" do
      let(:key) { :base_url }
      let(:value) { "http://example.com" }

      it { is_expected.to be_a(URI) }
    end
  end

  describe "#search_hash_key" do
    let(:hash_key) { :hash_key }

    subject { instance.search_hash_key(key, hash_key) }

    context "when the attribute isn't configured anywhere in the hierarchy" do
      it { expect { subject }.to raise_error(RuntimeError) }
    end

    context "when the attribute isn't configured on the child, but on the parent" do
      let(:parent_values) { { key => value } }

      it { expect { subject }.not_to raise_error }
    end

    context "when the attribute is configured on the child" do
      let(:child_values)  { { key => value } }

      context "but its value is not a Hash" do
        it { is_expected.to be_nil }
      end

      context "and the value is a Hash" do
        context "but the hash key is not present" do
          let(:value) { { some_other_key: 2 } }

          it { is_expected.to be_nil }
        end

        context "and the hash key present" do
          let(:value) { { hash_key => :hash_value } }

          it { is_expected.to eq(:hash_value) }
        end
      end
    end

    context "when the attribute is configured on the parent" do
      let(:parent_values)  { { key => value } }

      context "and the value is a Hash" do
        context "but the hash key is not present" do
          let(:value) { { some_other_key: 2 } }

          it { is_expected.to be_nil }
        end

        context "and the hash key present" do
          let(:value) { { hash_key => :parent_hash_value } }

          it { is_expected.to eq(:parent_hash_value) }
        end

        context "and the hash key present in both parent and child" do
          let(:child_values) do
            {
              key => { hash_key => :child_hash_value }
            }
          end

          let(:parent_values) do
            {
              key => { hash_key => :parent_hash_value }
            }
          end

          it { is_expected.to eq(:child_hash_value) }
        end
      end
    end
  end

  describe "#dup" do
    let(:child_values)        { { value1: "foo" } }
    let(:parent_values)       { { value2: "bar" } }
    let(:grandparent_values)  { { value3: "baz" } }

    let(:clone) { instance.dup }

    it "duplicated the internal data store" do
      expect(instance.store.object_id).not_to eq(clone.store.object_id)
    end

    it "duplicated the parent instance" do
      expect(instance.parent.object_id).not_to eq(clone.parent.object_id)
    end

    it "duplicated the grandparent instance" do
      expect(instance.parent.parent.object_id).not_to eq(clone.parent.parent.object_id)
    end

    context "the clones' values" do
      it { expect(clone.value1).to eq("foo") }
      it { expect(clone.value2).to eq("bar") }
      it { expect(clone.value3).to eq("baz") }
    end

    context "the clones' value objects" do
      it { expect(clone.value1.object_id).not_to eq(instance.value1.object_id) }
      it { expect(clone.value2.object_id).not_to eq(instance.value2.object_id) }
      it { expect(clone.value3.object_id).not_to eq(instance.value3.object_id) }
    end

    context "the grandparents unclonable_attribute" do
      subject { clone.unclonable_attribute }

      its(:object_id) { is_expected.to eq(grandparent.unclonable_attribute.object_id) }
    end
  end
end

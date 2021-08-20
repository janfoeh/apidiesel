# frozen_string_literal: true

module Apidiesel
  # `Config` is a key-value store that allows for multiple stores
  # to be chained together in a hierarchical fashion.
  #
  # ```ruby
  # parent =
  #   Apidiesel::Config.new
  # child =
  #   Apidiesel::Config.new(parent: parent)
  #
  # parent.set :foo, "foo"
  #
  # # If a child doesn't have its own value for a key, the parent
  # # hierarchy is traversed until it is found
  # child.foo
  # # => "foo"
  #
  # child.set :foo, "bar"
  # child.foo
  # # => "bar"
  # parent.foo
  # # => "foo"
  # ```
  class Config
    # If you initialize a `Config` store with a block, the block
    # is executed in the scope of a `Setter` instance
    #
    # ```ruby
    # config =
    #   Apidiesel::Config.new do
    #     # scope is `Setter.new`
    #     key1 :foo
    #     key2 :bar
    #   end
    #
    # config.key1
    # # => :foo
    # ```
    class Setter
      attr_reader :store

      def initialize
        @store = {}
      end

      def method_missing(method_name, value = nil, **kargs)
        store[method_name.to_sym] =
          if value
            value
          elsif kargs[:value].is_a?(Proc)
            kargs[:value].call
          elsif kargs[:value]
            kargs[:value]
          end
      end

      def respond_to_missing?(method_name, *args)
        true
      end
    end

    attr_reader :store
    attr_accessor :label
    attr_accessor :parent

    # ```ruby
    # config =
    #   Apidiesel::Config.new do
    #     # scope is `Setter.new`
    #     key1 :foo
    #     key2 :bar
    #   end
    #
    # config.key1
    # # => :foo
    # ```
    #
    # @param config [Hash] the initial keys and values
    # @param parent [Apidiesel::Config, nil] a parent store
    # @param label  [Symbol, String, nil] a store name. Helps with debugging
    # @yield A given block will be executed in the scope of a `Setter` instance
    def initialize(config = {}, parent: nil, label: nil, &block)
      @label  = label
      @store  = config
      @parent = parent

      if block_given?
        setter = Setter.new

        setter.instance_eval(&block)

        setter.store.each { |key, value| set(key, value) }
      end
    end

    # Is a configuration key `key` configured?
    #
    # @param key        [Symbol]
    # @param only_self  [Boolean] do not check parent stores
    # @return [Boolean]
    def configured?(key, only_self: false)
      if store.has_key?(key)
        return true
      else
        return false if only_self
      end

      parent.try(:configured?, key)
    end

    # Is a configuration key `key` configured and a value `#present?`
    #
    # @param key        [Symbol]
    # @param only_self  [Boolean] do not check parent stores
    # @return [Boolean]
    def present?(key, only_self: false)
      configured?(key, only_self: only_self) && fetch(key, only_self: only_self).present?
    end

    # The topmost store in the configuration chain
    # @return [Apidiesel::Config]
    def root
      parent ? parent.root : self
    end

    # The complete chain of stores excluding `self`
    #
    # @return [Array<Apidiesel::Config>]
    def parents
      parent ? parent.parents.prepend(parent) : []
    end

    # Fetch the value for key `key`
    #
    # @param key        [Symbol]
    # @param only_self  [Boolean] do not check parent stores
    # @return [Object]
    def fetch(key, only_self: false)
      key = key.to_sym

      if store[key]
        store[key]
      else
        parent.try(:fetch, key) unless only_self
      end
    end

    # Set the value for key `key`
    #
    # @param key   [Symbol]
    # @param value [Object]
    # @return [Object]
    def set(key, value)
      setter_method = "#{key}="
      key           = key.to_sym

      if respond_to?(setter_method)
        send(setter_method, value)
      else
        store[key] = value
      end
    end

    # Specialized setter for `#set(:url, value)` that casts
    # value as `URI`
    #
    # @param value [String]
    # @return [void]
    def url=(value)
      store[:url] = value.present? ? URI.parse(value) : value
    end

    # Specialized setter for `#set(:base_url, value)` that casts
    # value as `URI`
    #
    # @param value [String]
    # @return [void]
    def base_url=(value)
      store[:base_url] = value.present? ? URI.parse(value) : value
    end

    # Searches for key `key` in hash attribute `attrib` across
    # the configuration chain
    #
    # `search_hash_key` allows you to find a Hash attribute key, even
    # if the child has overloaded that attribute, but does not have that
    # key.
    #
    # @param attrib               [Symbol] the configuration attribute name
    # @param key                  [Object] the Hash key
    # @param skip_existence_check [Boolean] do not check whether the attribute
    #   exists
    # @return [Object, nil]
    def search_hash_key(attrib, key, skip_existence_check: false)
      raise "Config key #{attrib} not found" unless skip_existence_check || configured?(attrib)

      own_value =
        fetch(attrib, only_self: true)

      if own_value.is_a?(Hash) && own_value.has_key?(key)
        return own_value[key]
      end

      parent ? parent.search_hash_key(attrib, key, skip_existence_check: true) : nil
    end

    def method_missing(method_name, *args, **kargs, &block)
      if configured?(method_name.to_sym)
        fetch(method_name.to_sym)
      else
        super
      end
    end

    def respond_to_missing?(method_name, *args)
      configured?(method_name.to_sym) ? true : super
    end

    def dup
      copy = super
      copy.instance_variable_set("@store", store.deep_dup)
      copy.instance_variable_set("@parent", copy.parent.dup)
      copy
    end
  end
end

# frozen_string_literal: true

module Apidiesel
  class Config
    class Setter
      attr_reader :store

      def initialize
        @store = {}
      end

      def method_missing(method_name, value = nil, **kargs)
        store[method_name.to_sym] = value || kargs[:value]
      end

      def respond_to_missing?(method_name, *args)
        true
      end
    end

    attr_reader :store
    attr_accessor :label
    attr_accessor :parent

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

    def configured?(key, only_self: false)
      if store.has_key?(key)
        return true
      else
        return false if only_self
      end

      parent.try(:configured?, key)
    end

    def present?(key, only_self: false)
      configured?(key, only_self: only_self) && fetch(key, only_self: only_self).present?
    end

    def root
      parent ? parent.root : self
    end

    def parents
      parent ? parent.parents.prepend(parent) : []
    end

    def fetch(key, only_self: false)
      key = key.to_sym

      if store[key]
        store[key]
      else
        parent.try(:fetch, key) unless only_self
      end
    end

    def set(key, value)
      setter_method = "#{key}="
      key           = key.to_sym

      if respond_to?(setter_method)
        send(setter_method, value)
      else
        store[key] = value
      end
    end

    def url=(value)
      store[:url] = value.present? ? URI.parse(value) : value
    end

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

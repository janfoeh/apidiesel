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
    attr_accessor :parent

    def initialize(config = {}, parent: nil, &block)
      @store         = config
      @parent        = parent

      if block_given?
        setter = Setter.new

        setter.instance_eval(&block)

        setter.store.each { |key, value| set(key, value) }
      end
    end

    def configured?(key)
      store.has_key?(key) || parent.try(:configured?, key)
    end

    def present?(key)
      configured?(key) && fetch(key).present?
    end

    def root
      parent ? parent.root : self
    end

    def parents
      parent ? parent.parents.prepend(parent) : []
    end

    def fetch(key)
      key = key.to_sym

      if store[key]
        store[key]
      else
        parent.try(:fetch, key)
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

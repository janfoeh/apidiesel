# frozen_string_literal: true

module Apidiesel
  # FilterBuilder defines the methods available within an `responds_with` block
  # when defining an API endpoint.
  class FilterBuilder
    # @!visibility private
    attr_accessor :response_filters, :response_formatters, :global_options

    # @param optional [Boolean] default for all attributes: if true, no exception
    #   is raised if an attribute is not present in the response
    # @param allow_nil [Boolean] default for all attributes: if true, no exception
    #   will be raised if an attributes value is not of the defined type, but nil
    # @!visibility private
    def initialize(optional: false, allow_nil: true)
      @response_filters    = []
      @response_formatters = []
      @global_options      = { optional: optional, allow_nil: allow_nil }
    end

    # @!macro [new] filter_types
    #   Returns a $0 from the API response hash
    #
    #   @overload $0(key, **kargs)
    #     Get the $0 named `key` from the response hash and name it `key` in the result hash
    #
    #     @param key [String, Symbol]
    #     @option kargs [Proc] :prefilter callback for modifying the value before typecasting
    #     @option kargs [Proc] :postfilter callback for modifying the value after typecasting
    #     @option kargs [Proc] :filter alias for :postfilter
    #     @option kargs [Hash] :map a hash map for replacing the value
    #     @option kargs [Boolean] :optional if true, no exception is raised if `key` is not
    #       present in the response
    #     @option kargs [Boolean] :allow_nil if true, no exception is raised if the `key` is
    #       present in the response, but `nil`
    #
    #   @overload $0(at:, as:, **kargs)
    #     Get the $0 named `at:` from the response hash and name it `as:` in the result hash
    #
    #     @param at [String, Symbol, Array<Symbol>] response hash key name or key path to lookup
    #     @param as [String, Symbol] result hash key name to return the value as
    #     @option kargs [Proc] :prefilter callback for modifying the value before typecasting
    #     @option kargs [Proc] :postfilter callback for modifying the value after typecasting
    #     @option kargs [Proc] :filter alias for :postfilter
    #     @option kargs [Hash] :map a hash map for replacing the value
    #     @option kargs [Boolean] :optional if true, no exception is raised if `key` is not
    #       present in the response
    #     @option kargs [Boolean] :allow_nil if true, no exception is raised if the `key` is
    #       present in the response, but `nil`
    #
    #   @return [nil]
    def value(*args, **kargs)
      args = normalize_arguments(args, kargs)

      response_formatters << lambda do |data, processed_data|
        value =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        value = apply_filter(args[:prefilter], value)

        value = apply_filter(args[:postfilter] || args[:filter], value)

        value = args[:map][value] if args[:map]

        processed_data[ args[:as] ] = value

        processed_data
      end
    end

    # @!macro filter_types
    #
    # Please note that response value is typecasted to `String` for comparison, so that
    # for absent values to be considered false, you have to include an empty string.
    #
    # @option kargs [Array<#to_s>, #to_s] :truthy ('true') values to be considered true
    # @option kargs [Array<#to_s>, #to_s] :falsy ('false') values to be considered false
    def boolean(*args, **kargs)
      args = normalize_arguments(args, kargs)

      args.reverse_merge!(truthy: 'true', falsy: 'false')

      args[:truthy] = Array(args[:truthy]).map(&:to_s)
      args[:falsy]  = Array(args[:falsy]).map(&:to_s)

      response_formatters << lambda do |data, processed_data|
        value =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        value = apply_filter(args[:prefilter], value)

        value = if args[:truthy].include?(value.to_s)
          true
        elsif args[:falsy].include?(value.to_s)
          false
        else
          nil
        end

        value = apply_filter(args[:postfilter] || args[:filter], value)

        value = args[:map][value] if args[:map]

        processed_data[ args[:as] ] = value

        processed_data
      end
    end

    # @!macro filter_types
    def string(*args, **kargs)
      create_primitive_formatter(:to_s, *args, **kargs)
    end

    # @!macro filter_types
    def integer(*args, **kargs)
      create_primitive_formatter(:to_i, *args, **kargs)
    end

    # @!macro filter_types
    def float(*args, **kargs)
      create_primitive_formatter(:to_f, *args, **kargs)
    end

    # @!macro filter_types
    def symbol(*args, **kargs)
      create_primitive_formatter(:to_sym, *args, **kargs)
    end

    # @!macro filter_types
    def datetime(*args, **kargs)
      args = normalize_arguments(args, kargs)
      args.reverse_merge!(format: '%Y-%m-%d')

      response_formatters << lambda do |data, processed_data|
        value =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        value = apply_filter(args[:prefilter], value)

        if args.has_key?(:on_error)
          value = DateTime.strptime(value, args[:format]) rescue args[:on_error]
        else
          value = DateTime.strptime(value, args[:format])
        end

        value = apply_filter(args[:postfilter] || args[:filter], value)

        processed_data[ args[:as] ] = value

        processed_data
      end
    end

    # @!macro filter_types
    def date(*args, **kargs)
      args = normalize_arguments(args, kargs)
      args.reverse_merge!(format: '%Y-%m-%d')

      response_formatters << lambda do |data, processed_data|
        value =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        value = apply_filter(args[:prefilter], value)

        if args.has_key?(:on_error)
          value = Date.strptime(value, args[:format]) rescue args[:on_error]
        else
          value = Date.strptime(value, args[:format])
        end

        value = apply_filter(args[:postfilter] || args[:filter], value)

        processed_data[ args[:as] ] = value

        processed_data
      end
    end

    # @!macro filter_types
    def time(*args, **kargs)
      args = normalize_arguments(args, kargs)
      args.reverse_merge!(format: '%Y-%m-%d')

      response_formatters << lambda do |data, processed_data|
        value =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        value = apply_filter(args[:prefilter], value)

        if args.has_key?(:on_error)
          value = Time.strptime(value, args[:format]) rescue args[:on_error]
        else
          value = Time.strptime(value, args[:format])
        end

        value = apply_filter(args[:postfilter] || args[:filter], value)

        processed_data[ args[:as] ] = value

        processed_data
      end
    end

    # @!macro filter_types
    # @example
    #
    #   # Given an API response:
    #   #
    #   # {
    #   #   order_id: 5,
    #   #   ordered_at :"2020-01-01",
    #   #   products: [{
    #   #     name: 'Catnip 2lbs',
    #   #     product_id: 2004921
    #   #   }]
    #   # }
    #
    #   expects do
    #     integer :order_id
    #     datetime :ordered_at
    #
    #     array :products do
    #       string :name
    #       integer :product_id
    #     end
    #   end
    #
    # @example
    #   # Given an API response:
    #   #
    #   # [
    #   #   {
    #   #     name: 'Catnip 2lbs',
    #   #     order_id: 2004921
    #   #   },
    #   #   {
    #   #     name: 'Catnip 5lbs',
    #   #     order_id: 2004922
    #   #   },
    #   # ]
    #
    #   expects do
    #     array do
    #       string :name
    #       integer :order_id
    #     end
    #   end
    def array(*args, **kargs, &block)
      unless block.present?
        create_primitive_formatter(:to_a, *args, **kargs)
        return
      end

      args = normalize_arguments(args, kargs)

      response_formatters << lambda do |data, processed_data|
        if args[:at]
          return processed_data unless has_key_path?(data, args[:at])

          data =
            get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])
        end

        data = apply_filter(args[:prefilter], data)

        if data.nil?
          processed_data[ args[:as] ] = nil
          return processed_data
        end

        array_of_hashes = data.map do |hash|
          builder =
            FilterBuilder.new(optional: global_options[:optional], allow_nil: global_options[:allow_nil])

          builder.instance_eval(&block)

          result = {}

          hash = apply_filter(args[:prefilter_each], hash)

          next if hash.blank?

          builder.response_formatters.each do |filter|
            result = filter.call(hash, result)
            break if result.blank?
          end

          next if result.blank?

          result = apply_filter(args[:postfilter_each] || args[:filter_each], result)

          result
        end

        if args[:as]
          processed_data[ args[:as] ] = array_of_hashes.compact
          processed_data
        else
          array_of_hashes.compact
        end
      end
    end

    # @!macro filter_types
    def hash(*args, **kargs, &block)
      unless block.present?
        create_primitive_formatter(:to_hash, *args, **kargs)
        return
      end

      args = normalize_arguments(args, kargs)

      response_formatters << lambda do |data, processed_data|
        data =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        data = apply_filter(args[:prefilter], data)

        if data.nil?
          processed_data[ args[:as] ] = nil
          return processed_data
        end

        result = {}

        builder =
          FilterBuilder.new(optional: global_options[:optional], allow_nil: global_options[:allow_nil])

        builder.instance_eval(&block)

        builder.response_formatters.each do |filter|
          result = filter.call(data, result)
        end

        result = apply_filter(args[:postfilter_each] || args[:filter_each], result)

        processed_data[ args[:as] ] = result

        processed_data
      end
    end

    # @example
    #   responds_with do
    #     object :issues,
    #             processed_with: ->(data) {
    #               data.delete_if { |k,v| k == 'www_id' }
    #             }
    #   end
    #
    # @example
    #
    #   responds_with do
    #     object :issues,
    #             wrapped_in: Apidiesel::ResponseObjects::Topic
    #   end
    #
    # @!macro filter_types
    # @option kargs [Proc] :processed_with yield the data to this Proc for processing
    # @option kargs [Class] :wrapped_in wrapper object, will be called as `Object.create(data)`
    def objects(*args, **kargs)
      args = normalize_arguments(args, kargs)

      response_formatters << lambda do |data, processed_data|
        value =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        value = apply_filter(args[:prefilter], value)

        value = args[:type].send(:create, value)

        value = apply_filter(args[:postfilter] || args[:filter], value)

        processed_data[ args[:as] ] = value

        processed_data
      end
    end

    %w{value string integer float hash array datetime date time objects symbol}.each do |name|
      define_method "x_#{name}".to_sym, ->(*args, **kargs, &block) { }
    end

    # Descends into the hash key hierarchy
    #
    # Useful for cutting out useless top-level keys
    #
    # @param key [Symbol, Array]
    def set_scope(key)
      response_filters << lambda do |data|
        fetch_path(data, *key)
      end
    end

    # Raises an Apidiesel::ResponseError if the callable returns true
    #
    # @example
    #   responds_with do
    #     response_error_if ->(data) { data[:code] != 0 },
    #                       message: ->(data) { data[:message] }
    #
    # @param callable [Lambda, Proc]
    # @param message  [String, Lambda, Proc]
    # @raise [Apidiesel::ResponseError]
    def response_error_if(callable, message:)
      response_formatters << lambda do |data, processed_data|
        return processed_data unless callable.call(data)

        raise ResponseError.new(error_message(message, data))
      end
    end

    protected

    def error_message(message, data)
      return message if message.is_a?(String)
      return message.call(data) if message.respond_to?(:call)
      'unknown error'
    end

    def create_primitive_formatter(cast_method_symbol, *args, **kargs)
      args = normalize_arguments(args, kargs)

      response_formatters << lambda do |data, processed_data|
        value =
          get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

        return processed_data unless has_key_path?(data, args[:at])

        value = apply_filter(args[:prefilter], value)

        value = value.try(cast_method_symbol) unless value.nil?

        value = apply_filter(args[:postfilter] || args[:filter], value)

        value = args[:map][value] if args[:map] && !value.nil?

        processed_data[ args[:as] ] = value

        processed_data
      end
    end

    def normalize_arguments(args, kargs)
      if args.length == 1
        kargs[:as] ||= args.first
        kargs[:at] ||= args.first
      end

      kargs =
        kargs.reverse_merge(global_options)

      kargs
    end

    def apply_filter(filter, value)
      return value unless filter

      filter.call(value)
    end

    # @param optional [Boolean] if false, raise an exception on missing keys
    # @param allow_nil [Boolean] if false, raise an exception on nil values
    def get_value(hash, *keys, optional:, allow_nil:)
      keys = keys.first if keys.first.is_a?(Array)

      value =
        if keys.length > 1
          fetch_path(hash, keys, optional: optional)
        else
          raise MalformedResponseError, "Missing key '#{keys.first}'" if !hash.has_key?(keys.first) && !optional
          hash[keys.first]
        end

      if value.nil? && !allow_nil
        raise MalformedResponseError, "Key '#{key}' has an unexpected nil value"
      end

      value
    end

    # @param optional [Boolean] if false, raise an exception on missing keys
    def fetch_path(hash, key_or_keys, optional:)
      Array(key_or_keys).reduce(hash) do |memo, key|
        if memo
          raise MalformedResponseError, "Missing key '#{key}'" if !memo.has_key?(key) && !optional
          memo[key]
        end
      end
    end

    def has_key_path?(hash, key_or_keys)
      keys = [*key_or_keys]

      return unless hash.is_a?(Hash)
      return hash.has_key?(keys.first) if keys.one?

      results = []

      keys.reduce(hash) do |memo, key|
        next unless memo

        results << memo.has_key?(key)

        memo[key]
      end

      results.all?
    end
  end
end

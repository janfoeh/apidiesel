# frozen_string_literal: true

module Apidiesel
  # FilterBuilder defines the methods available within an `responds_with` block
  # when defining an API endpoint.
  class FilterBuilder
    # @!visibility private
    attr_accessor :global_options
    attr_accessor :processors
    attr_reader :expect_array

    # @param optional [Boolean] default for all attributes: if true, no exception
    #   is raised if an attribute is not present in the response
    # @param allow_nil [Boolean] default for all attributes: if true, no exception
    #   will be raised if an attributes value is not of the defined type, but nil
    # @!visibility private
    def initialize(optional: true, allow_nil: true, array: false)
      @processors     = []
      @expect_array   = array
      @global_options = { optional: optional, allow_nil: allow_nil }
    end

    # All processors wrapped into one root container element - a Hash or an
    # Array processor
    #
    # @return [Processors::Hash, Processors::Array]
    def root_processor
      if processors.one?
        root = processors.first

        if root.is_a?(Processors::Array) ||(root.is_a?(Processors::Hash) && !expect_array)
          return root
        end

      else
        root =
          Processors::Hash.new(**global_options)
                          .tap { |processor| processor.children = @processors }

        return root unless expect_array
      end

      Processors::Array.new(**global_options)
                        .tap { |processor| processor.children = root }
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
      kargs = normalize_arguments(args, kargs)

      processors << Processors::Attribute.new(**kargs)
    end

    # @!macro filter_types
    #
    # @param truthy [Array, Object] values to be considered true
    # @param falsy  [Array, Object] values to be considered false
    def boolean(*args, truthy: [true, 'true'], falsy: [false, 'false'], **kargs)
      kargs = normalize_arguments(args, kargs)

      processors << Processors::Boolean.new(truthy: [*truthy], falsy: [*falsy], **kargs)
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
    # @param format [String] the expected value format
    # @option kargs [Object] :on_error the value to return instead
    #   if conversion fails. Prevents conversion exceptions if set.
    def datetime(*args, format: '%Y-%m-%d', **kargs)
      kargs = normalize_arguments(args, kargs)

      processors << Processors::DateOrTime.new(klass: DateTime, format: format, **kargs)
    end

    # @!macro filter_types
    # @param format [String] the expected value format
    # @option kargs [Object] :on_error the value to return instead
    #   if conversion fails. Prevents conversion exceptions if set.
    def date(*args, format: '%Y-%m-%d', **kargs)
      kargs = normalize_arguments(args, kargs)

      processors << Processors::DateOrTime.new(klass: Date, format: format, **kargs)
    end

    # @!macro filter_types
    # @param format [String] the expected value format
    # @option kargs [Object] :on_error the value to return instead
    #   if conversion fails. Prevents conversion exceptions if set.
    def time(*args, format: '%Y-%m-%d', **kargs)
      kargs = normalize_arguments(args, kargs)

      processors << Processors::DateOrTime.new(klass: Time, format: format, **kargs)
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

      kargs =
        normalize_arguments(args, kargs)

      processors << processor =
        Processors::Array.new(**kargs)

      builder =
        FilterBuilder.new(**global_options)

      builder.instance_eval(&block)

      processor.children = builder.root_processor
    end

    # @!macro filter_types
    def hash(*args, **kargs, &block)
      unless block.present?
        create_primitive_formatter(:to_hash, *args, **kargs)
        return
      end

      kargs =
        normalize_arguments(args, kargs)

      processors << processor =
        Processors::Hash.new(**kargs)

      builder =
        FilterBuilder.new(**global_options)

      builder.instance_eval(&block)

      processor.children = builder.processors
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
    # TODO
    def objects(*args, **kargs)
      kargs = normalize_arguments(args, kargs)

      processors << Processors::Attribute.new(**kargs)

      # response_formatters << lambda do |data, processed_data|
      #   value =
      #     get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

      #   return processed_data unless has_key_path?(data, args[:at])

      #   value = apply_filter(args[:prefilter], value)

      #   value = args[:type].send(:create, value)

      #   value = apply_filter(args[:postfilter] || args[:filter], value)

      #   processed_data[ args[:as] ] = value

      #   processed_data
      # end
    end

    # We define an x_-prefixed no-op for every attribute. These allow us to keep attributes
    # in a `responds_with` block for documentation purposes, while ignoring them in the output.
    %w{value string integer float hash array datetime date time objects symbol}.each do |name|
      define_method "x_#{name}".to_sym, ->(*args, **kargs, &block) { }
    end

    private

    def create_primitive_formatter(cast_method_symbol, *args, **kargs)
      kargs = normalize_arguments(args, kargs)

      processors << Processors::Primitive.new(cast: cast_method_symbol, **kargs)
    end

    def normalize_arguments(args, kargs)
      if args.length == 1
        kargs[:as] ||= args.first
        kargs[:at] ||= args.first
      end

      kargs[:read_key]  = kargs.delete(:at)
      kargs[:write_key] = kargs.delete(:as)

      kargs =
        kargs.reverse_merge(global_options)

      kargs
    end
  end
end

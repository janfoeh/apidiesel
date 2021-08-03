# frozen_string_literal: true

module Apidiesel
  module Dsl
    # Defines the input parameters expected for this API endpoint.
    #
    # @example
    #   expects do
    #     string :query
    #     integer :per_page, :optional => true, :default => 10
    #   end
    #
    # See the {Apidiesel::Dsl::ExpectationBuilder ExpectationBuilder} instance methods
    # for more information on what to use within `expect`.
    #
    # @macro [attach] expects
    #   @yield [Apidiesel::Dsl::ExpectationBuilder]
    def expects(&block)
      builder = ExpectationBuilder.new
      builder.instance_eval(&block)

      config.parameter_validations.replace(builder.parameter_validations)
      config.parameters_to_filter.replace(builder.parameters_to_filter)
    end

    # Defines the expected content and format of the response for this API endpoint.
    #
    # @example
    #   responds_with do
    #     string :user_id
    #   end
    #
    # See the {Apidiesel::Dsl::FilterBuilder} instance methods for more information
    # on what to use within `responds_with`.
    #
    # You can define multiple _scenarios_ in which different responses are returned by the API,
    # such as successful and failure situations. Out of the box, Apidiesel supports scenarios
    # labelled `:http_<http status code>` (eg. `:http_204`) or `:http_<http status code class>xx`
    # (eg. `:http_2xx`). If one exists, it is used over the default one:
    #
    # @example
    # ```ruby
    # responds_with(scenario: :http_403) do
    #   # no body in response for 403
    # end
    #
    # responds_with(scenario: [:http_4xx, http_5xx]) do
    #   integer :error_code
    #   string  :error_message
    # end
    #
    # responds_with do
    #   string :firstname
    #   string :lastname
    # end
    # ```
    #
    # If you have different needs for scenario selection, you can configure a different
    # detector in your endpoints `config`:
    #
    # ```ruby
    #   class MyEndpoint < Apidiesel::Endpoint
    #     config.response_detector ->(request:, config:) {
    #       # Your Proc receives the current `Apidiesel::Request`, plus
    #       # the endpoints `Apidiesel::Config`, and is expected to return
    #       # either a specific scenario name `Symbol` or `:default`
    #     }
    # ```
    #
    # @macro [attach] responds_with
    #   @param scenario             [Symbol, Array<Symbol>]
    #   @param attributes_optional  [Boolean] default for all attributes: if true, no exception
    #     is raised if an attribute is not present in the response
    #   @param attributes_allow_nil [Boolean] default for all attributes: if true, no exception
    #     will be raised if an attributes value is not of the defined type, but nil
    #   @yield [Apidiesel::Dsl::FilterBuilder]
    def responds_with(scenario: :default, attributes_optional: false, attributes_allow_nil: true, **args, &block)
      builder = FilterBuilder.new(optional: attributes_optional, allow_nil: attributes_allow_nil)

      builder.instance_eval(&block)

      [*scenario].each do |scenario_label|
        config.response_filters[scenario_label]     ||= []
        config.response_formatters[scenario_label]  ||= []

        config.response_filters[scenario_label].replace(builder.response_filters)
        config.response_formatters[scenario_label].replace(builder.response_formatters)

        if args[:unnested_hash]
          config.response_formatters[scenario_label] << lambda do |_, response|
            if response.is_a?(Hash) && response.keys.length == 1
              response.values.first
            else
              response
            end
          end
        end
      end
    end

    # Semantic sugar for `responds_with` blocks with an explicit `scenario` label
    #
    # @see {responds_with}
    def responds_with_on(scenario, **kargs, &block)
      responds_with(scenario: scenario, **kargs, &block)
    end

    def action(label, &block)
      subklass       = Class.new(self, &block)
      subklass.label = label

      actions << subklass
    end

    # ExpectationBuilder defines the methods available within an `expects` block
    # when defining an API endpoint.
    class ExpectationBuilder
      # @!visibility private
      attr_accessor :parameter_validations, :parameters_to_filter

      # @!visibility private
      def initialize
        @parameter_validations  = []
        @parameters_to_filter   = []
      end

      # Defines a string parameter.
      #
      # ```ruby
      # # This endpoint expects to be given an 'email', which is sent to the API as 'username',
      # # and requires either a 'value1', a 'value2' or both to be present.
      # expects do
      #   string :email, :submitted_as => :username
      #   string :value1, :optional_if_present => :value2
      #   string :value2, :optional_if_present => :value1
      # end
      # ``
      #
      # @!macro [new] expectation_types
      #   @param param_name [Symbol] name of the parameter
      #   @option args [Boolean] :optional (false) defines whether this parameter may be omitted
      #   @option args [Symbol]  :optional_if_present param_name is optional, if the parameter given here is present instead
      #   @option args [Symbol]  :required_if_present param_name is required if param_name is also present
      #   @option args [Symbol]  :submitted_as submit param_name to the API under the name given here
      #   @option args [Object]  :default a default parameter to be set when no value is specified
      #   @option args [Boolean, Symbol] :fetch if not provided by the caller, query the base
      #     `Apidiesel::Api` object for it. It will be taken from either `config[<parameter_name>]`, or the return
      #     value of a method with the same name. If you pass a Symbol, this will be used as the name to lookup
      #     instead
      #   @option args [true, false] :submit (true) set to `false` for arguments that should not be submitted
      #                                               as API parameters
      #   @option args [Enumerable] :allowed_values only accept the values in this Enumerable.
      #                               If Enumerable is a Hash, use the hash values to define what is actually
      #                               sent to the server. Example: `:allowed_values => {:foo => "f"}` allows
      #                               the value ':foo', but sends it as 'f'
      #   @option args [Symbol, Proc] :typecast A method name or Proc for typecasting the given value into
      #                               the form it will be submitted in
      #   @return [nil]
      def string(param_name, **args)
        validation_builder(:to_s, param_name, **args)
        parameters_to_filter << param_name if args[:submit] == false
      end

      # Defines a symbol parameter
      #
      # This is primarily used in places where symbols are more convenient for the API user;
      # the value itself will be transmitted as a String.
      #
      # @example
      #   expects do
      #     symbol :status, allowed_values: %i(pending open closed)
      #   end
      #
      # @!macro expectation_types
      def symbol(param_name, **args)
        validation_builder(:to_s, param_name, **args)
        parameters_to_filter << param_name if args[:submit] == false
      end

      # Defines an integer parameter.
      #
      # By default, `#to_i` is called on the input value; set `:typecast` to override.
      #
      # @example
      #   expects do
      #     integer :per_page, :optional => true
      #   end
      #
      # @!macro expectation_types
      def integer(param_name, **args)
        validation_builder(:to_i, param_name, **args)
        parameters_to_filter << param_name if args[:submit] == false
      end

      # Defines a boolean parameter.
      #
      # FIXME: sensible duck typing check
      #
      # @example
      #   expects do
      #     boolean :per_page, :optional => true
      #   end
      #
      # @!macro expectation_types
      def boolean(param_name, **args)
        args[:typecast] = nil

        validation_builder(nil, param_name, **args)
        parameters_to_filter << param_name if args[:submit] == false
      end

      # Defines a date, time or datetime parameter.
      #
      #
      # @example
      #   expects do
      #     datetime :starts_at, format: '%d-%m-%Y'
      #   end
      #
      # @!macro expectation_types
      # @option args [String] :format a format string as supported by Rubys `#strftime`
      def datetime(param_name, **args)
        if args[:format]
          args[:processor] = ->(value) { value.try(:strftime, args[:format]) }
        end

        args[:typecast] = nil

        validation_builder(:strftime, param_name, **args)
        parameters_to_filter << param_name if args[:submit] == false
      end

      alias_method :time, :datetime
      alias_method :date, :datetime

      # Defines an object parameter
      #
      # By default, `#to_hash` is called on the input value; set `:typecast` to override.
      #
      # @example
      #   expects do
      #     object :contract, klass: Contract
      #   end
      #
      # @!macro expectation_types
      # @option args [Class] :klass the expected class of the value
      def object(param_name, **args)
        args[:typecast] = args[:typecast] || :to_hash

        type_check = ->(value, param_name) {
          unless value.is_a?(args[:klass])
            raise Apidiesel::InputError, "arg #{param_name} must be a #{args[:klass].name}"
          end
        }

        validation_builder(type_check, param_name, **args)
        parameters_to_filter << param_name if args[:submit] == false
      end

        protected

      def validation_builder(duck_typing_check, param_name, typecast: duck_typing_check, **args)
        options = args

        parameter_validations << lambda do |api, config, given_params, processed_params|
          given_value = given_params[param_name]

          if options[:fetch] && given_value.nil?
            lookup_name =
              options[:fetch].is_a?(Symbol) ? options[:fetch] : param_name

            if config.fetch(lookup_name)
              given_value = config.fetch(lookup_name)

            elsif api.respond_to?(lookup_name)
              given_value = api.send(lookup_name)
            end
          end

          if options[:default]
            given_params[param_name] ||= options[:default]
          end

          if options.has_key?(:optional_if_present)
            options[:optional] = true unless given_params[ options[:optional_if_present] ].blank?
          end

          if options.has_key?(:required_if_present)
            options[:optional] = given_params[ options[:required_if_present] ].present? ? false : true
          end

          unless options.has_key?(:optional) && options[:optional] == true
            raise Apidiesel::InputError, "missing arg: #{param_name} - options: #{options.inspect}" if given_value.blank?

            if duck_typing_check.is_a?(Proc)
              duck_typing_check.call(given_value, param_name)
            elsif !duck_typing_check.nil?
              raise Apidiesel::InputError, "invalid arg #{param_name}: must respond to #{duck_typing_check}" unless given_value.respond_to?(duck_typing_check)
            end
          end

          if options[:typecast] && given_value
            given_value =
              case options[:typecast]
              when Symbol
                given_value.send(options[:typecast])
              when Proc
                options[:typecast].call(given_values)
              end
          end


          if options.has_key?(:allowed_values) && !given_value.blank?
            unless options[:allowed_values].include?(given_value)
              raise Apidiesel::InputError, "value '#{given_value}' is not a valid value for #{param_name}"
            end

            if options[:allowed_values].is_a? Hash
              given_value = options[:allowed_values][ given_value ]
            end
          end

          if options[:processor]
            given_value = options[:processor].call(given_value)
          end

          if options[:submitted_as]
            processed_params[ options[:submitted_as] ] = given_value
          else
            processed_params[param_name] = given_value
          end

          # Values marked `submit: false` we write back into the parameters hash
          # passed in when the endpoint was invoked.
          # This is primarily used for values needed in URL placeholders.
          if options[:submit] == false
            given_params[param_name] = given_value
          end
        end
      end
    end

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
            data =
              get_value(data, args[:at], optional: args[:optional], allow_nil: args[:allow_nil])

            return processed_data unless has_key_path?(data, args[:at])
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
end

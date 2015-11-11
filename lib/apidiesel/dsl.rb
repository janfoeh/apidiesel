module Apidiesel
  module Dsl
    # Defines the input parameters expected for this API action.
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
      parameter_validations.concat builder.parameter_validations
    end

    # Defines the expected content and format of the response for this API action.
    #
    # @example
    #   responds_with do
    #     string :user_id
    #   end
    #
    # See the {Apidiesel::Dsl::FilterBuilder FilterBuilder} instance methods
    # for more information on what to use within `responds_with`.
    #
    # @macro [attach] responds_with
    #   @yield [Apidiesel::Dsl::FilterBuilder]
    def responds_with(&block)
      builder = FilterBuilder.new
      builder.instance_eval(&block)
      response_filters.concat builder.response_filters
      response_formatters.concat builder.response_formatters
    end

    # ExpectationBuilder defines the methods available within an `expects` block
    # when defining an API action.
    class ExpectationBuilder
      attr_accessor :parameter_validations

      def initialize
        @parameter_validations  = []
      end

      # Defines a string parameter.
      #
      # @example
      #   expects do
      #     string :email, :submitted_as => :username
      #     string :value1, :optional_if_present => :value2
      #     string :value2, :optional_if_present => :value1
      #   end
      #
      #   # This action expects to be given an 'email', which is sent to the API as 'username',
      #   # and requires either a 'value1', a 'value2' or both to be present.
      #
      # @param [Symbol] param_name name of the parameter
      # @param [Hash] *args
      # @option *args [Boolean] :optional (false) defines whether this parameter may be omitted
      # @option *args [Symbol] :optional_if_present param_name is optional, if the parameter given here is present instead
      # @option *args [Symbol] :required_if_present param_name is required if param_name is also present
      # @option *args [Symbol] :submitted_as submit param_name to the API under the name given here
      # @option *args [Object] :default a default parameter to be set when no value is specified
      # @option *args [Enumerable] :allowed_values only accept the values in this Enumerable.
      #                             If Enumerable is a Hash, use the hash values to define what is actually
      #                             sent to the server. Example: `:allowed_values => {:foo => "f"}` allows
      #                             the value ':foo', but sends it as 'f'
      def string(param_name, *args)
        validation_builder(:to_s, param_name, *args)
      end

      # Defines an integer parameter.
      #
      # @example
      #   expects do
      #     integer :per_page, :optional => true
      #   end
      #
      # @param (see #string)
      # @option (see #string)
      def integer(param_name, *args)
        validation_builder(:to_i, param_name, *args)
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
      # @param (see #string)
      # @option (see #string)
      def boolean(param_name, *args)
        validation_builder(:to_s, param_name, *args)
      end

      # Defines a date, time or datetime parameter.
      #
      #
      # @example
      #   expects do
      #     datetime :starts_at, format: '%d-%m-%Y'
      #   end
      #
      # @param (see #string)
      # @option *args [String] :format strftime format string
      # @option (see #string)
      def datetime(param_name, **args)
        if args[:format]
          args[:processor] = ->(value) { value.try(:strftime, args[:format]) }
        end

        validation_builder(:strftime, param_name, **args)
      end

        protected

      def validation_builder(duck_typing_check, param_name, *args)
        options = args.extract_options!

        parameter_validations << lambda do |given_params, processed_params|
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
            raise Apidiesel::InputError, "missing arg: #{param_name} - options: #{options.inspect}" unless given_params.has_key?(param_name) && !given_params[param_name].blank?
            raise Apidiesel::InputError, "invalid arg #{param_name}: must respond to #{duck_typing_check}" unless given_params[param_name].respond_to?(duck_typing_check)
          end

          if options.has_key?(:allowed_values) && !given_params[param_name].blank?
            unless options[:allowed_values].include?(given_params[param_name])
              raise Apidiesel::InputError, "value '#{given_params[param_name]}' is not a valid value for #{param_name}"
            end

            if options[:allowed_values].is_a? Hash
              given_params[param_name] = options[:allowed_values][ given_params[param_name] ]
            end
          end

          if options[:processor]
            given_params[param_name] = options[:processor].call(given_params[param_name])
          end

          if options[:submitted_as]
            processed_params[ options[:submitted_as] ] = given_params[param_name]
          else
            processed_params[param_name] = given_params[param_name]
          end
        end
      end
    end

    # FilterBuilder defines the methods available within an `responds_with` block
    # when defining an API action.
    class FilterBuilder
      attr_accessor :response_filters, :response_formatters

      def initialize
        @response_filters    = []
        @response_formatters = []
      end

      # Returns `key` from the API response as a string.
      #
      # @param [Symbol] key the key name to be returned as a string
      # @param [Hash] *args
      # @option *args [Symbol] :within look up the key in a namespace (nested hash)
      def string(key, *args)
        copy_value_directly(key, *args)
      end

      # Returns `key` from the API response as an integer.
      #
      # @param (see #string)
      # @option (see #string)
      def integer(key, *args)
        copy_value_directly(key, *args)
      end

      # Returns `key` from the API response as a hash.
      #
      # @param (see #string)
      # @option (see #string)
      def hash(key, *args)
        copy_value_directly(key, *args)
      end

      # Returns `key` from the API response as an array.
      #
      # @param (see #string)
      # @option (see #string)
      def array(key, *args)
        copy_value_directly(key, *args)
      end

      # Returns the API response processed or wrapped in wrapper objects.
      #
      # @example
      #   responds_with do
      #     object :issues, :processed_with => lambda { |data| data.delete_if { |k,v| k == 'www_id' } }
      #   end
      #
      # @example
      #
      #   responds_with do
      #     object :issues, :wrapped_in => Apidiesel::ResponseObjects::Topic
      #   end
      #
      # @param [Symbol] key the key name to be wrapped or processed
      # @option *args [Symbol] :within look up the key in a namespace (nested hash)
      # @option *args [Proc] :processed_with yield the data to this Proc for processing
      # @option *args [Class] :wrapped_in wrapper object, will be called as `Object.create(data)`
      # @option *args [Symbol] :as key name to save the result as
      def objects(key, *args)
        options = args.extract_options!

        response_formatters << lambda do |data, processed_data|
          d = get_value(key, data, options[:within])

          if options[:processed_with]
            d = options[:processed_with].call(d)
          end
          if options[:wrapped_in]
            d = options[:wrapped_in].send(:create, d)
          end

          result_key = options[:as] || key

          processed_data[result_key] = d

          processed_data
        end
      end

      # Descends into the hash key hierarchy
      #
      # Useful for cutting out useless top-level keys
      #
      # @param [Symbol, Array] key
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
      # @param [Lambda, Proc] callable
      # @param [String, Lambda, Proc] message
      # @raises [Apidiesel::ResponseError]
      def response_error_if(callable, message:)
        response_formatters << lambda do |data, processed_data|
          return processed_data unless callable.call(data)

          message = message.is_a?(String) ? message : message.call(data)

          raise ResponseError.new(message)
        end
      end

        protected

      def get_value(key, hash, namespace = nil)
        if namespace.is_a?(Array)
          fetch_path(hash, *namespace)
        elsif namespace.nil?
          hash[key]
        else
          hash[namespace][key]
        end
      end

      def fetch_path(hash, *parts)
        parts.reduce(hash) do |memo, key|
          memo[key] if memo
        end
      end

      def copy_value_directly(key, *args)
        options = args.extract_options!

        response_formatters << lambda do |data, processed_data|
          processed_data[key] = get_value(key, data, options[:within])

          processed_data
        end
      end

    end

  end
end
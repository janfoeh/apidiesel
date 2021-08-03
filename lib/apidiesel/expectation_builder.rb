# frozen_string_literal: true

module Apidiesel
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
        if args[:klass] && !value.is_a?(args[:klass])
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
end

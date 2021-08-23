# frozen_string_literal: true

module Apidiesel
  # ExpectationBuilder defines the methods available within an `expects` block
  # when defining an API endpoint.
  class ExpectationBuilder
    # @!visibility private
    attr_accessor :parameters
    # @!visibility private
    def initialize
      @parameters = {}
    end

    def parameters_to_filter
      parameters.values
                .select { |param| !param.submit }
                .map(&:output_name)
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
    #   @param name [Symbol] name of the parameter
    #   @option kargs [Boolean] :optional (false) defines whether this parameter may be omitted
    #   @option kargs [Symbol]  :optional_if_present name is optional, if the parameter given here is present instead
    #   @option kargs [Symbol]  :required_if_present name is required if name is also present
    #   @option kargs [Symbol]  :submitted_as submit name to the API under the name given here
    #   @option kargs [Object]  :default a default parameter to be set when no value is specified
    #   @option kargs [Boolean, Symbol] :fetch if not provided by the caller, query the base
    #     `Apidiesel::Api` object for it. It will be taken from either `config[<parameter_name>]`, or the return
    #     value of a method with the same name. If you pass a Symbol, this will be used as the name to lookup
    #     instead
    #   @option kargs [true, false] :submit (true) set to `false` for arguments that should not be submitted
    #                                               as API parameters
    #   @option kargs [Enumerable] :allowed_values only accept the values in this Enumerable.
    #                               If Enumerable is a Hash, use the hash values to define what is actually
    #                               sent to the server. Example: `:allowed_values => {:foo => "f"}` allows
    #                               the value ':foo', but sends it as 'f'
    #   @option kargs [Symbol, Proc] :typecast A method name or Proc for typecasting the given value into
    #                               the form it will be submitted in
    #   @return [nil]
    def string(name, **kargs)
      parameters[name] =
        Parameters::Parameter.new(
          input_name:   name,
          output_name:  kargs.delete(:submitted_as),
          typecast:     :to_s,
          **kargs
        )
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
    def symbol(name, **kargs)
      parameters[name] =
        Parameters::Parameter.new(
          input_name:   name,
          output_name:  kargs.delete(:submitted_as),
          typecast:     :to_s,
          **kargs
        )
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
    def integer(name, **kargs)
      parameters[name] =
        Parameters::Parameter.new(
          input_name:   name,
          output_name:  kargs.delete(:submitted_as),
          typecast:     :to_i,
          **kargs
        )
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
    def boolean(name, **kargs)
      parameters[name] =
        Parameters::Parameter.new(
          input_name:     name,
          output_name:    kargs.delete(:submitted_as),
          allowed_values: [true, false],
          **kargs
        )
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
    # @option kargs [String] :format a format string as supported by Rubys `#strftime`
    def datetime(name, **kargs)
      parameters[name] =
        Parameters::DateTime.new(
          input_name:     name,
          output_name:    kargs.delete(:submitted_as),
          allowed_values: [true, false],
          **kargs
        )
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
    # @option kargs [Class] :klass the expected class of the value
    def object(name, typecast: :to_hash, **kargs)
      parameters[name] =
        Parameters::DateTime.new(
          input_name:     name,
          output_name:    kargs.delete(:submitted_as),
          allowed_values: [true, false],
          typecast:       typecast,
          **kargs
        )
    end
  end
end

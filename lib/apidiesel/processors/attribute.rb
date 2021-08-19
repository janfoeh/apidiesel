# frozen_string_literal: true

module Apidiesel
  module Processors
    class Attribute
      attr_reader :read_key
      attr_reader :write_key
      attr_reader :prefilter
      attr_reader :postfilter
      attr_reader :map
      attr_reader :optional
      attr_reader :allow_nil
      attr_reader :options

      # @param read_key   [Symbol, nil] the key to read the value in a given input, if
      #   the input is a Hash. Leave blank for attributes operating on non-Hash inputs
      # @param write_key  [Symbol, nil] the key the processed output is written back to.
      #   Leave blank for attributes not operating on Hash inputs
      # @param prefilter  [Proc, nil] a proc for transforming the output prior to the
      #   primary operation of the attribute (type casting etc.)
      # @param postfilter [Proc, nil] a proc for transforming the output after the
      #   primary operation of the attribute (type casting etc.)
      # @param map        [Hash] a map for value replacements in the form of
      #   `{ value => replacement }`
      # @param optional   [Boolean] if false, an exception is raised if `read_key` is
      #   missing, or if the input is nil
      # @param allow_nil  [Boolean] if false, an exception is raised if `read_key` is
      #   present but nil
      # @option options Options specific to subclasses of `Attribute`
      # @return [self]
      def initialize(read_key: nil, write_key: nil, prefilter: nil, postfilter: nil,
                      map: nil, optional: false, allow_nil: false, **options)
        @read_key   = read_key
        @write_key  = write_key
        @prefilter  = prefilter
        @postfilter = postfilter
        @map        = map
        @optional   = optional
        @allow_nil  = allow_nil
        @options    = options

        after_initialize if respond_to?(:after_initialize)
      end

      # Apply this processor to `input`
      #
      # @param input       [Object]
      # @param path        [Array<Symbol>] the parent processors Hash key
      #   path in the overall response data. Used to improve exception
      #   messages
      # @param element_idx [Integer, nil] the index of the currently
      #   processed element, if this element is part of an Array. Used to
      #   improve exception messages
      # @raise MalformedResponseError
      # @return [Object] the processed `input` data
      def execute(input, path:, element_idx: nil, response_model: nil, **kargs)
        execute_around(
          input,
          path: path,
          element_idx: element_idx,
          response_model: response_model,
          **kargs
        ) do |subset, path|
          process(subset, path: path, element_idx: element_idx, response_model: response_model, **kargs)
        end
      end

      # Overloaded by subclasses for performing their primary operation
      #
      # @param subset      [Object]
      # @param path        [Array<Symbol>] the parent processors Hash key
      #   path in the overall response data. Used to improve exception
      #   messages
      # @param element_idx [Integer, nil] the index of the currently
      #   processed element, if this element is part of an Array. Used to
      #   improve exception messages
      # @return [Object] the processed `subset` data
      def process(subset, path: nil, element_idx: nil, response_model: nil, **_kargs)
        subset
      end

      def to_model(parent_klass)
        attribute_name = write_key

        parent_klass.class_eval do
          attribute attribute_name
        end

        unless optional
          parent_klass.class_eval do
            validates attribute_name, presence: true
          end
        end
      end

      # An extended #inspect with indentation for nested processors
      #
      # @return [String]
      def display(indent = 0)
        [
          "#{self.class.name.to_s.demodulize} #{read_key} => #{write_key} | #{options.map {|k,v| "#{k}: #{v}" }.join(',')}",
        ].map { |line| (" " * indent) + line }
         .join("\n")
      end

      private

      # This is an around filter which performs the standard checks and
      # modifications to the input data, then yields it to a block.
      #
      # It contains the operations common to all attribute types; the block
      # can then focus on the type-specific operations.
      #
      # @param input       [Object]
      # @param path        [Array<Symbol>] the parent processors Hash key
      #   path in the overall response data
      # @param element_idx [Integer, nil] the index of the currently
      #   processed element, if this element is part of an Array
      # @yieldparam subset [Object] the input subset which is relevant to this
      #   processor. If the full input is `{ a: 1, b: 2}` and this processor
      #   has a `read_key` for `:b`, the subset will be `{ b: 2 }`
      # @yieldparam path [Array<Symbol>] our own Hash key path in the overall
      #   response data (parent path + our own key)
      # @yieldreturn [Object] block must return the processed `input` input
      # @raise MalformedResponseError
      # @return [Object] returns the processed `input` input
      def execute_around(input, path:, element_idx: nil, response_model: nil, **_kargs)
        subset =
          get_subset(input, path: path, element_idx: element_idx, skip_presence_check: response_model.present?)

        subset = apply_filter(prefilter, subset)
        subset = map[subset] if map.present? && subset.present?

        current_path = read_key ? path + [read_key] : path

        # At this point, we've
        # * raised if we wanted to raise
        # * prefiltered if we wanted to
        # * mapped if we wanted to
        #
        # If the value is still nil that's fine, but there is nothing else to do.
        if subset.present?
          subset = yield(subset, current_path)
          subset = apply_filter(postfilter, subset)
        end

        subset
      end

      # Filter `value` through a `filter` proc
      #
      # @param filter [Proc, Symbol] Symbols have `#to_proc`
      #   called on them
      # @param value  [Object]
      # @return [Object]
      def apply_filter(filter, value)
        return value unless filter

        case filter
        when Symbol
          filter.to_proc.call(value)
        when Proc
          filter.call(value)
        else
          raise "unsupported filter type #{filter.class.name}"
        end
      end

      # Is this Attribute made to operate on Hash inputs?
      #
      # @return [Boolean]
      def expects_hash_input?
        read_key.present?
      end

      # Retrieve the part from `input` this attribute is supposed
      # to operate on, and perform presence validations
      #
      # @param input       [Object]
      # @param path        [Array<Symbol>] the parent processors Hash key
      #   path in the overall response data
      # @param element_idx [Integer, nil] the index of the currently
      #   processed element, if this element is part of an Array
      # @yieldparam subset [Object] the input subset which is relevant to this
      #   processor. If the full input is `{ a: 1, b: 2}` and this processor
      #   has a `read_key` for `:b`, the subset will be `{ b: 2 }`
      # @raise MalformedResponseError
      # @return [Object]
      def get_subset(input, path: nil, element_idx: nil, skip_presence_check: false)
        error_args = { input: input, path: path, element_idx: element_idx }

        if input.nil?
          raise_error "missing non-optional value", **error_args if !allow_nil
          return nil
        end

        if !expects_hash_input?
          return input
        end

        unless input.is_a?(::Hash)
          raise_error "cannot extract key #{read_key} from #{input.class.name}", **error_args
        end

        unless skip_presence_check
          if !input.has_key?(read_key) && !optional
            raise_error "missing non-optional key #{read_key}", **error_args
          end

          if input[read_key].nil? && !allow_nil
            raise_error "missing non-optional value for key #{read_key}", **error_args
          end
        end

        input[read_key]
      end

      # Helper for raising nicely formatted MalformedResponseErrors
      #
      # @param message      [String]
      # @param input        [Object] the input we were operating on when the
      #   error occurred
      # @param path         [Array<Symbol>, nil] our position in the overall
      #   response body
      # @param element_idx  [Integer, nil] the index of the currently processed
      #   element, if our input is part of an Array
      # @raise MalformedResponseError
      # @return [void]
      def raise_error(message, input: nil, path: nil, element_idx: nil)
        if path
          message_intro =
            path.map(&:to_s)
                .join('->')

          message_intro << "[#{element_idx}]" if element_idx

          raise MalformedResponseError.new("#{message_intro} #{message}", input)
        else
          raise MalformedResponseError.new(message, input)
        end
      end
    end
  end
end

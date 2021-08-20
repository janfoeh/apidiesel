# frozen_string_literal: true

module Apidiesel
  # @abstract An abstract base class for defining API endpoints
  #
  # An endpoint represents one or more URLs you can execute one
  # or more actions on, the parameters required and the response
  # expected to return.
  #
  # Take a JSON API as an example:
  #
  # ```ruby
  # class MyApi < Apidiesel::Api
  #   use Apidiesel::Handlers::JSON
  # end
  # ```
  #
  # For a simple endpoint that needs no parameters and no processing
  # of the response, our class would look like this:
  #
  # ```ruby
  # module Endpoints
  #   class User < Apidiesel::Endpoint
  #     url "https://www.example.com/users"
  #     http_method :get
  #   end
  # end
  #
  # # and we call it like this:
  # api = MyApi.new
  # api.user.get
  # ```
  #
  # If your API has multiple endpoints, it makes sense to set the base_url
  # on your `Api` base instead:
  #
  # ```ruby
  # class MyApi < Apidiesel::Api
  #   use Apidiesel::Handlers::JSON
  #   base_url "https://www.example.com"
  # end
  #
  # module Endpoints
  #   class User < Apidiesel::Endpoint
  #     url path: "/users"
  #     http_method :get
  #   end
  # end
  # ```
  #
  # Assume `/users` accepted both `GET` and `POST` requests. We can model that within the
  # same Endpoint class through `action` blocks.
  # Action names can be chosen freely, but we're simply naming them after their
  # HTTP methods here:
  #
  # ```ruby
  # module Endpoints
  #   class User < Apidiesel::Endpoint
  #     url path: "/users"
  #
  #     action(:get) do
  #       http_method :get
  #     end
  #
  #     action(:post) do
  #       http_method :post
  #     end
  #   end
  # end
  #
  # api.user.get
  # api.user.post
  # ```
  #
  # Assume `/users` optionally accepted a parameter, such as `/users?only_active=true`:
  #
  # ```ruby
  # module Endpoints
  #   class User < Apidiesel::Endpoint
  #     url path: "/users"
  #
  #     action(:get) do
  #       http_method :get
  #
  #       expects do
  #         boolean :only_active, optional: true
  #       end
  #     end
  #
  #     action(:post) do
  #       http_method :post
  #     end
  #   end
  # end
  #
  # api.user.get
  # api.user.get(only_active: true)
  # ```
  #
  # If a non-optional parameter is missing when the endpoint is executed, an `Apidiesel::InputError`
  # is raised.
  #
  # Assume `GET /users` returns an array of user objects, with a lot more attributes than we need.
  # By defining what we want the response to look like, we can customize the response value with a
  # `responds_with` block.
  #
  # Also assume that both `GET` and `POST` actually return data in the same format. In that case, we
  # can define the response on the class itself instead of twice on each action - just as with the
  # URL configuration, the actions inherit everything else.
  #
  # ```ruby
  # module Endpoints
  #   class User < Apidiesel::Endpoint
  #     url path: "/users"
  #
  #     responds_with do
  #       array do
  #         integer :id
  #         string :username
  #         string :email
  #       end
  #     end
  #
  #     action(:get) do
  #       http_method :get
  #
  #       expects do
  #         boolean :only_active, optional: true
  #       end
  #     end
  #
  #     action(:post) do
  #       http_method :post
  #     end
  #   end
  # end
  # ```
  #
  # If your endpoint responds differently under different circumstances, for example in case
  # of errors, you can configure multiple _response scenarios_.
  #
  # Unnamed response blocks as above are _default_ scenarios. They are used if no better matching
  # response block is found.
  #
  # You can configure responses for one or more specific HTTP status codes (eg. 404), or status
  # code classes (eg. 4xx).
  #
  # ```ruby
  # module Endpoints
  #   class User < Apidiesel::Endpoint
  #     url path: "/users"
  #
  #     responds_with do
  #       array do
  #         integer :id
  #         string :username
  #         string :email
  #       end
  #     end
  #
  #     responds_with scenario: [:http_4xx, :http_500] do
  #       integer :error_code
  #       string :error_message
  #     end
  #
  #     action(:get) do
  #       http_method :get
  #
  #       expects do
  #         boolean :only_active, optional: true
  #       end
  #     end
  #
  #     action(:post) do
  #       http_method :post
  #     end
  #   end
  # end
  # ```
  #
  # Because endpoint classes can inherit configuration from parent classes,
  # a central parent class is a good place for configuring shared error responses:
  #
  # ```ruby
  # class Endpoint < Apidiesel::Endpoint
  #   responds_with scenario: [:http_4xx, :http_500] do
  #     integer :error_code
  #     string :error_message
  #   end
  # end
  #
  # module Endpoints
  #   class User < Endpoint
  #     url path: "/users"
  #
  #     responds_with do
  #       array do
  #         integer :id
  #         string :username
  #         string :email
  #       end
  #     end
  #
  #     action(:get) do
  #       http_method :get
  #
  #       expects do
  #         boolean :only_active, optional: true
  #       end
  #     end
  #
  #     action(:post) do
  #       http_method :post
  #     end
  #   end
  # end
  # ```
  class Endpoint
    extend Dsl
    extend Handlers

    attr_accessor :api
    attr_reader :config

    class << self
      attr_reader :label

      # Because a subclasses configuration is initialized
      # _before_ the label is set, we need to update the
      # configuration label manually at that time.
      #
      # @param [Symbol, String]
      # @return [void]
      def label=(value)
        @label       = value
        config.label = "#{descriptive_name} (#{value})"
      end

      def config
        @config ||= begin
          response_detector = default_response_detector

          Config.new(label: descriptive_name) do
            library_namespace     nil
            request_handlers      value: -> { [] }
            response_handlers     value: -> { [] }
            exception_handlers    value: -> { [] }
            url_value             nil
            url_args              nil
            http_method           nil
            http_basic_username   nil
            http_basic_password   nil
            content_type          nil
            headers               value: -> { {} }
            parameter_validations []
            parameters_to_filter  []
            processors            value: -> { {} }
            processor_models      value: -> { {} }
            response_filters      value: -> { {} }
            response_formatters   value: -> { {} }
            response_detector     response_detector
            parameter_formatter   nil
            parameters_as         :auto
          end
        end
      end

      %i(http_method http_basic_username http_basic_password content_type headers
         parameters_as response_detector library_namespace).each do |config_key|
        define_method(config_key) do |value = nil|
          value.present? ? config.set(config_key, value) : config.fetch(config_key)
        end
      end

      def actions
        @actions ||= []
      end

      def for(label)
        actions.find { |action| action.label == label }
      end

      # A meaningful class name
      #
      # Since variants are implemented using anonymous subclasses,
      # they do not have a name. This returns their parent classes
      # name instead
      #
      # @return [String]
      def descriptive_name
        label ? ancestors.second.name : name
      end

      def format_parameters(&block)
        config.set(:parameter_formatter, block)
      end

      # Defines this Endpoints URL, or modifies the base URL set on `Api`
      #
      # Given keyword arguments such as `path:` will be applied to
      # the `URI` object supplied to `Api.url`.
      #
      # Accepts a `Proc`, which will be called at request time with
      # the URL constructed so far and the current `Exchange` object.
      #
      # A string value and all keyword arguments can contain
      # placeholders for all arguments supplied to the endpoint in
      # Rubys standard `String.%` syntax.
      #
      # @example
      #   class Api < Apidiesel::Api
      #     base_url 'https://foo.example'
      #   end
      #
      #   module Endpoints
      #     # modify the base URL set on `Api`
      #     class EndpointA < Apidiesel::Endpoint
      #       url path: '/endpoint_a'
      #     end
      #
      #     # replace the base URL set on `Api`
      #     class EndpointB < Apidiesel::Endpoint
      #       url 'https://subdomain.foo.example'
      #     end
      #
      #     # modify the base URL set on `Api` with a
      #     # 'username' argument placeholder
      #     class EndpointC < Apidiesel::Endpoint
      #       url path: '/endpoint_c/%{username}'
      #
      #       expects do
      #         string :username, submit: false
      #       end
      #     end
      #
      #     # dynamically determine the URL with a
      #     # `Proc` object
      #     class EndpointD < Apidiesel::Endpoint
      #       url ->(url, exchange) {
      #         url.path = '/' + exchange.endpoint_arguments[:username]
      #                                  .downcase
      #         url
      #       }
      #
      #       expects do
      #         string :username, submit: false
      #       end
      #     end
      #   end
      #
      # @overload url(value)
      #   @param value [String, URI] a complete URL string or `URI`
      #
      # @overload url(**kargs)
      #   @option **kargs [String] any method name valid on Rubys `URI::Generic`
      #
      # @overload url(value)
      #   @param value [Proc] a callback that returns a URL string at request time.
      #     Receives the URL contructed so far and the current `Exchange` instance.
      def url(value = nil, **kargs)
        if value && kargs.any?
          raise ArgumentError, "you cannot supply both argument and keyword args"
        end

        config.set(:url_value, value) if value
        config.set(:url_args, kargs) if kargs.any?
      end

      # When subclassing to create an `action`, we chain our configuration into
      # the subclasses config
      def inherited(subklass)
        subklass.config.parent = config
      end
    end

    # Default mechanism for selecting a response formatter
    #
    # You can define multiple `responds_to` blocks to cover different response
    # scenarios, such as success or failure. The Proc at `config.response_detector`
    # determines which of those blocks gets to handle a response.
    #
    # This is the default mechanism which lets you process responses differently
    # based on the HTTP status code returned.
    #
    # Actions and endpoints can inherit scenarios from their parent classes.
    #
    # @see {Apidiesel::Dsl#responds_with}
    # @return [Proc]
    def self.default_response_detector
      ->(exchange:, config:) {
        status =
          exchange.response
                  .code
                  .to_s

        status_code_label =
          "http_#{status}".to_sym
        status_class_label =
          "http_#{status[0]}xx".to_sym

        case
        when config.search_hash_key(:processors, status_code_label)
          logger.debug "classified response as #{status_code_label}"
          status_code_label

        when config.search_hash_key(:processors, status_class_label)
          logger.debug "classified response as #{status_class_label}"
          status_class_label

        else
          logger.debug "classified response as #{status_code_label}/#{status_class_label}"\
                        ", but no formatters available. Using :default"
          :default
        end
      }
    end

    # Returns current class name formatted for use as a method name
    #
    # Example: {Apidiesel::Endpoints::Foo} will return `foo`
    #
    # @return [String] the demodulized, underscored name of the current Class
    def self.name_as_method
      ::ActiveSupport::Inflector.underscore( ::ActiveSupport::Inflector.demodulize(self.name) )
    end
    private_class_method :name_as_method

    # @param api [Apidiesel::Api] a reference to the parent Api object
    def initialize(api)
      @api = api

      klass_config =
        self.class.config.dup

      klass_config.root.parent =
        api.config

      @config =
        Config.new(parent: klass_config, label: "Instance of #{self.class.descriptive_name}")
    end

    # Performs the endpoint-specific input validations on `*args` according to the endpoints
    # `expects` block, executes the API request and prepares the data according to the
    # endpoints `responds_with` block.
    #
    # @option **args see specific, non-abstract `Apidiesel::Endpoint`
    # @return [Apidiesel::Exchange]
    def build_exchange(**args)
      params = {}

      config.parameter_validations.each do |validation|
        validation.call(api, config, args, params)
      end

      if config.parameter_formatter
        params = config.parameter_formatter.call(params)
      else
        params.except!(*config.parameters_to_filter)
      end

      unless config.include_nil_parameters
        params.delete_if { |key, value| value.nil? }
      end

      exchange = Apidiesel::Exchange.new(endpoint: self, endpoint_arguments: args, parameters: params)
      exchange.url = build_url(args, exchange)

      exchange
    end

    def process_response(exchange)
      body =
        symbolize_response_body(exchange.response.parsed_body)

      scenario =
        instance_exec(exchange: exchange, config: config, &config.response_detector)

      processor       = config.search_hash_key(:processors, scenario)
      processor_model = config.search_hash_key(:processor_models, scenario)

      if processor.blank?
        return body
      end

      begin
        if exchange.endpoint_arguments[:active_model] && processor_model
          response_model =
            processor.execute(body, path: [:__root], response_model_klass: processor_model)

          unless [*response_model].all?(&:valid?)
            exchange.response.exception =
              MalformedResponseError.new("Response produced an invalid response model")
          end

          response_model
        else
          processor.execute(body, path: [:__root])
        end
      rescue => ex
        exchange.response.exception = ex
        nil
      end
    end

      protected

    # @return [URI]
    def build_url(endpoint_arguments, exchange)
      url = case config.url_value
      when String
        URI( config.url_value % endpoint_arguments )
      when URI
        config.url_value
      when Proc
        config.url_value.call(base_url, exchange)
      when nil
        if config.base_url
          config.base_url
        else
          raise Error, "endpoint URL configuration requires a base_url, but none is configured"
        end
      end

      url_args = config.url_args.transform_values do |value|
        value % endpoint_arguments
      end

      if append_path = url_args.delete(:append_path)
        url_string = url.to_s

        unless url_string.end_with?("/")
          url_string << "/"
        end

        append_path.delete_prefix!("/")

        url = URI.join(url_string, append_path)
      end

      url_args.each do |name, value|
        url.send("#{name}=", value)
      end

      url
    end

    # Symbolizes keys on Hash elements of the response body
    #
    # @param body [Object]
    # @return [Object]
    def symbolize_response_body(body)
      case body
      when Hash
        body.deep_symbolize_keys
      when Array
        body.map do |element|
          element.is_a?(Hash) ? element.deep_symbolize_keys : element
        end
      else
        body
      end
    end

    def logger
      api.logger
    end
  end
end

# CHANGELOG

## 1.0.0

Coming from the development release 0.15, 1.0.0 contains a number of breaking changes:

* the term "action" has been replaced by "endpoint" throughout the gem

  `Apidiesel::Action` becomes `Apidiesel::Endpoint`, the default namespace for endpoints
  becomes `<MyNamespace>::Endpoints`
  and so on.

* `Apidiesel::CONFIG` constant has been removed

* `Apidiesel::Api` DSL changes:

  * `register_endpoints` has been removed
  * `url` has been renamed to `base_url`
  * `http_basic_auth` has been removed; use `http_basic_username` and `http_basic_password` instead
  * `config` is now an accessor for a `Apidiesel::Config` instance storing the base class configuration

  Previously:

  ```ruby
  class MyApi < Apidiesel::Api
    url "https://www.example.com"
    config :some_key, "some_value"
    http_basic_auth "username", "password"
  end
  ```

  Now:

  ```ruby
  class MyApi < Apidiesel::Api
    base_url "https://www.example.com"
    config.set :some_key, "some_value"
    http_basic_username "username"
    http_basic_password "password"
  end
  ```

* Endpoints are invoked differently

  Previously, you invoked endpoints by calling their underscored name on your `Api` instance:

  ```ruby
  # old invocation
  api = MyApi.new
  api.my_endpoint(id: 5, username: "foo")
  ```

  Now, this returns a proxy on which you call the endpoints HTTP method:

  ```ruby
  # new invocation
  api = MyApi.new
  api.my_endpoint.post(id: 5, username: "foo")
  ```

* Dynamic endpoint lookup; removal of `register_endpoints`

  You no longer have to call `register_endpoints`; endpoints are looked up dynamically at runtime.

* Endpoint namespacing

  Endpoints can now be namespaced in modules:

  ```ruby
  module Endpoints
    class Pictures < Apidiesel::Endpoint
    end

    module User
      class Pictures < Apidiesel::Endpoint
      end
    end
  end

  api = MyApi.new

  api.pictures.get(limit: 10)
  api.user.pictures.get(limit: 10)
  ```

* Multiple actions per Endpoint

  An endpoint can now contain multiple different actions, for example to support multiple HTTP verbs
  for a single URL:

  ```ruby
  module Endpoints
    class Users < Apidiesel::Endpoint
      url path: "/users"

      action(:list) do
        http_method :get

        expects do
          integer :limit
        end
      end

      action(:get) do
        url path: "/users/%{id}"
        http_method :get

        expects do
          integer :id, submit: false
        end
      end

      action(:post) do
        http_method :post

        expects do
          string :firstname
          string :lastname
        end
      end
    end
  end

  api = MyApi.new

  api.users.list(limit: 20)
  api.users.get(id: 5)
  api.users.post(firstname: "Foo", lastname: "Bar")
  ```

* `responds_with { array :some_key {} }` when `:some_key` is a `Hash`

  Previously, `array :some_key` would work even if the value of `:some_key` was a `Hash`; it would automatically
  wrap the hash in an array. This has changed.

  If you require the old behaviour, use a `:prefilter`:

  ```ruby
  responds_with do
    array(:some_key
          prefilter: ->(value) { value.is_a?(Hash) ? [value] : value }) do
      string :foo
      integer :bar
    end
  end
  ```

* Handlers no longer receive the API config as an argument

  Access the chained config through `request.endpoint.config` instead

* Apidiesel no longer raises on request errors or on errors occurring while processing the response

  You'll receive back a failed `Apidiesel::Request` instead. To regain the previous behaviour, set 
  config values `raise_request_errors true` and `raise_response_errors true`.

* Responses with an empty response body no longer automatically raise exceptions

  As long as your endpoints response block doesn't expect anything different, body-less responses are now perfectly fine.

* Handlers have changed

  Instead of modules with specially named classes in them, handlers are now expected to be a simple class which responds to any or all of `#handle_request`, `#handle_response` or `#handle_exception`.

  Handlers can now optionally be passed args, keyword args and a block through `use`. Because of this they must accept `**kargs` in their `initialize`, or simply subclass `Apidiesel::Handlers::Handler` if they don't care about initializer arguments.

  A basic handler for all three situations would be

  ```ruby
  class MyHandler
    def initialize(*_args, **_kargs)
    end

    def handle_request(request)
    end

    def handle_response(request)
    end

    def handle_exception(request)
    end
  ```

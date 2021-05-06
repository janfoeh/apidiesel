# CHANGELOG

## 1.0.0

Coming from the development release 0.15, 1.0.0 contains a number of breaking changes:

* the term "action" has been replaced by "endpoint" throughout the gem

  `Apidiesel::Action` becomes `Apidiesel::Endpoint`, the default namespace for endpoints
  becomes `<MyNamespace>::Endpoints`, `Apidiesel::Api.register_actions` becomes `Apidiesel::Api.register_endpoints`
  and so on.

* `Apidiesel::CONFIG` constant has been removed

* `Apidiesel::Api` DSL changes:

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

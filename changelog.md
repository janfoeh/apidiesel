# CHANGELOG

## 1.0.0

Coming from the development release 0.15, 1.0.0 contains a number of breaking changes:

* the term "action" has been replaced by "endpoint" throughout the gem

  `Apidiesel::Action` becomes `Apidiesel::Endpoint`, the default namespace for endpoints
  becomes `<MyNamespace>::Endpoints`, `Apidiesel::Api.register_actions` becomes `Apidiesel::Api.register_endpoints`
  and so on.

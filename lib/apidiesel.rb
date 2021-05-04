require 'uri'
require 'httpi'
require 'active_support/all'

HTTPI.log = false

require 'apidiesel/version'

require 'apidiesel/errors'
require 'apidiesel/handlers'
require 'apidiesel/api'
require 'apidiesel/dsl'
require 'apidiesel/request'
require 'apidiesel/endpoint'
require 'apidiesel/handlers/response_processor'
require 'apidiesel/handlers/http_request_helper'
require 'apidiesel/handlers/json'

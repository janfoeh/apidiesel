require 'uri'
require 'httpi'

HTTPI.log = false

require 'apidiesel/version'

require 'apidiesel/errors'
require 'apidiesel/handlers'
require 'apidiesel/api'
require 'apidiesel/dsl'
require 'apidiesel/request'
require 'apidiesel/action'
require 'apidiesel/handlers/action_response_processor'
require 'apidiesel/handlers/http_request_helper'
require 'apidiesel/handlers/json'


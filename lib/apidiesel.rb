# frozen_string_literal: true

require 'uri'
require 'httpi'
require 'active_support/all'

HTTPI.log = false

require 'apidiesel/version'

require 'apidiesel/errors'
require 'apidiesel/handlers'
require 'apidiesel/config'
require 'apidiesel/proxies'
require 'apidiesel/expectation_builder'
require 'apidiesel/filter_builder'
require 'apidiesel/library'
require 'apidiesel/api'
require 'apidiesel/processors/attribute'
require 'apidiesel/processors/container_attribute'
require 'apidiesel/processors/array'
require 'apidiesel/processors/hash'
require 'apidiesel/processors/primitive'
require 'apidiesel/processors/boolean'
require 'apidiesel/processors/date_or_time'
require 'apidiesel/dsl'
require 'apidiesel/request'
require 'apidiesel/endpoint'
require 'apidiesel/handlers/handler'
require 'apidiesel/handlers/response_processor'
require 'apidiesel/handlers/http_request_helper'
require 'apidiesel/handlers/json'

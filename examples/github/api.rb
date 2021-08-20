# frozen_string_literal: true

require "apidiesel"

Dir[ File.join(__dir__, "endpoints", "**", "*.rb") ].each do |file|
  require file
end

module Github
  class Api < Apidiesel::Api
    use Apidiesel::Handlers::JSON

    base_url 'https://api.github.com'
  end
end

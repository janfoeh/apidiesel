require "apidiesel"

Dir[ File.join(__dir__, 'actions', '*.rb') ].each do |file|
  require file
end

module Github
  class Api < Apidiesel::Api
    use Apidiesel::Handlers::JSON

    url 'https://api.github.com'

    register_actions
  end
end
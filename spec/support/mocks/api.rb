# frozen_string_literal: true

module Mocks
  class Api
    include RSpec::Mocks::ExampleMethods

    def self.build(**kargs)
      new.build(**kargs)
    end

    def build(config: Apidiesel::Config.new)
      mock =
        instance_double("Apidiesel::Api")

      if config
        allow(mock).to receive(:config).and_return(config)
      end

      mock
    end
  end
end

# Apidiesel

[![Gem Version](https://badge.fury.io/rb/apidiesel.svg)](https://badge.fury.io/rb/apidiesel) [![Dependency Status](https://gemnasium.com/janfoeh/apidiesel.svg)](https://gemnasium.com/janfoeh/apidiesel)

Apidiesel is a DSL for building API clients. It is made to be highly readable,
easily extensible and to assume as little as possible about your API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'apidiesel'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install apidiesel

## Usage

Apidiesel consists of three main parts: the base `Api`, one `Action` for each API
endpoint and `Handler` plugins for processing incoming and outgoing data.

```ruby
module Actions
  class GetUsers < Apidiesel::Action
    url path: '/users'

    expects do
      string :firstname, optional: true
      string :lastname, optional: true
      boolean :active, default: true
    end

    responds_with do
      objects :users, wrapped_in: MyUserModel
    end
  end
end

class Api < Apidiesel::Api
  url 'https://foo.example'
  http_method :post

  register_actions
end

api = Api.new
api.get_users(firstname: 'Jane', lastname: 'Doe')
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/apidiesel.


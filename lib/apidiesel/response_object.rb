module Apidiesel
  # Abstract wrapper object for response objects
  class ResponseObject
    def self.create(array_of_hashes)
      array_of_hashes.collect do |hash|
        new(hash)
      end
    end

    def initialize(hash)
      @hash = hash
    end

    def raw_data
      @hash
    end

    def method_missing(name)
      if @hash.has_key?(name.to_sym)
        return @hash[name.to_sym]
      end

      super
    end

    def respond_to?(name)
      return true if @hash.has_key?(name.to_sym)
      super
    end
  end
end
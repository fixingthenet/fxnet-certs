require 'hashie/mash'
require 'json'

module FxnetCerts
  class Config
    def self.load(filename)
      new(JSON.parse(File.read(filename)))
    end

    def initialize(hash)
      @config=Hashie::Mash.new(hash)
    end

    def cert(name)
      certs.select do |c| c.name == name end.first
    end
    
    def method_missing(m,*args, &block)
      @config.send(m,*args)
    end
  end
end

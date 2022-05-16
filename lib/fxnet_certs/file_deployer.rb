# coding: utf-8
require 'pp'
module FxnetCerts
  class FileDeployer

    def self.deploy(*args)
      new(*args).deploy!
    end

    def initialize(deployment:,
                   cert:,
                   target:,
                   logger: Logger.new(STDOUT))
      @cert=cert
      @deployment=deployment
      @filename=target.filename
      @logger=logger
    end

    def deploy!
      File.write(@filename, @cert)
      @logger.info("Cert Deployment: result #{@filename}")
      self
    end
  end  
end

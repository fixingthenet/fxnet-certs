# coding: utf-8
require 'pp'
module FxnetCerts
  class S3Deployer

    def self.deploy(*args)
      new(*args).deploy!
    end

    def initialize(deployment:,
                   cert:,
                   target:,
                   logger: Logger.new(STDOUT))
      @cert=cert
      @deployment=deployment
      @bucket = target.bucket
      @path_crt=target.path_crt
      @path_key=target.path_key
      @logger=logger
    end

    def deploy!
      s3_client=Aws::S3::Client.new
      @logger.debug("Uploading full cert: #{@cert.full_body}")
      resp=s3_client.put_object(bucket: @bucket,
                                key: @path_crt,
                                body: StringIO.new(@cert.full_body),
                                acl: 'public-read'
                                )
      @logger.info("Cert Deployment: result #{resp}")
      self
    end
  end  
end

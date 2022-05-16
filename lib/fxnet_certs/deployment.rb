
# { deployments: [
#{ "name": "fxnet-dev", 

#     "test": { "type": "live", 
#     "host": "cert.dev.fixingthe.net"},

#     "test": { "type": "file", 
#     "filename": "/code/data/fxnet-dev.crt"},


#      "target": {
#         "type": "file",
#         "filename": "/code/data/fxnet-dev.crt"
#      },
#      "cert": "fxnet-dev-star"
#    }     
#  ]
# }
module FxnetCerts
  class Deployment

    def initialize(config, cert, logger: Loggern.new(STDOUT))
      @config=config
      @cert=cert
      @logger=logger
    end

    def cert_name
      @config.cert
    end

    def cert_exist?
      @cert.exist?
    end

    def cert_valid_domains?
      true #TBD!
    end

    def cert_valid_after?(min_valid_after)
      @cert.valid_after?(min_valid_after)
    end

    def valid_domains?
      checker.valid_domains?(@cert.fqdns)
    end

    def valid_after?(min_valid_after)
      checker.valid_after?(min_valid_after)
    end

    def name
      @config.name
    end

    def deploy!
      deployer=case @config.target.type
      when 'aws-elb-classic'
        require 'fxnet_certs/aws_elb_deployer'
        AWSELBDeployer
      when 'aws-elb-application'
        require 'fxnet_certs/aws_elbv2_deployer'
        AWSELBV2Deployer
      when 'file'
        require 'fxnet_certs/file_deployer'
        FileDeployer
      when 's3'
        require 'fxnet_certs/s3_deployer'
        S3Deployer
      else
        raise "unkown deployer"
      end
      deployer.deploy(
          deployment: self,
          cert: @cert,
          logger: @logger,
          target: @config.target
        )
    end
    
    private
    
    def checker
      return @checker if defined?(@checker)
      chk=case @config.test.type
      when 'live'
        require 'fxnet_certs/https_live_checker'
        @checker = HTTPSLiveChecker
      when 'file'
        require 'fxnet_certs/file_checker'
        @checker = FileChecker
      when 's3'
        require 'fxnet_certs/file_checker'
        require 'fxnet_certs/s3_checker'
        @checker = S3Checker
      else
        raise "Unknown checker"
      end
      @checker = chk.new(@config.test, logger: @logger)
    end
  end
end

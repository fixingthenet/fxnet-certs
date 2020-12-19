require 'fxnet_certs/https_live_checker'
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
      @live_checker ||= HTTPSLiveChecker.new(@config.test.host,
                                         @config.test.port, logger: @logger)

    end
  end
end

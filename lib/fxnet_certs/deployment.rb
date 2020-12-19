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
      case @config.target.type
      when 'aws-elb-classic'
        require 'fxnet_certs/aws_elb_deployer'
        deployer=AWSELBDeployer.deploy(deployment: self,
                                        cert: @cert,
                                        logger: @logger,
                                        target: @config.target)
      when 'aws-elb-application'
        require 'fxnet_certs/aws_elbv2_deployer'
        deployer=AWSELBV2Deployer.deploy(
          deployment: self,
          cert: @cert,
          logger: @logger,
          target: @config.target
        )
      else
        # don't deploy
      end
    end
    private
    def checker
      @live_checker ||= HTTPSLiveChecker.new(@config.test.host,
                                         @config.test.port, logger: @logger)

    end
  end
end

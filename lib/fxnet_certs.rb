require 'fxnet_certs/config'
require 'fxnet_certs/certificate'
require 'fxnet_certs/deployment'

module FxnetCerts

  class Runner
    DAY=24*60*60
    def initialize(basepath: "/data", logger: Logger.new(STDOUT))
      @basepath=Pathname.new(basepath)
      @logger=logger
      @config=Config.load(@basepath.join("domains.json"))
      @min_valid_after=Time.now+7*DAY
      certificates
      deployments
    end

    def deployment(name)
      @deployments[name]
    end

    def deployments
      return @deployments.values if defined?(@deployments)
      @deployments={}
      @config.deployments.each do |deployment_config|

        deployment=@deployments[deployment_config.name]=Deployment.new(
          deployment_config,
          certificate(deployment_config.cert),
          logger: @logger)
        @logger.debug("Loading deployment: #{deployment.name}")
      end
      @deployments.values
    end

    def certificate(name)
      @certificates[name]
    end

    def certificates
      return @certificates.values if defined?(@certificates)
      @certificates={}
      @config.certs.each do |cert_config|
        cert=@certificates[cert_config.name]=Certificate.new(cert_config.name,
                                                       cert_config.domains,
                                                       @basepath.join('certs'),
                                                       logger: @logger)
        @logger.debug("Loading certificate: #{cert.name}")
      end
      @certificates.values
    end

    def run
      deployments.each do |deployment|
        suggestion=suggest(deployment, min_valid_after: @min_valid_after)
        @logger.info("#{deployment.name.ljust(30)}..........#{suggestion}")
        case suggestion
        when :deploy
          deployment.deploy!

        when :issue
          @logger.debug("Issuing Cert: #{deployment.name}:#{deployment.cert_name}")
          certificate(deployment.cert_name).issue!
          deployment.deploy!
        when :renew
          @logger.debug("Renwing Cert: #{deployment.name}:#{deployment.cert_name}")
          certificate(deployment.cert_name).renew!
          deployment.deploy!
        end
      end
    end

    def suggest(deployment, min_valid_after: )
      if deployment.cert_exist? # check stored state
        if deployment.cert_valid_after?(min_valid_after)
          if deployment.cert_valid_domains?
          # check deployed remote stuff
          else
            :issue
          end
        else
          return :renew
        end
      else
        return :issue
      end

      if deployment.valid_domains?
        if deployment.valid_after?(min_valid_after)
          return :nop
        else
          return :deploy
        end
      else
        return :deploy
      end
    end

  end # Runner

    def self.run(*args)
      puts "run called"
      Runner.new(*args).run
    end
end

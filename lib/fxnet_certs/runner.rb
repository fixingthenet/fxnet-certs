module FxnetCerts
  class Runner
    DAY=24*60*60
    def initialize(basepath: "/mnt/data",
                   configpath: "/mnt/config",
                   logger: ,
                   days: 7,
                   dns_provider:,
                   test:
                  )
      @basepath=Pathname.new(basepath)
      @configpath=Pathname.new(configpath)
      @logger=logger
      @config=Config.load(@configpath.join("domains.json"))
      @min_valid_after=Time.now+days*DAY
      @dns_provider=dns_provider
      @test_only = test
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
        suggestion=deployment.suggest(min_valid_after: @min_valid_after)
        @logger.info("#{deployment.name.ljust(30)}..........#{suggestion}")
        certer=Certer.new(certificate(deployment.cert_name),
                     basepath: @basepath,
                     logger: @logger,
                     dns_provider: @dns_provider)
                     
        if @test_only
          puts "TEST ONLY, would: #{suggestion}"
        else  
          case suggestion
          when :deploy
            deployment.deploy!
          when :issue
            @logger.debug("Issuing Cert: #{deployment.name}:#{deployment.cert_name}")
            certer.issue!
            deployment.deploy!
          when :renew
            @logger.debug("Renewing Cert: #{deployment.name}:#{deployment.cert_name}")
            certer.renew!
            deployment.deploy!
          end  
        end
      end
    end

  end # Runner

    def self.run(*args)
      args[0][:logger].info("Starting Certer with args: #{args[0]}")
      Runner.new(*args).run
    end
end

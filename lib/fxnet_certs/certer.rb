module FxnetCerts
  class Certer
    ACME="/root/.acme.sh/acme.sh"

    attr_reader :cert
    def initialize(cert,
                   test: false,
                   dns_provider:,
                   config:,
                   basepath:,
                   configpath:,
                   logger: Logger.new(STDOUT))
      @test=test
      @cert=cert
      @logger=logger
      @basepath=basepath
      @configpath=configpath
      @config=config
      @errors=[]
      @dns_provider=dns_provider
    end

    def acme_args
      args=[
        domain_flags,
        "--cert-home  #{@basepath.join("certs",cert.name)}",
        "--config-home #{@basepath.join("config",cert.name)}",
        "--debug 2",
        "--force",
#        "--register-account", 
        "-m #{@config.cert(cert.name).issuer}"
      ].flatten
      if domain_alias = @config.cert(cert.name).domain_alias
        args = args.concat(
          ["--domain-alias",
          domain_alias,
          ]
        )  
      end
      args
    end

    def issue!
      @logger.info("Issuing new cert: #{cert.name}")
      cmd=[ACME,
           "--issue",
           "--dns #{@dns_provider}",
           acme_args,
          ].flatten

      cmd << "--test" if test?

      cmd=cmd.flatten.join(' ')
      if run(cmd)
        cert.generate_fullchain
      else
        @errors << { reason: "issue_failed"}
      end
      self
    end

    def renew!
      @logger.info("Renewing new cert: #{cert.name}")
      cmd=[ACME,
           "--renew",
           "--force",
           acme_args,
          ].flatten

      cmd << "--test" if test?

      cmd=cmd.flatten.join(' ')
      if run(cmd)
        cert.generate_fullchain
      else
        @errors << { reason: "issue_failed"}
      end

    end

    private

    def run(cmd)
      @logger.debug("running: #{cmd}")
      if test?
        true
      else
        system(cmd)
      end
    end

    def test?
      !!@test
    end

    def domain_flags
      cert.fqdns.map do |fqdn| "-d #{fqdn}" end.join(" ")
    end
  end
end

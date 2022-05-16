module FxnetCerts
  class Certer
    ACME="/root/.acme.sh/acme.sh"

    attr_reader :cert
    def initialize(cert,
                   test: true,
                   dns_provider:,
                   logger: Logger.new(STDOUT))
      @test=test
      @cert=cert
      @logger=logger
      @errors=[]
      @dns_provider=dns_provider
    end

    def acme_args
      [
        domain_flags,
        "--cert-home  /data/certs/#{cert.name}",
        "--config-home /data/config",
#        "--debug",
        "--force",
#        "--register-account", 
        "-m peter.schrammel@gmx.de"
#        "--challenge-alias",
#        "dev.fixingthe.net",
#        "--domain-alias",
#        "dev.fixingthe.net"
      ].flatten
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

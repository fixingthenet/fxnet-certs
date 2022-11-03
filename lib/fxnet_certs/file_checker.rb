module FxnetCerts
  class FileChecker
    def initialize(test, logger: Logger.new(STDOUT))
      @filename=test.filename
      @logger=logger
      check
    end

    def valid_domains?(fqdns)
      return false unless @cert
      result=true
      fqdns.each do |domain|
        if OpenSSL::SSL.verify_certificate_identity(@cert, domain)
          @logger.debug("HTTPS Checking domain: ok #{@filename} #{domain} ")
        else
          result = false
          @logger.debug("HTTPS Checking domain: failed #{@filename} #{domain}")
        end
      end
      result
    end

    def valid_after?(min_valid_after)
      return false unless @cert
      result = true
#      @peer_cert_chain.each do |cert|
       cert = @cert
        left=((cert.not_after - min_valid_after).to_f/(24*60*60))
        if cert.not_after > min_valid_after
          @logger.debug("HTTPS Checking days: ok #{@host}:#{@port} #{left}")
        else
          @logger.debug("HTTPS Checking days: failed #{@host}:#{@port} #{left}")
          result=false
        end
#      end
      result
    end

    private

    def check
      begin
        content=File.read(@filename)
        cert=content.match(/-----BEGIN CERTIFICATE-----\n(.*)-----END CERTIFICATE-----/m)[0]
        @cert=OpenSSL::X509::Certificate.new(cert)
      rescue
        @logger.debug("No crtificate file to check found at: #{@filename}, #{$!.message}")
      end  
    end
  end
end

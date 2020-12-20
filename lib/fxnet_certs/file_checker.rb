require 'aws-sdk'

module FxnetCerts
  class FileChecker
    def initialize(test, logger: Logger.new(STDOUT))
      @filename=test.filename
      @logger=logger
      check
    end

    def valid_domains?(fqdns)
      result=true
      fqdns.each do |domain|
        if OpenSSL::SSL.verify_certificate_identity(@cert, domain)
          @logger.debug("HTTPS Checking domain: ok #{@filename} #{domain} }")
        else
          result = false
          @logger.debug("HTTPS Checking domain: failed #{@filename} #{domain} }")
        end
      end
      result
    end

    def valid_after?(min_valid_after)
      result = true
#      @peer_cert_chain.each do |cert|
       cert = @cert
        left=((cert.not_after - min_valid_after).to_f/(24*60*60))
        if cert.not_after > min_valid_after
          @logger.debug("HTTPS Checking days: ok #{@host}:#{@port} #{left} }")
        else
          @logger.debug("HTTPS Checking days: failed #{@host}:#{@port} #{left} }")
          result=false
        end
#      end
      result
    end

    private

    def check
      @cert=OpenSSL::X509::Certificate.new(File.read(@filename))
    end
  end
end

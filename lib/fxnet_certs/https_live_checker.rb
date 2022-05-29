
# needs host and port (443 is default)
module FxnetCerts
  class HTTPSLiveChecker
    def initialize(test, logger: Logger.new(STDOUT))
      @host=test.host
      @port=test.port || 443
      @logger=logger
      check
    end

    def valid_domains?(fqdns)
      result=true
      fqdns.each do |domain|
        if OpenSSL::SSL.verify_certificate_identity(@peer_cert, domain)
          @logger.debug("HTTPS Checking domain: ok #{@host}:#{@port} #{domain}")
        else
          result = false
          @logger.debug("HTTPS Checking domain: failed #{@host}:#{@port} #{domain}")
        end
      end
      result
    end

    def valid_after?(min_valid_after)
      result=true
      @peer_cert_chain.each do |cert|
        left=((cert.not_after - min_valid_after).to_f/(24*60*60))
        if cert.not_after > min_valid_after
          @logger.debug("HTTPS Checking days: ok #{@host}:#{@port} #{left}")
        else
          @logger.debug("HTTPS Checking days: failed #{@host}:#{@port} #{left}")
          result=false
        end
      end
      result
    end

    private

    def check
      @logger.debug("checking #{@host}:#{@port}")
      tcp_sock = TCPSocket.new(@host, @port)
      ctx = OpenSSL::SSL::SSLContext.new
      ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
      ssl_sock = OpenSSL::SSL::SSLSocket.new(tcp_sock, ctx)
      ssl_sock.sync_close = true
      ssl_sock.connect
      @peer_cert=ssl_sock.peer_cert
      @peer_cert_chain=ssl_sock.peer_cert_chain
      ssl_sock.close
    end
  end
end

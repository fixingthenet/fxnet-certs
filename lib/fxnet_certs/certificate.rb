require 'pathname'
require 'openssl'
require 'fileutils'


module FxnetCerts
  class Certificate
    attr_reader :name, :domains, :cert
    def initialize(name, domains, basepath, logger: Logger.new(STDOUT))
      @name=name
      @domains=domains
      @basepath=Pathname.new(basepath)
      @logger=logger
      ensure_cert_path
    end

    def generate_fullchain
      @logger.debug("Fullchain at: #{fullchain_path}")
      content= full_body
      changed=false
      if File.exist?(fullchain_path)
        backup=File.read(fullchain_path)
        File.write("#{fullchain_path}.old",backup)
        @changed= (backup !=content)
      else
        @changed=true
      end
      File.write(fullchain_path,content)
    end

    def versioned_name
      "#{@name}-#{version}"
    end

    def version
      Digest::MD5.hexdigest(File.read(fullchain_path))
    end

    def cert
      OpenSSL::X509::Certificate.new(File.read(fullchain_path))
    end

    def valid_after?(min_valid_after)
      cert.not_after > min_valid_after
    end

    def exist?
      !!cert_body
    end

    def fqdns
      domains.map(&:fqdn)
    end

    def main_domain
      domains[0].fqdn
    end

    def cert_path
      @basepath.join(name,main_domain)
    end

    def fullchain_path
      "#{cert_path}/fullchain.full"
    end

    def full_body
     "#{cert_body}\n#{ca_body}\n#{private_key_body}"
    end
    
    def cert_body
      File.read("#{cert_path}/#{main_domain}.cer") rescue nil
    end

    def private_key_body
      File.read("#{cert_path}/#{main_domain}.key") rescue nil
    end

    def ca_body
      File.read("#{cert_path}/ca.cer") rescue nil
    end
    
    def ensure_cert_path
      FileUtils.mkdir_p(cert_path)
    end  
  end
end

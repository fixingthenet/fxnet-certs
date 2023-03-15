require 'pathname'
require 'openssl'
require 'fileutils'


# This needs a shared filesystem where the keys and all artefacts are stored
# TODO: be independent of a filesystem (abstract it, so we could store these things in s3, or retrieve live from a servier)

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
      Digest::MD5.hexdigest(full_body)
    end

    def cert
      OpenSSL::X509::Certificate.new(full_body)
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
      @basepath.join(name,main_domain+'_ecc')
    end

    def fullchain_path
      cert_path.join("fullchain.full")
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

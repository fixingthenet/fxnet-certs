#!/usr/bin/env ruby

# envs:
# DNS_PROVIDER  (dns_aws)
# see: https://github.com/Neilpang/acme.sh/blob/master/dnsapi/README.md
# AWS_SDK
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY




#file looks like:
# {
#   certs: [
#      {name: "my_example",
#       test: { host: "ssltest.example.com", port: "443"},
#       installs: [ {type: 'aws-elb-classic', elbs: [{name_prefix: "example_wildcard"}] }]
#        domains: [
#         { fqdn: "example.com" },
#         { fqdn: "*.example.com" },
#        ]
#      },
# ..next domain
# ],
#  next cert to create
# }

require 'json'
require 'aws-sdk'
require 'hashie'


# see: http://mathish.com/2011/01/14/openssl-in-ruby.html
class SSLChecker
  def self.check(*args)
    new(*args).check
  end

  DAY=24*60*60

  attr_reader :errors
  attr_reader :suggest
  attr_reader :local_cert

  def initialize(host,
                 port,
                 domains,
                 fullchain_path,
                 min_valid_after: Time.now+7*DAY,
                 logger: Logger.new(STDOUT)
                )
    @host=host
    @port=port
    @domains=domains
    @errors=[]
    @min_valid_after=min_valid_after
    @logger=logger
    @fullchain_path=fullchain_path
  end

  def version
    Digest::MD5.hexdigest(File.read(@fullchain_path))
  end

  def check
    if issue_check
      deployment_check
    end
    self
  end

  def valid?
    @errors.empty?
  end

  def domain_missmatch_error?
    @domain_missmatch_error
  end

  def outdated_error?
    @outdated_error
  end

  def issue_check
    if File.exist?(@fullchain_path)
      @local_cert=OpenSSL::X509::Certificate.new(File.read(@fullchain_path))
      if local_cert.not_after > @min_valid_after
        @logger.info("Local check ok: #{@fullchain_path}")
      else
        @suggest=:renew
        log={reason: "local_not_after",
             subject: local_cert.subject.to_s,
             not_after: local_cert.not_after}
        @logger.warn("Local Check failed: #{log.inspect}")
        errors << log
      end
      #TBD: check domains!!!!!
    else
      @suggest=:issue
      log={ reason: "never_issued"}
      @logger.warn(log.inspect)
      errors << log
    end
    valid?
  end

  def deployment_check
    tcp_sock = TCPSocket.new(@host, @port)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_NONE
    ssl_sock = OpenSSL::SSL::SSLSocket.new(tcp_sock, ctx)
    ssl_sock.sync_close = true
    ssl_sock.connect
    @domains.each do |domain|
      begin
        ssl_sock.post_connection_check(domain)
        @logger.info("domain: #{@host}:#{@port} #{domain} ok")
      rescue
        @suggest=:deploy # we assume that domain checks were done on local certs
        log={reason: "domain", domain: domain}
        @domain_missmatch_error=true
        @errors << log
        @logger.warn(log.inspect)
      end
    end
    ssl_sock.peer_cert_chain.each do |cert|
      left=cert.not_after - @min_valid_after
      if cert.not_after > @min_valid_after
        @logger.info("days_left ok: #{@host}:#{@port}:#{cert.subject} #{left/DAY}")
      else
        @suggest=:deploy # we assume that time checks were done on local certs already
        @outdated_error=true
        log={reason: "not_after",
             subject: cert.subject,
             not_after: cert.not_after}
        @errors << log
        @logger.warn("days_left failed: #{log.inspect}")
      end
    end
    ssl_sock.close
    valid?
  end

end



class Config
  def self.load(filename)
    new(JSON.parse(File.read(filename)))
  end

  def initialize(hash)
    @config=Hashie::Mash.new(hash)
  end

  def method_missing(m,*args, &block)
    @config.send(m,*args)
  end
end

#class Cert
#  attr_reader :ca, :cert, :private_key

#  def initialize(ca,cert,private_key)
#    @ca=ca
#    @cert=cert
#    @private_key=private_key
#  end

#  def not_after
#    ssl.not_after
#  end

#  private
#  def ssl
#    @ssl ||= OpenSSL::X509::Certificate.new("#{body}\n#{cert}\n#{private_key}")
#  end
#end

class Certer
  ACME="/root/.acme.sh/acme.sh"

  attr_reader :cert_config
  def initialize(cert_config, test: false, logger: Logger.new(STDOUT))
    @test=test
    @cert_config=cert_config
    @logger=logger
    @errors=[]
  end

  #def cert
  #  Cert.new(ca_body, cert_body, private_key_body)
  #end

  def valid?
    @errors.empty?
  end

  def main_domain
    cert_config.domains[0].fqdn
  end


  def acme_args
      domain_names=cert_config.domains.map do |domain| "-d #{domain.fqdn}" end.join(" ")
      [
      domain_names,
      "--cert-home  /data/certs/#{cert_config.name}",
      "--config-home /data/config",
      ].flatten

  end

  def issue!
      @logger.info("Issuing new cert: #{cert_config.name}")
      cmd=[ACME,
      "--issue",
      "--dns #{ENV["DNS_PROVIDER"]}",
      acme_args,
      ].flatten

      cmd << "--test" if test?

      cmd=cmd.flatten.join(' ')
      if run(cmd)
        write_fullchain
      else
        @errors << { reason: "issue_failed"}
      end
      self
  end

  def renew!
      @logger.info("Renewing new cert: #{cert_config.name}")
      cmd=[ACME,
           "--renew",
           "--force",
           acme_args,
          ].flatten

      cmd << "--test" if test?

      cmd=cmd.flatten.join(' ')
      if run(cmd)
        write_fullchain
      else
        @errors << { reason: "issue_failed"}
      end

  end

  def cert_path
    "/data/certs/#{cert_config.name}/#{main_domain}"
  end

  def cert_body
    File.read("#{cert_path}/#{main_domain}.cer")
  end

  def private_key_body
    File.read("#{cert_path}/#{main_domain}.key")
  end
  def ca_body
    File.read("#{cert_path}/ca.cer")
  end
  def fullchain_path
    "#{cert_path}/fullchain.full"
  end
  private
  def write_fullchain
    @logger.debug("Fullchain at: #{fullchain_path}")
    content="#{cert_body}\n#{ca_body}\n#{private_key_body}"

    @changed=false
    if File.exist?(fullchain_path)
      backup=File.read(fullchain_path)
      File.write("#{fullchain_path}.old",backup)
      @changed= (backup !=content)
    else
      @changed=true
    end
    File.write(fullchain_path,content)
  end

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

end

class AWSELBClassic
  def self.deploy(*args)
    new(*args).deploy!
  end

  attr_reader :cert_name

  def initialize(cert_name, certer, deployment_config, logger: Logger.new(STDOUT))
    @cert_name=cert_name
    @certer=certer
    @deployment_config=deployment_config
    @logger=logger
  end

  def deploy!
    iam_cert=upload_server_cert
    @logger.info("Cert Deployment: result #{iam_cert.arn}")
    set_server_cert(iam_cert.arn)
    self
  end

  private
  def upload_server_cert
    iam=Aws::IAM::Client.new(region: 'eu-west-1')
    certs=iam.list_server_certificates({max_items: 1000}).server_certificate_metadata_list.select { |cm| cm.server_certificate_name == cert_name}
    unless certs.empty?
      @logger.info("Cert Deployment: hold #{cert_name}")
      certs[0]
    else
      @logger.info("Cert Deployment: upload #{cert_name}")
      result=iam.upload_server_certificate({
                                      server_certificate_name: cert_name,
                                      certificate_body: @certer.cert_body,
                                      private_key: @certer.private_key_body,
                                      certificate_chain: @certer.ca_body
                                           })
      result.server_certificate_metadata
    end

  end
  def set_server_cert(iam_arn)
    client=Aws::ElasticLoadBalancing::Client.new(region: 'eu-west-1')
    balancer_name=@deployment_config.target.balancer_name
    lb=client.
         describe_load_balancers(load_balancer_names: [balancer_name]).
         load_balancer_descriptions[0]

    if lb
      puts lb.inspect
      listeners=lb.listener_descriptions.select { |ld| ld.listener.protocol == 'HTTPS'}
      if listeners.empty?
        @logger.error("Set ELB cert: no HTTPS listener for #{balancer_name}")
      else
        listener=listeners[0].listener
        if listener.ssl_certificate_id == iam_arn
          @logger.error("Set ELB cert: hold cert for #{listener.instance_protocol} #{balancer_name}")
        else
          resp = client.
                   set_load_balancer_listener_ssl_certificate({
                                                                load_balancer_name: balancer_name,
                                                                load_balancer_port: listener.load_balancer_port,
                                                                ssl_certificate_id: iam_arn
                                                                   })
          @logger.info("Set ELB cert: set  #{balancer_name} #{listener.load_balancer_port} ")
        end
      end
    else
      @logger.error("Set ELB cert: no such lb #{balancer_name}")
    end
  end
end

logger=Logger.new(STDOUT)
STDOUT.sync=true

config=Config.load("/data/domains.json")

if ARGV[0]=='run'

  needs_cert=[]
  config.certs.each do |cert_config|
    domains=cert_config.domains.map do |dom| dom.fqdn end
    certer=Certer.new(cert_config,
                      test: ARGV[1]=='test',
                      logger: logger)

    ssl_checker=SSLChecker.check(cert_config.test.host,
                                     cert_config.test.port,
                                     domains,
                                     certer.fullchain_path,
                                     logger: logger
                                    )
    if ssl_checker.valid?
      logger.info("Cert ok: #{cert_config.name}")
    else
      logger.warn("Cert errors: #{ssl_checker.errors.inspect}")
      needs_cert << [cert_config,ssl_checker,certer]
    end
  end

  needs_cert.each do |cert_config,ssl_checker,certer|

    case ssl_checker.suggest
    when :deploy
      logger.info("Deploying Cert: #{cert_config.inspect}")
      deps=config.deployments.select { |deployment|  deployment.cert == cert_config.name }
      deps.each do |dep|
        logger.info("Deploying Cert: #{dep.cert} on #{dep.target.inspect}")
        case dep.target.type
        when "aws-elb-classic"
          AWSELBClassic.deploy("#{cert_config.name}-#{ssl_checker.version}",
                               certer,
                               dep,
                               logger: logger)
        end
      end
    when :issue
      logger.info("Issuing Cert: #{cert_config.inspect}")
      #certer.issue!
    #upload
    when :renew
      logger.info("Renewing Cert: #{cert_config.inspect}")
      #certer.renew!
      #upload
    end
  end
end

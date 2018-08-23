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


# see: http://mathish.com/2011/01/14/openssl-in-ruby.html


class SSLChecker
  def self.check(*args)
    new(*args).check
  end

  DAY=24*60*60

  attr_reader :errors
  def initialize(host,port, domains, min_valid_after: Time.now+4*DAY)
    @host=host
    @port=port
    @domains=domains
    @errors=[]
    @min_valid_after=min_valid_after
    @logger=Logger.new(STDOUT)
  end

  def valid?
    @errors.empty?
  end

  def check
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
        log={reason: "domain", domain: domain}
        @errors << log
        @logger.warn(log.inspect)
      end
    end
    ssl_sock.peer_cert_chain.each do |cert|
      left=cert.not_after - @min_valid_after
      if cert.not_after > @min_valid_after
        @logger.info("days_left: #{@host}:#{@port}:#{cert.subject} #{left/DAY}  ok")
      else
        log={reason: "not_after",
             subject: cert.subject,
             not_after: cert.not_after}
        @errors << log
        @logger.warn(log)
      end
    end
    ssl_sock.close
    self
  end

end

#client=Aws::ElasticLoadBalancing::Client.new(region: 'eu-west-1')
#lb=client.describe_load_balancers(load_balancer_names: ["staging-metoda-lb-star-v2"]).load_balancer_descriptions[0]
#resp = client.set_load_balancer_listener_ssl_certificate({
#load_balancer_name: "my-load-balancer",
#load_balancer_port: 443,
#ssl_certificate_id: "arn:aws:iam::123456789012:server-certificate/new-server-cert",
#})

#iam.upload_server_certificate({ server_certificate_name: "pschrammel-test", certificate_body: File.read("/data/certs/metoda_star/metoda.com/metoda.com.cer"), private_key: File.read("/data/certs/metoda_star/metoda.com/metoda.com.key"),certificate_chain: File.read("/data/certs/metoda_star/metoda.com/ca.cer")})
#iam=Aws::IAM::Client.new(region: 'eu-west-1')


class Config
  def self.load(filename)
    JSON.parse(File.read(filename))
  end

  def initialize(hash)
    @config=hash
  end

  def[](key)
    @config[key]
  end
end

class Certer
  ACME="/root/.acme.sh/acme.sh"

  def ensure
    config["certs"].each do |cert|
      if File.exist?(cert_path(cert))
        renew(cert)
      else
        issue(cert)
      end
    end
  end

  def cert_path(cert)
    "/data/certs/#{cert['name']}/#{main_domain(cert)}"
  end

  def main_domain(cert)
    cert["domains"][0]["fqdn"]
  end

  def acme_args(cert)
      domain_names=cert["domains"].map do |domain| "-d #{domain["fqdn"]}" end.join(" ")
      [
      domain_names,
      "--cert-home  /data/certs/#{cert['name']}",
      "--config-home /data/config",
      ].flatten

  end
  def issue(cert)
      cmd=[ACME,
      "--issue",
      "--dns #{ENV["DNS_PROVIDER"]}",
      acme_args(cert),
      ].flatten

      cmd << "--test" if test?

      cmd=cmd.flatten.join(' ')
      run(cmd)
      write_fullchain(cert)
  end

  def renew(cert)
      cmd=[ACME,
      "--renew",
      acme_args(cert),
      ].flatten

      cmd << "--test" if test?

      cmd=cmd.flatten.join(' ')
      run(cmd)
      write_fullchain(cert)
  end

  def write_fullchain(cert)
    chain=File.read("#{cert_path(cert)}/fullchain.cer")
    private_key=File.read("#{cert_path(cert)}/#{main_domain(cert)}.key")
    outfile="#{cert_path(cert)}/fullchain.full"
    puts "writing: #{outfile}"
    content="#{chain}\n#{private_key}"

    changed=false
    if File.exist?(outfile)
      backup=File.read(outfile)
      File.write("#{outfile}.old",backup)
      changed= (backup !=content)
    else
      changed=true
    end

    File.write(outfile,content)
    if changed
      puts "upload to aws"
    end
  end

  private
  def config
    @config ||= JSON.parse(File.read("/data/domains.json"))
  end

  def run(cmd)
    puts "running: #{cmd}"
    system(cmd) unless test?
  end

  def test?
    ARGV[0]=='test'
  end

end

#certer=Certer.new
#certer.ensure
config=Config.load("/data/domains.json")
config["certs"].each do |cert|
  domains=cert["domains"].map do |dom| dom["fqdn"] end
  ssl_checker=SSLChecker.check(cert["test"]["host"],
                               cert["test"]["port"],
                               domains)
  unless ssl_checker.valid?
    STDERR.inspect ssl_checker.errors
  end
end

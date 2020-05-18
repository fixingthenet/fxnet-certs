#!/usr/bin/env ruby

# currently supporting only one cert for multiple domains
# envs:
# DNS_PROVIDER
# https://github.com/Neilpang/acme.sh/blob/master/dnsapi/README.md

#file looks like:
# { domains: [
#     { fqdn: "www.example.com" }
#   ]
# }

require 'json'
ACME="/root/.acme.sh/acme.sh"

def run(cmd)
  puts "running: #{cmd}"
  system(cmd)
end
  
def issue
  domains=JSON.parse(File.read("/data/domains.json"))
  domain_names=domains["domains"].map do |domain| "-d #{domain["fqdn"]}" end.join(" ")
  cmd=[ACME,
  "--issue",
  " --dns #{ENV["DNS_PROVIDER"]}",
  domain_names,
  "--cert-home  /data/certs",
  "--config-home /data/config",
  "--fullchain-file /data/fullchain.pem"
  ].flatten.join(' ')
  run(cmd)
end

def renew
  cmd="#{ACME} --renew-all"
  run(cmd)
end

case ARGV[0]
when 'issue'
  issue
when 'renew'
  unless File.exist?('/data/certs')
    issue
  end  
  renew
else
  STDERR.puts("error: unknown command '#{ARGV[0]}'")
  exit 1
end

  

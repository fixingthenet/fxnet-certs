#!/usr/bin/env ruby

# envs:
# DNS_PROVIDER  (dns_aws)
# see: https://github.com/Neilpang/acme.sh/blob/master/dnsapi/README.md
# AWS_REGION
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
#

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

$: << File.expand_path(File.join(__dir__,'../lib'))

require 'fxnet_certs'
logger=Logger.new(STDOUT)
logger.level=ENV["LOGGER_LEVEL"] || 'error'

FxnetCerts.run(basepath: "/data",
               logger: logger,
               days: (ENV["DAYS"] || 7).to_i,
               dns_provider: ENV["DNS_PROVIDER"]
              )

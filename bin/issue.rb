#!/usr/bin/env ruby

# envs:
# DNS_PROVIDER  (dns_aws)
# see: https://github.com/Neilpang/acme.sh/blob/master/dnsapi/README.md
# AWS_REGION
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

require 'byebug'
require 'aws-sdk'

$: << File.expand_path(File.join(__dir__,'../lib'))

require 'fxnet_certs'
logger=Logger.new(STDOUT)
logger.level=ENV["LOGGER_LEVEL"] || 'error'

FxnetCerts.run(basepath: "/code/data",
               configpath: "/mnt/config",
               logger: logger,
               days: (ENV["DAYS"] || 7).to_i,
               dns_provider: ENV["DNS_PROVIDER"]
              )

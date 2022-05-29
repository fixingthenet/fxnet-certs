#!/usr/bin/env ruby

# envs:
# DNS_PROVIDER  (dns_aws)
# see: https://github.com/Neilpang/acme.sh/blob/master/dnsapi/README.md
# AWS_REGION
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

require 'byebug'
require 'aws-sdk'
require 'optparse'

$: << File.expand_path(File.join(__dir__,'../lib'))

require 'fxnet_certs'
# setting up the logger
STDOUT.sync=true
logger=Logger.new(STDOUT)
logger.level=ENV["LOGGER_LEVEL"] || 'error'

# parsing options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-t", "--test", "Run only tests, nor rnewe, no issue") do |v|
    options[:test] = v
  end
  opts.on("-f", "--front MINUTES", "don't stop just sleep ") do |v|
    options[:front] = v.to_i * 60
  end
end.parse!

if options[:front] 
 while true do
  FxnetCerts.run(basepath: "/code/data",
               configpath: "/mnt/config",
               logger: logger,
               days: (ENV["DAYS"] || 7).to_i,
               dns_provider: ENV["DNS_PROVIDER"],
               test: options[:test]
              )
   sleep options[:front]
  end
else
FxnetCerts.run(basepath: "/code/data",
               configpath: "/mnt/config",
               logger: logger,
               days: (ENV["DAYS"] || 7).to_i,
               dns_provider: ENV["DNS_PROVIDER"],
               test: options[:test]
              )

end

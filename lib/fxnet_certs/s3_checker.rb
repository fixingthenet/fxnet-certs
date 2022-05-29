require 'aws-sdk'
require 'tempfile'

module FxnetCerts
  class S3Checker < FileChecker
    def initialize(test, logger: Logger.new(STDOUT))
      @test=test
      @logger=logger
      @filename = Tempfile.new('fxnet-cert-s3').path
      download
      super(OpenStruct.new(filename: @filename), logger: logger)
    end

    private
    
    def download
      s3_client=Aws::S3::Client.new
      begin
        resp=s3_client.get_object( bucket: @test.bucket, key: @test.path)
        @logger.debug("Writing to: #{@filename}")
        @logger.debug("Content:\n #{resp.body.read}")
        @logger.debug("bucket: #{@test.bucket} #{@test.path}")
        resp.body.rewind
        File.write(@filename, resp.body.read)
      rescue Aws::S3::Errors::NoSuchKey
        @logger.debug("S3: no such path/key")
        File.write(@filename, '')
      end
    end
  end
end

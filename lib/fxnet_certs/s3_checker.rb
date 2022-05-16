require 'aws-sdk'
require 'tempfile'

module FxnetCerts
  class S3Checker < FileChecker
    def initialize(test, logger: Logger.new(STDOUT))
      @test=test
      @logger=logger
      download
      super(OpenStruct.new(filename: @filename), logger: logger)
    end

    private
    
    def download
      s3_client=Aws::S3::Client.new
      @filename = Tempfile.new('fxnet-cert-s3').path
      begin
        resp=s3_client.get_object( bucket: @test.bucket, key: @test.path)
        File.write(@filename, resp.body.read)
      rescue Aws::S3::Errors::NoSuchKey
        File.write(@filename, '')
      end
    end
  end
end

# coding: utf-8
require 'pp'
module FxnetCerts
  class AWSELBDeployer

    def self.deploy(*args)
      new(*args).deploy!
    end

    def initialize(deployment:,
                   cert:,
                   target:,
                   logger: Logger.new(STDOUT))
      @cert=cert
      @deployment=deployment
      @balancer_name=target.balancer_name
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
      iam=Aws::IAM::Client.new
      certs=iam.list_server_certificates({max_items: 1000}).server_certificate_metadata_list.select { |cm| cm.server_certificate_name == @cert.versioned_name}
      unless certs.empty?
        @logger.info("Cert Deployment: hold #{@cert.versioned_name} on #{@balancer_name}")
        certs[0]
      else
        @logger.info("Cert Deployment: upload #{@cert.versioned_name} on #{@balancer_name}")
        result=iam.upload_server_certificate({
                                               server_certificate_name: @cert.versioned_name,
                                               certificate_body: @cert.cert_body,
                                               private_key: @cert.private_key_body,
                                               certificate_chain: @cert.ca_body
                                             })
        result.server_certificate_metadata
      end

    end
    def set_server_cert(iam_arn)
      client=Aws::ElasticLoadBalancing::Client.new
      begin
      lb=client.
           describe_load_balancers(load_balancer_names: [@balancer_name]).
           load_balancer_descriptions[0]
      rescue Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound
        lb=nil
      end
      if lb
        listeners=lb.listener_descriptions.select { |ld| ld.listener.protocol == 'HTTPS'}
        if listeners.empty?
          @logger.error("Set ELB cert: no HTTPS listener for #{@balancer_name}")
        else
          listener=listeners[0].listener
          if listener.ssl_certificate_id == iam_arn
            @logger.error("Set ELB cert: hold cert for #{listener.instance_protocol} on #{@balancer_name}")
          else
            resp = client.
                     set_load_balancer_listener_ssl_certificate({
                                                                  load_balancer_name: @balancer_name,
                                                                  load_balancer_port: listener.load_balancer_port,
                                                                  ssl_certificate_id: iam_arn
                                                                }) #if false #true
            @logger.info("Set ELB cert: set  #{@balancer_name} #{listener.load_balancer_port} on #{@balancer_name}")
          end
        end
      else
        @logger.error("Set ELB cert: no such lb #{@balancer_name}")
      end
    end
  end
end

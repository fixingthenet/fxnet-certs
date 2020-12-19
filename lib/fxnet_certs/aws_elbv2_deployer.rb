# coding: utf-8
require 'fxnet_certs/aws_elb_deployer'

module FxnetCerts
  class AWSELBV2Deployer < AWSELBDeployer

    def set_server_cert(iam_arn)
      client=Aws::ElasticLoadBalancingV2::Client.new
      lb=client.
           describe_load_balancers(names: [@balancer_name]).
           load_balancers[0]

      if lb
        listeners=client.describe_listeners({ load_balancer_arn: lb.load_balancer_arn}).listeners
        listeners=listeners.select { |ls| ls.protocol == 'HTTPS'}
        if listeners.empty?
          @logger.error("Set ELB cert: no HTTPS listener for #{@balancer_name}")
        else
          listener=listeners[0]
          if listener.certificates[0].certificate_arn == iam_arn
            @logger.error("Set ELB cert: hold cert for #{listener.instance_protocol} on #{@balancer_name}")
          else
            resp = client.
                     modify_listener({
                                       listener_arn: listener.listener_arn,
                                       certificates: [
                                         { certificate_arn: iam_arn }
                                       ]
                                     })
            @logger.info("Set ELB cert: set  #{@balancer_name} #{listener.port} on #{@balancer_name}")
          end
        end
      else
        @logger.error("Set ELB cert: no such lb #{@balancer_name}")
      end
    end
  end
end

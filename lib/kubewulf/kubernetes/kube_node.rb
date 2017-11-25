module Kubewulf
    class KubeNode
        attr_accessor :name,
                      :hostname,
                      :private_ipv4,
                      :public_ipv4,
                      :machine_type,
                      :pod_cidr,
                      :region, 
                      :zone,
                      :conditions

        def initialize(options = {})
            if options[:kubeclient_data]
                construct_from_kubeclient(options[:kubeclient_data])
            end
        end

        def construct_from_kubeclient(data)
            @name = data.metadata.name
            @machine_type = data.metadata.labels['beta.kubernetes.io/instance-type']
            @region = data.metadata.labels['failure-domain.beta.kubernetes.io/region']
            @zone = data.metadata.labels['failure-domain.beta.kubernetes.io/zone']
            @pod_cidr = data.spec.podCIDR

            data.status.addresses.each do |a|
                case a['type']
                    when 'ExternalIP'
                        @public_ipv4 = a['address']
                    when 'InternalIP'
                        @private_ipv4 = a['address']
                    when 'Hostname'
                        @hostname = a['address']
                end
            end
            @conditions = {}
            data.status.conditions.collect{|c| c.to_h}.each do |c|
                @conditions[c[:type]] = c
            end
        end

    end # End Class
end # End Module

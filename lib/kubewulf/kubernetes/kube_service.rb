module Kubewulf
    class KubeService
        attr_accessor :name,
                      :site,
                      :kubernetes_service_type,
                      :private_ipv4,
                      :public_ipv4,
                      :routing_tag,
                      :ports,
                      :version,
                      :app_name

        def initialize(options = {})
            @log = Kubewulf::Logger
            if options[:kubeclient_data]
                construct_from_kubeclient(options[:kubeclient_data])
            end
        end

        def diffable_hash
            return { name: @name,
                     ports: @ports,
                     app_name: @app_name }
        end

        def construct_from_kubeclient(data)
            @name = data.metadata.name
            @site = data.metadata.namespace
            @private_ipv4 = data.spec.clusterIP 
            @public_ipv4 = data.spec.loadBalancerIP 
            @kubernetes_service_type = data.spec.type
            @ports = {}
            if data.spec.ports
                data.spec.ports.each do |p| 
                    if p.name.nil? 
                        @log.debug "Found service with no name, ignoring..."
                        next
                    end
                    @ports[p.name.to_sym] = { name: p.name,
                                                protocol: p.protocol, 
                                                node_port: p.nodePort,
                                                service_port: p.port, 
                                                container_port: p.targetPort } 
                end
            end
            @version = data.metadata.labels.version if data.metadata.labels
            @app_name = data.metadata.labels.app if data.metadata.labels
            @routing_tag = data.metadata.labels.routing_tag if data.metadata.labels
        end

    end # End Class
end # End Module

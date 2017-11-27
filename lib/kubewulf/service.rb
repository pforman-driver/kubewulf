module Kubewulf
    class Service
        attr_accessor :name,
                      :app_name,
                      :kubernetes_service_type,
                      :ports,
                      :public_ipv4,
                      :proxy_mode,
                      :version,
                      :routing_tag

        # ports: { name: "", service_port: "", container_port: "", node_port: "", protocol: ""} 
        def diffable_hash
            return { name: @name,
                     ports: @ports,
                     app_name: @app_name }
        end
        
        # Overriding name to raise exceptions for bad format
        # Must be /^[a-z][a-z0-9-]*[a-z0-9]$/
        def name=(value)
            if value.match /^[a-z][a-z0-9-]*[a-z0-9]$/
                @name = value
            else
                raise "Invalid service name '#{value}', must be /^[a-z][a-z0-9-]+[a-z0-9]$/" 
            end
        end

        def app_name
            return @name if @app_name.nil? 
        end

        def proxy_name
            return "#{app_name}-#{routing_tag}"
        end

        private

    end # End Class
end # End Module

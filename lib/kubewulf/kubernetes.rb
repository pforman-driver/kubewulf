# This class relies heavily on abonas's kubeclient gem. This may be something 
# for a refactor in the future, but also we are using base kubernetes objects:
# service, pod, config_map, node, secret
# This class also abstracts the objects to prevent impacting consumers of this class's
# methods
module Kubewulf

    require 'kubeclient'
    require 'kubewulf/kubernetes/kube_config_map'
    require 'kubewulf/kubernetes/kube_namespace'
    require 'kubewulf/kubernetes/kube_node'
    require 'kubewulf/kubernetes/kube_pod'
    require 'kubewulf/kubernetes/kube_secret'
    require 'kubewulf/kubernetes/kube_service'

    class Kubernetes
                     
        def initialize(options = {})
            @log = Kubewulf::Logger
            @client_mode = options[:client_mode] || "local"
            @refresh_interval = 60
        end

        def existing_config_maps
            if stale?(@config_maps)
                @config_maps = refresh_kubernetes_objects("config_maps")
            end
            return @config_maps[:objects]
        end

        def existing_pods
            if stale?(@pods)
                @pods = refresh_kubernetes_objects("pods")
            end
            return @pods[:objects]
        end

        def existing_secrets
            if stale?(@secrets)
                @secrets = refresh_kubernetes_objects("secrets")
            end
            return @secrets[:objects]
        end

        def existing_services
            if stale?(@services)
                @services = refresh_kubernetes_objects("services")
            end
            return @services[:objects]
        end

        def existing_nodes
            if stale?(@nodes)
                @nodes = refresh_kubernetes_objects("nodes")
            end
            return @nodes[:objects]
        end
    
        def existing_namespaces
            if stale?(@namespaces)
                @namespaces = refresh_kubernetes_objects("namespaces")
            end
            return @namespaces[:objects]
        end

        def set_site(site)
            rv = "no_change"
            if existing_namespaces.select{|n| n.name == site.name}.length == 0
                r = kubeclient_resource
                r.metadata = {}
                r.metadata.name = site.name
                client.create_namespace(r)
                rv = "created"
            end
            return rv
        rescue Exception => e
            @log.warn "Unable to create namespace: #{e}"
            return false
        end

        def set_service(service, site)
            rv = "no_change"
            tmp_ports = []
            r = kubeclient_resource
            r.spec = {}
            r.metadata = {}
            r.metadata.labels = {}
            r.spec.ports = []
            r.spec.selector = {}

            r.metadata.name = service.name
            r.metadata.namespace = site.name
            r.metadata.labels.app = service.name
            r.metadata.labels.routing_tag = service.routing_tag
            r.metadata.labels.proxy_mode = service.proxy_mode
            r.spec.selector.app = service.name
            r.spec.selector.routing_tag = service.routing_tag
            if site.data[:service_node_ports]
                site_node_port = site.data[:service_node_ports][service.name.to_sym]
                if site_node_port
                    @log.debug "Node port specified for site/service...."
                end
            end
            if site_node_port
                r.spec.type = "NodePort"
            end
            service.ports.each do |port_id, port_data|
                tmp_port =   { 'port' => port_data[:service_port],
                               'targetPort' => port_data[:container_port],
                               'name' => port_id.to_s,
                               'protocol' => port_data[:protocol] }
                if site_node_port 
                    node_port = site_node_port[port_id]
                    if node_port
                        tmp_port['nodePort'] = node_port
                    end
                end
                tmp_ports << tmp_port
            end
            r.spec.ports = tmp_ports
            
            # Find the existing kube service, and attempt to diff the configured service with the existing one
            existing_service = existing_services.select{|s| s.name == service.name && 
                                                            s.site == site.name }.first
            if existing_service.nil?
                @log.debug "creating..."
                client.create_service(r)
                rv = "created"
            elsif diff_service(existing_service, service, site_node_port)
                @log.debug "updating..."
                client.delete_service(service.name, site.name)
                client.create_service(r)
                rv = "updated"
            else
                rv = "no_change"
            end
            return rv
        rescue Exception => e
            @log.warn "Unable to create or update service: #{e}"
            raise e
            return false
        end

        def set_config_map(cm)
            rv = "no_change"

            # Configure kubeclient resource
            r = kubeclient_resource
            r.metadata = {}
            r.metadata.name = cm.name
            r.metadata.namespace = cm.site
            r.data = cm.data_hash

            # Find a deployed instance of the config map, create if nil, update if diff == true
            existing_config_map = existing_config_maps.select{|kcm| kcm.name == cm.name && 
                                                                    kcm.site == cm.site}.first
            if existing_config_map.nil? 
                client.create_config_map(r)       
                rv = "created"
            elsif diff_config_map(existing_config_map, cm)
                client.update_config_map(r)
                rv = "updated"
            else 
                rv = "no_change"
            end
            return rv
        rescue Exception => e
            @log.warn "Unable to create config_map: #{e}"
            return false
        end

        def set_secret(secret)
            rv = "no_change"

            # Configure kubeclient resource
            r = kubeclient_resource
            r.metadata = {}
            r.metadata.name = secret.name
            r.metadata.namespace = secret.site
            r.data = secret.data_hash_base64

            # Find a deployed instance of the secret, create if nil, update if diff == true
            existing_secret = existing_secrets.select{|ksecret| ksecret.name == secret.name && 
                                                                ksecret.site == secret.site}.first
            if existing_secret.nil?
                client.create_secret(r)
                rv = "created"
            elsif diff_secret(existing_secret, secret)
                client.update_secret(r)
                rv = "updated"
            else
                rv = "no_change"
            end
            return rv
        rescue Exception => e
            @log.warn "Unable to create secret: #{e}"
            return false
        end

        def client
            if @client.nil?
                @client = setup_client
            end
            return @client
        end

        private
        def diff_config_map(kube_cm, config_cm)
            return kube_cm.data_hash != config_cm.data_hash
        end

        def diff_secret(kube_secret, config_secret)
            return kube_secret.data_hash_raw != config_secret.data_hash_raw
        end

        def diff_port(config, existing, node_port)
            a = {}
            b = {}
            if node_port
                 a = { service_port: config[:service_port],
                       container_port: config[:container_port],
                       node_port: node_port,
                       protocol: config[:protocol] }
                 b = { service_port: existing[:service_port],
                       container_port: existing[:container_port],
                       node_port: existing[:node_port],
                       protocol: existing[:protocol] }
            else
                 a = { service_port: config[:service_port],
                       container_port: config[:container_port],
                       protocol: config[:protocol] }
                 b = { service_port: existing[:service_port],
                       container_port: existing[:container_port],
                       protocol: existing[:protocol] }
            end
            # @log.debug a.inspect
            # @log.debug b.inspect
            # @log.debug "diff?" + (a != b).to_s
            return a != b
        end

        def diff_service(kube_service, config_service, site_node_port)
            is_diff = []
            tmp_c = {name: config_service.name, 
                     version: config_service.version,
                     routing_tag: config_service.routing_tag,
                     app_name: config_service.app_name}
            tmp_k = {name: kube_service.name,
                     version: kube_service.version,
                     routing_tag: kube_service.routing_tag,
                     app_name: kube_service.app_name}
            if tmp_c != tmp_k
                @log.debug "Diff in common params"
                # @log.debug tmp_c.inspect
                # @log.debug tmp_k.inspect
                is_diff << true
            else
                config_service.ports.each do |port_name, port_data|
                    if site_node_port
                        is_diff << diff_port(port_data, kube_service.ports[port_name], site_node_port[port_name])
                    else
                        is_diff << diff_port(port_data, kube_service.ports[port_name], nil)
                    end
                        
                end
            end
            return is_diff.include?(true)
        end

        def kubeclient_resource
            Kubeclient::Resource.new
        end
   
        # The stale? method is intended to ensure we cache the objects, and only 
        # refresh on a configured window, helping to speed up interaction.  
        def stale?(object)
            if object.nil?
                return true
            elsif (Time.now.to_i - object[:updated_at].to_i) > @refresh_interval
                return true
            else
                return false
            end
        end

        # Builds a hash, containing an array of kube objects
        def refresh_kubernetes_objects(object_class)
            objects = {updated_at: 0, objects: []}
            objects_tmp = client.send("get_#{object_class}".to_sym)
            objects_tmp.each do |obj|
                objects[:objects] << construct_object(object_class, obj)
            end
            objects[:updated_at] = Time.now.to_i
            return objects
        end

        # This method maps a string representing the plural kubernetes object types, to 
        # the class for internally managing the kubernetes object.  
        def construct_object(object_class, data)
            object = case object_class
                when "nodes"
                    KubeNode.new(:kubeclient_data => data)
                when "services"
                    KubeService.new(:kubeclient_data => data)
                when "pods"
                    KubePod.new(:kubeclient_data => data)
                when "config_maps"
                    KubeConfigMap.new(:kubeclient_data => data)
                when "namespaces"
                    KubeNamespace.new(:kubeclient_data => data)
                when "secrets"
                    KubeSecret.new(:kubeclient_data => data)
            end
            return object
        end

        def setup_client
            client = nil
            if @client_mode == "local"
                client = Kubeclient::Client.new('http://localhost:8001/api/', 'v1')
            elsif ENV['KUBERNETES_SERVICE_HOST']
                ssl_options  = { ca_file: '/var/run/secrets/kubernetes.io/serviceaccount/ca.crt' }
                auth_options = { bearer_token_file: '/var/run/secrets/kubernetes.io/serviceaccount/token' }
                client = Kubeclient::Client.new( "https://#{ENV['KUBERNETES_SERVICE_HOST']}:#{ENV['KUBERNETES_PORT_443_TCP_PORT']}/api/", 
                                                 'v1',
                                                 auth_options: auth_options,
                                                 ssl_options: ssl_options )

            end
            return client
        end

    end # End Class
end # End Module

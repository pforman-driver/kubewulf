module Kubewulf
    class KubeConfigMap
        require 'yaml'

        attr_accessor :name,
                      :site,
                      :data

        def initialize(options = {})
            if options[:kubeclient_data]
                construct_from_kubeclient(options[:kubeclient_data])
            end
        end

        def construct_from_kubeclient(data)
            @name = data.metadata.name
            @site = data.metadata.namespace
            @data = JSON.parse(JSON.generate(data.data.to_h))
        end

        def data_hash
            @data
        end

        def to_yaml
            YAML.dump({"apiVersion" => "v1",
                       "kind" => "ConfigMap",
                       "metadata" => metadata_hash,
                       "data" => @data})    
        end

        private
        def metadata_hash
            return { "name" => @name, "namespace" => @site }
        end

    end # End Class
end # End Module

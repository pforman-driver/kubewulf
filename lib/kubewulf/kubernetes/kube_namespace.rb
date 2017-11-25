module Kubewulf
    class KubeNamespace
        require 'yaml'

        attr_accessor :name

        def initialize(options = {})
            if options[:kubeclient_data]
                construct_from_kubeclient(options[:kubeclient_data])
            end
        end

        def construct_from_kubeclient(data)
            @name = data.metadata.name
        end

        def to_yaml
            YAML.dump({"apiVersion" => "v1",
                       "kind" => "ConfigMap",
                       "metadata" => metadata_hash })
        end

        private
        def metadata_hash
            return { "name" => @name }
        end

    end # End Class
end # End Module

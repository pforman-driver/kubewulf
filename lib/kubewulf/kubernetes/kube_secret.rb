module Kubewulf
    class KubeSecret
        require 'yaml'
        require 'base64'

        attr_accessor :name,
                      :site,
                      :data

        def initialize(options = {})
            if options[:kubeclient_data]
                construct_from_kubeclient(options[:kubeclient_data])
            end
        end

        def construct_from_kubeclient(secret)
            @name = secret.metadata.name
            @site = secret.metadata.namespace
            @data = data_hash(secret.data)
        end

        def data_hash_raw
            @data
        end

        def to_yaml
            YAML.dump({"apiVersion" => "v1",
                       "kind" => "Secret",
                       "metadata" => metadata_hash,
                       "data" => @data})    
        end

        private
        def data_hash(data)
            tmp_h = JSON.parse(JSON.generate(data.to_h))
            return tmp_h.transform_values{|v| Base64.decode64(v)}
        end

        def metadata_hash
            return { "name" => @name, "namespace" => @site }
        end

    end # End Class
end # End Module

module Kubewulf
    class ConfigMap
        attr_accessor :name,
                      :site,
                      :data

        def to_json
            JSON.generate({"apiVersion" => "v1",
                           "kind" => "ConfigMap",
                           "metadata" => {"name" => @name, "namespace" => @site},
                           "data" => @data})
        end

        def data_hash
            JSON.parse(JSON.generate(@data))
        end
        private

    end # End Class
end # End Module

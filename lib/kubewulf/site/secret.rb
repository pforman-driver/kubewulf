module Kubewulf
    class Secret
        attr_accessor :name,
                      :site,
                      :data

        def to_json
            JSON.generate({"apiVersion" => "v1",
                           "kind" => "ConfigMap",
                           "metadata" => {"name" => @name, "namespace" => @site},
                           "data" => @data})
        end

        def data_hash_raw
            return JSON.parse(JSON.generate(data.to_h))
        end

        def data_hash_base64
            tmp_h = JSON.parse(JSON.generate(data.to_h))
            return tmp_h.transform_values{|v| Base64.strict_encode64(v)}
        end

        private

    end # End Class
end # End Module

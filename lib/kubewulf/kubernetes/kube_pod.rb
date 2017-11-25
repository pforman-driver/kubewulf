module Kubewulf
    class KubePod
        attr_accessor :name,
                      :app_name,
                      :site,
                      :version,
                      :release_track,
                      :phase,
                      :private_ipv4

        def initialize(options = {})
            if options[:kubeclient_data]
                construct_from_kubeclient(options[:kubeclient_data])
            end
        end

        def construct_from_kubeclient(data)
            @name = data.metadata.name
            @site = data.metadata.namespace
            @private_ipv4 = data.status.podIP
            if data.metadata.labels
                @app_name = data.metadata.labels.app
                @release_track = data.metadata.labels.track
                @version = data.metadata.labels.version
            end
            @phase = data.status.phase
        end

    end # End Class
end # End Module

module Kubewulf

    # This class is intimately coupled with the yaml format, as described 
    # in the README. 
    # This initial design makes it cleaner to deploy a working instance of the gem
    # enabling users to eventually design their own datasource, and integrate
    # wtih the TODO API based config backend. 
    # The resoning behind the way the yaml is constructed is with the goal
    # of keeping it easier for human consumption and vcs diffs.

    class Datastore

        require 'json'
        require 'yaml'
        require 'deep_merge'

        attr_accessor :base_file_path,
                      :sites,
                      :file_format, # yaml or json 
                      :site_defaults,
                      :service_type_data,
                      :cluster_data

        def initialize(options = {})
            @log = Kubewulf::Logger
            @file_format = "yaml"
            @base_file_path = options[:base_file_path]

            if @base_file_path.nil?
                raise "datastore::base_file_path not set!"
            end
        end

        # Build list of sites, constructed from the defined default hash, and the
        # individual site settings.
        # This is the primary map for loading the additional classess associated with
        # a site like site_cluster_map, site_secret, and site_service. 
        def load_sites
            sites = {}
  
            @log.debug "Loading site defaults..."
            site_defaults = load_objects("site_defaults")
            @log.debug "Found: #{site_defaults.keys.sort.join(", ")}"

            load_objects("sites").each do |site_id, site_data|

                @log.debug "Loading site_id: #{site_id}..."
                # Using marshalling to properly clone the site_default object
                # https://stackoverflow.com/questions/8206523/how-to-create-a-deep-copy-of-an-object-in-ruby
                site = Marshal.load(Marshal.dump(site_defaults[site_data[:default_config].to_sym]))

                @log.debug "Loading site defaults: #{site_data[:default_config]}"
                site.deep_merge!(site_data)

                s_obj = Site.new
                s_obj.name = site_id.to_s
                s_obj.description = site[:description]
                s_obj.domain = site[:domain]
                s_obj.environment = site[:environment]
                s_obj.cluster_id = site[:cluster_id]
                s_obj.secret_backend = site[:secret_backend]
                s_obj.site_contact_email = site[:site_contact_email]
                s_obj.site_contact_phone = site[:site_contact_phone]
                s_obj.cloud_account_id = site[:cloud_account_id]
                s_obj.data = site[:data]

                sites[site_id] = s_obj
            end
            return sites
        end

        # Build the list of services. 
        # Note: It is intentional to prevent site specific overrides 
        # to the configuration of a service to prevent complex configuration 
        # overrides and inheritance. 
        def load_services
            services = {}

            @log.debug "Loading services..."
            service_defaults = load_objects("service_defaults")
            @log.debug "Found: #{service_defaults.keys.sort.join(", ")}"

            load_objects("services").each do |service_id, service_data|
    
                @log.debug "Loading service_id: #{service_id}..."
                # Using marshalling to properly clone the service_default object
                # https://stackoverflow.com/questions/8206523/how-to-create-a-deep-copy-of-an-object-in-ruby
                service = Marshal.load(Marshal.dump(service_defaults[service_data[:default_config].to_sym]))

                @log.debug "Loading service defaults: #{service_data[:default_config]}"
                service.deep_merge!(service_data)

                @log.debug service.inspect

                s_obj = Kubewulf::Service.new
                s_obj.name = service_id.to_s
                s_obj.proxy_mode = service[:proxy_mode]
                s_obj.kubernetes_service_type = service[:kubernetes_service_type]
                s_obj.routing_tag = service[:routing_tag]
                s_obj.ports = service[:ports]
                
                @log.debug s_obj.inspect

                services[service_id] = s_obj
            end
            return services
        end

        private

        # Object load method, used to ensure interface to yaml files
        # is consistent
        def load_objects(obj_class)
            data = nil
            f = nil

            begin
                f = File.open(File.join(@base_file_path, "#{obj_class}.#{@file_format}"), "r")
            rescue Errno::ENOENT => e
                @log.fatal "File not found: #{e}"
                exit 1
            rescue Exception => e
                raise e
            end

            begin
                case @file_format
                    when "json"
                        data = JSON.load(f)
                    when "yaml"
                        data = YAML.load(f)
                end
            rescue Exception => e
                raise e
            end

            begin
                # Kubewulf::validate(obj_class)
                # TODO: add object validations
                true
            rescue Exception => e
                raise e
            end

            data.symbolize_keys!
            return data
        end
        
    end # End Class
end # End Module

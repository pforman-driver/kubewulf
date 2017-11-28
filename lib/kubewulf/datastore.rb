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

        # Fog is a pretty heavy gem, we only use it 
        # to keep cloud storage interactions abstracted
        # perhaps in the future we may write our own abstraction
        # to limit possible compatibility issues 
        require 'fog'

        attr_accessor :base_file_path,
                      :cloud_storage_bucket,
                      :cluster_data,
                      :file_format, # yaml or json 
                      :service_type_data,
                      :storage_provider,
                      :site_defaults,
                      :sites

        def initialize(options = {})
            @log = Kubewulf::Logger
            @base_file_path = options[:base_file_path]
            @cloud_storage_bucket = options[:cloud_storage_bucket]
            @file_format = "yaml"
            @storage_provider = options[:storage_provider] || "local"

            if @base_file_path.nil?
                raise "datastore::base_file_path not set!"
            end

            @log.debug "Storage provider: #{@storage_provider}"
            @log.debug "Storage bucket: #{@cloud_storage_bucket}"
            @log.debug "Storage path: #{@base_file_path}"
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

                @log.debug "Merging site '#{site_id} with following defaults: '#{site_data[:default_config]}'"
                site.deep_merge!(site_data)

                s_obj = Site.new
                s_obj.name = site_id.to_s
                s_obj.description = site[:description]
                s_obj.domain = site[:domain]
                s_obj.environment = site[:environment]
                s_obj.hosted_services = site[:hosted_services]
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

            @log.debug "Loading service_defaults..."
            service_defaults = load_objects("service_defaults")
            @log.debug "Found: #{service_defaults.keys.sort.join(", ")}"

            load_objects("services").each do |service_id, service_data|
    
                @log.debug "Loading service '#{service_id}'..."
                # Using marshalling to properly clone the service_default object
                # https://stackoverflow.com/questions/8206523/how-to-create-a-deep-copy-of-an-object-in-ruby
                service = Marshal.load(Marshal.dump(service_defaults[service_data[:default_config].to_sym]))

                @log.debug "Merging service '#{service_id}' with following defaults: '#{service_data[:default_config]}'"
                service.deep_merge!(service_data)

                s_obj = Kubewulf::Service.new
                s_obj.name = service_id.to_s
                s_obj.proxy_mode = service[:proxy_mode]
                s_obj.kubernetes_service_type = service[:kubernetes_service_type]
                s_obj.routing_tag = service[:routing_tag]
                s_obj.ports = service[:ports]
                
                services[service_id] = s_obj
            end
            return services
        end

        # Build the list of managed clusters
        def load_clusters
            clusters = {}

            @log.debug "Loading clusters..."

            load_objects("clusters").each do |cluster_id, cluster_data|

                @log.debug "Loading cluster '#{cluster_id}'..."
                c_obj = Kubewulf::Cluster.new
                c_obj.name = cluster_id.to_s
                c_obj.zone = cluster_data[:zone]
                c_obj.cloud_account_id = cluster_data[:cloud_account_id]

                clusters[cluster_id] = c_obj
            end
            return clusters
        end

        private

        # Object load method
        # is consistent
        def load_objects(obj_class)
            data = nil
            filename = "#{obj_class}.#{@file_format}"
           
            case storage_provider
                when "local"
                    data = load_local_file(filename)
                else 
                    data = load_cloud_file(filename)
            end
 
            # Kubewulf::validate(obj_class)
            # TODO: add object validations

            # Enforce symbolized keys
            data.symbolize_keys!

            return data
        rescue Exception => e
            raise e
        end

        # Common method to parse datastore file
        def parse_file_data(raw_data)
            data = nil
            case @file_format
                when "json"
                    data = JSON.load(raw_data)
                when "yaml"
                    data = YAML.load(raw_data)
            end
            return data
        rescue Exception => e
            raise "Parse ERROR: #{e}"
        end

        # Basic file load, assumes base path is fully qualified
        # TODO: leverage fog's cloud storage mocks to have 
        # local be only for testing, as we assume that any one using 
        # this gem for anything serious would use a managed cloud storage
        # bucket
        def load_local_file(filename)
            data = nil
            f = File.open(File.join(@base_file_path, filename), "r")
            case @file_format
                when "json"
                    data = JSON.load(f)
                when "yaml"
                    data = YAML.load(f)
            end
            return data
        rescue Errno::ENOENT => e
            @log.fatal "File not found: #{e}"
            exit 1
        rescue Exception => e
            raise e
        end

        # Common method to load file from cloud storage
        def load_cloud_file(filename)
            data = nil
            resp = cloud_storage.get_object( @cloud_storage_bucket, 
                                             File.join(@base_file_path, filename) ) 
            if resp.body
                data = parse_file_data(resp.body.to_s)
            end
        rescue Exception => e
            raise "Cloud Storage ERROR: #{e}"
        end

        # Cloud storage client lazy loader
        def cloud_storage
            if @cloud_storage.nil?
                case @storage_provider
                    when "Google"
                        @cloud_storage = Fog::Storage.new({
                            :provider => 'Google',
                            :google_storage_access_key_id => ENV['STORAGE_KEY_ID'],
                            :google_storage_secret_access_key => ENV['STORAGE_SECRET'] })
                    when "AWS"
                        @cloud_storage = Fog::Storage.new({
                            :provider => 'AWS',
                            :aws_access_key_id => ENV['STORAGE_KEY_ID'],
                            :aws_secret_access_key => ENV['STORAGE_SECRET'] })
                end
            end
            return @cloud_storage
        rescue Exception => e
            raise "Cloud Storage Init ERROR: #{e}"
        end
        
    end # End Class
end # End Module

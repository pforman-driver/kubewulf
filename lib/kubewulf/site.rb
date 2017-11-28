module Kubewulf
    class Site
        require 'kubewulf/site/config_map'
        require 'kubewulf/site/secret'

        attr_accessor :name,
                      :cluster_id,
                      :description,
                      :environment,
                      :secret_backend,
                      :explicit_service_list,
                      :domain,
                      :site_contact_email,
                      :site_contact_phone,
                      :cloud_account_id,
                      :data

        def initialize(options = {})
            @log = Kubewulf::Logger
            @config_maps = []
            @secrets = []
            @explicit_service_list = []
            load_options(options)

            @vault = HashicorpVault.new
        end

        def required_fields
            return true
        end

        # Returns list of config map objects found 
        # configured in @data
        def config_maps
            if @config_maps.empty? 
                set_config_maps
            end
            return @config_maps
        end

        # This method is intended to be configurable
        # as no one will want to put their secrets in
        # raw yaml. It will likely come from a vault
        # like hahicorp's vault or someother backend
        def secrets
            if @secrets.empty?
                set_secrets
            end
            return @secrets
        end

        def run_service?(service_name)
            if @explicit_service_list.empty?
                return true
            else
                return @explicit_service_list.include?(service_name)
            end
        end

        private

        # Config map and secret construction lives here. 
        # TODO: this could be refactored to somewhere common perhaps?
        def set_config_maps
            config_map_ids.each do |cm_key|
                cm_data = @data[cm_key] 
                cm = ConfigMap.new
                cm.name = cm_key.to_s 
                cm.site = @name
                cm.data = cm_data
                @config_maps << cm
            end
        end

        # This method serves as a map to multiple backends, configurable by site
        # test: will use the site's data object as a source
        # hashicorp_vault: will use a hashicorp vault backend, see readme for 
        # more details on it's implementation
        def set_secrets
            case @secret_backend
                when "test"
                    set_test_secrets
                when "hashicorp_vault"
                    set_hashicorp_vault_secrets
            end
        end

        def set_test_secrets
            @data.keys.select{|k| k.to_s.end_with?("-secrets")}.each do |secret_key|
                secret = Secret.new
                secret.name = secret_key.to_s
                secret.site = @name
                secret.data = @data[secret_key]
                @secrets << secret
            end
        end
        
        def set_hashicorp_vault_secrets
            @data.keys.select{|k| k.to_s.end_with?("-secrets")}.each do |secret_key|
                secret = Secret.new
                secret.name = secret_key.to_s
                secret.site = @name
                secret.data = {}
                @data[secret_key].each do |k,v|
                    secret.data[k] = @vault.read_vault_secret(v)
                end 
                @secrets << secret
            end
        end 

        def read_hashicorp_vault_key(key)
            return "some super secret thing from vault"
        end

        def config_map_ids
            @data.keys.select{|k| k.to_s.end_with?("-conf")}.sort
        end

        def config_map_names
            @data.keys.select{|k| k.to_s.end_with?("-conf")}.collect{|k| k.to_s}.sort
        end
 
        def load_options(options)
          options.each do |k,v| 
            self.send("#{k.to_s}=".to_sym, v)
          end
        end

    end # End Class
end # End Module

module Kubewulf
    class HashicorpVault
        require 'vault'

        # For hashicorp vault, expects the following 
        # env variables:
        # VAULT_ADDR
        # VAULT_TOKEN
        # VAULT_SSL_VERIFY

        def initialize
            @log = Kubewulf::Logger
            @client = Vault::Client.new
        end

        # Key is in format of vaultkey _space_ field_name
        def read_vault_secret(key)
            value = ""
            (vault_key, field_name) = key.split(/\s/)
            secret = @client.logical.read(vault_key) 
            if secret.nil? 
                @log.warn "Vault key '#{vault_key}' not found"
            end

            if secret.data.has_key?(field_name.to_sym)
                value = secret.data[field_name.to_sym]
            else
                @log.warn "Field name '#{field_name}' not found in vault key '#{vault_key}'"
            end 
            return value
        rescue Exception => e
            @log.warn "Unable to retrieve vault key '#{vault_key}' with field '#{field_name}': #{e}"
            raise e
        end

        private

    end # End Class
end # End Module

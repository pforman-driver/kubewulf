require "kubewulf/version"

module Kubewulf
    require 'kubewulf/datastore'
    require 'kubewulf/site'
    require 'kubewulf/service'
    require 'kubewulf/logger'
    require 'kubewulf/kubernetes'
    require 'kubewulf/hashicorp_vault'
end


class Hash
    def symbolize_keys!
        t=self.dup
        self.clear
        t.each_pair do |k,v|
            if v.kind_of?(Hash)
                v.symbolize_keys!
            end
            self[k.to_sym] = v
            self
        end
        self
    end
end

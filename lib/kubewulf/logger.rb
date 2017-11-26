module Kubewulf
    require 'logger'

    def Kubewulf.init_logger
        $stdout.sync = true
        return Logger.new($stdout) 
    end 
    Logger = Kubewulf.init_logger
end

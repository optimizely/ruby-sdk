module Optimizely
  class ProxyConfig
    attr_reader :host, :port, :username, :password

    def initialize(host, port = nil,  username = nil, password = nil)
      # host - DNS name or IP address of proxy
      # port - port to use to acess the proxy
      # username - username if authorization is required
      # password - password if authorization is required
      @host = host
      @port = port
      @username = username
      @password = password
    end
  end
end

require 'forwardable'

module Celluloid
  module WebSocket
    module Client
      class Connection
        include Celluloid::IO
        extend Forwardable

        def initialize(url, handler)
          @url = url
          uri = URI.parse(url)
          port = uri.port || (uri.scheme == "ws" ? 80 : 443)
          @socket.close rescue nil
          @socket = Celluloid::IO::TCPSocket.new(uri.host, port)
          @socket = Celluloid::IO::SSLSocket.new(@socket) if port == 443
          @socket.connect
          @client = ::WebSocket::Driver.client(self)
          @handler = handler

          async.run
        end
        attr_reader :url

        def run
          @client.on('open') do |event|
            @handler.async.on_open if @handler.respond_to?(:on_open)
          end
          @client.on('message') do |event|
            @handler.async.on_message(event.data) if @handler.respond_to?(:on_message)
          end
          @client.on('close') do |event|
            @handler.async.on_close(event.code, event.reason) if @handler.respond_to?(:on_close)
          end

          @client.start

          loop do
            begin
              @client.parse(@socket.readpartial(1024))
            rescue EOFError
              break
            end
          end
        end

        def_delegators :@client, :text, :binary, :ping, :close, :protocol

        def write(buffer)
          @socket.write buffer
        end
      end
    end
  end
end



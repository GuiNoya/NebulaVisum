#!/bin/ruby

require 'socket'
require 'json'
require 'rubygems'

class Communicator

	attr_reader :port, :core;

	def initialize(port = 2000)
		@port = port;
		@core = Core.new("oneuser:onepass", "http://localhost:2633/RPC2")
	end

	def start()
		server = TCPServer.new(self.port)
		loop do
			Thread.start(server.accept) do |client|
				string = client.gets.chomp
				parsed = JSON.parse(string)
				parsed.each_pair do |key, value|
					response = eval("core." + key + "(value)")
					client.puts(response)
				end
				client.close
			end
		end
	end
end

# Verificar se está rodando como root

communicator = Communicator.new
communicator.start

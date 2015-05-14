#!/bin/ruby

require 'socket'
require 'json'
require 'rubygems'

require_relative 'Core'

class Communicator

	attr_reader :port, :core;

	def initialize(port = 2000)
		@port = port;
		@core = Core.new("nebulavisum:nebulavisum", "http://localhost:2633/RPC2")
	end

	def start()
		server = TCPServer.new(self.port)
		loop do
			Thread.start(server.accept) do |client|
				string = client.gets.chomp
				begin
					parsed = JSON.parse(string)
				rescue
					puts string
					client.puts("ERR_INVALID_JSON")
					client.close
					Thread.exit
				end
				parsed.each_pair do |key, value|
					begin
						response = eval("core." + key + "(value)")
						client.puts(response)
					rescue Exception => e
						puts e.message
						puts e.backtrace.inspect
					end
				end
				client.close
			end
		end
	end
end

raise "Must run as root!" unless Process.uid == 0

communicator = Communicator.new
communicator.start

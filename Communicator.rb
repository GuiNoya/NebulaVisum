require 'socket'
require 'json'
require 'rubygems'
class Communicator
	attr_reader :port, :core;

	def initialize(port = 2000)
		@port = port;
		@core = Core.new("oneuser:onepass","http://localhost:2633/RPC2")
	end

	def start()
		server = TCPServer.new self.port
		loop do
			Thread.start(server.accept) do |client|
			string = client.gets.chomp
			parsed = JSON.parse(string)
			parsed.each_pair do |key, value|
				if(key == "softDisponiveis")
					response = core.availableSoft(value);
				elsif(key == "criarTemplate")
					response = core.createTemplate(value);
				elsif(key == "criarVM")
					response = core.createVM(value);
				elsif(key == "infoVM")
					response = core.infoVM(value);
				elsif(key == "minhasVMs")
					response = core.myVMs(value);
				elsif(key == "meusTemplates")
					response = core.myTemplates(value);
				end
				client.puts response
			end
			client.close
			end
		end
	end
end

communicator = Communicator.new()
communicator.start()

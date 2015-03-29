require 'socket'
require 'json'
require 'rubygems'
class Communicator
	attr_reader :port;

	def initialize(port = 2000)
		@port = port;
	end

	def start()
		server = TCPServer.new self.port
		loop do
			Thread.start(server.accept) do |client|
			string = client.gets.chomp
			parsed = JSON.parse(string)
			parsed.each_pair do |key, value|
				if(key == "softDisponiveis")
					response = availableSoft(value);
				elsif(key == "criarTemplate")
					response = createTemplate(value);
				elsif(key == "criarVM")
					response = createVM(value);
				elsif(key == "infoVM")
					response = infoVM(value);
				elsif(key == "minhasVMs")
					response = myVMs(value);
				elsif(key == "meusTemplates")
					response = myTemplates(value);
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

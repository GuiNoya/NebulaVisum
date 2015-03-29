# Environment Configuration
ONE_LOCATION=ENV["ONE_LOCATION"]

if !ONE_LOCATION
	RUBY_LIB_LOCATION="usr/lib/one/ruby"
else
	RUBY_LIB_LOCATION=ONE_LOCATION+"/lib/ruby"
end

$: << RUBY_LIB_LOCATION

require 'json'
require 'rubygems'
require 'opennebula'
include OpenNebula
class Core
	attr_reader :oneClient
	def initialize()
		CREDENTIALS = "oneuser:onepass"
		ENDPOINT = "http://localhost:2633/RPC2"

		@oneClient = Client.new(CREDENTIALS, ENDPOINT)
	end

	def availableSoft(string)
		parsed = JSON.parse(string);
	
		response = '{"softDisponiveis":'
		#ATRIBUI STATUS
		response += '{"status":' + status
		#PEGA SOFTWARES
		response += ', "softwares":' + softwares + '}'
		response += '}'
	end

	def createTemplate(string)
		parsed = JSON.parse(string);
		#CRIA TEMPLATE COM BASE NO PARSE
		#SE PRIMEIRO ACESSO
			#CRIA VN E A ASSOCIA AO USUARIO
		#SENÃO
			#PEGA VN DO USUARIO
	
		#CRIA A IMAGEM
		#CRIA TEMPLATE
	
		response = '{"criarTemplate":'
		response += '{"idTemplate":' + name
		response += ', "status":' + status + '}'
		response += '}'
	end

	def createVM(string)
		parsed = JSON.parse(string);
		#CRIA VM COM BASE NO PARSE

		response = '{"criarVM":'
		response += '{"VMs":' + vms
		response += ', "status":' + status + '}'
		response += '}'
		end

	def infoVM(string)
		parsed = JSON.parse(string);
		#OBTEM INFORMACOES DA VM COM BASE NO PARSE
	
		response = '{"infoVM":'
		response += '{"status":' + status
		#INFO FISICAS
		response += ', "hd":' + hd
		response += ', "mem":' + mem
		response += ', "cpu":' + cpu
		#INFO REDE
		response += ', "ip":' + ip
		response += ', "mask":' + mask
		response += ', "broadcast":' + broadcast
		response += ', "gateway":' + gateway
		#INFO SOFTWARES
		response += ', "softwares":' + softwares + '}'
		response += '}'
	end

	def myVMs(string)
		parsed = JSON.parse(string);
		#OBTEM NOMES DAS VMS DADO USUARIO
	
		response = '{"minhasVMs":'
		response += '{"status":' + status
		response += ', "VMs":' + vms + '}'
		response += '}'
	end

	def myTemplates(string)
		parsed = JSON.parse(string);
		#OBTEM NOMES DOS TEMPLATES DADO USUARIO
	
		response = '{"meusTemplates":'
		response += '{"templates":' + templates
		response += ', "status":' + status + '}'
		response += '}'
	end
end

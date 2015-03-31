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

	attr_reader :oneClient, :conf;
	
	def initialize(credential, endpoint)

		@oneClient = Client.new(credential, endpoint)

		lines_vector = File.readlines("/etc/NebulaVisum/nv.conf")
		@conf = {}
		lines_vector.each do |line|
			key, value = line.split(":=")
			@conf[key] = value
		end
	end

	def avblSoft(hash)
	
		response = '{"avblSoft":'
		if(@conf.length > 0)
			status = "OK"
		else
			status = "ERR_UNAVAILABLE_SOFTWARES"
		end

		response += '{"status":' + status
		softwares = '['

		@conf.each_pair do |key, value|
			softwares += '"'+ key +'"'
			softwares += ','
		end

		softwares[softwares.length-1] = ']'
		response += ', "softwares":' + softwares + '}'
		response += '}'
	end

	def createTemplate(hash)
		#CRIA TEMPLATE COM BASE NO PARSE
		#SE PRIMEIRO ACESSO
			#CRIA VN E A ASSOCIA AO USUARIO
		#SENÃO
			#PEGA VN DO USUARIO
	
		#CRIA A IMAGEM
		
		# Precisa verificar por erros de execução nos comandos
		system('mount_image.sh ' + user)
		
		softwares.each do |software|
			system('chroot /mnt/'+ user +' '+ @conf[software])
		end
		system('umount_image.sh ' + user)
		
		#CRIA TEMPLATE
	
		response = '{"createTemplate":'
		response += '{"templateId":' + name
		response += ', "status":' + status + '}'
		response += '}'
	end

	def createVM(hash)
		#CRIA VM COM BASE NO PARSE

		response = '{"createVM":'
		response += '{"VMs":' + vms
		response += ', "status":' + status + '}'
		response += '}'
		end

	def infoVM(hash)
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

	def myVMs(hash)
		#OBTEM NOMES DAS VMS DADO USUARIO
	
		response = '{"myVMs":'
		response += '{"status":' + status
		response += ', "VMs":' + vms + '}'
		response += '}'
	end

	def myTemplates(hash)
		#OBTEM NOMES DOS TEMPLATES DADO USUARIO
	
		response = '{"myTemplates":'
		response += '{"templates":' + templates
		response += ', "status":' + status + '}'
		response += '}'
	end
end

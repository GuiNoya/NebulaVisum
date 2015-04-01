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
		softwares = '[ '

		@conf.each_pair do |key, value|
			softwares += '"'+ key +'"'
			softwares += ','
		end

		softwares[softwares.length-1] = ']'
		response += ', "softwares":' + softwares + '}'
		response += '}'
	end

	def createTemplate(hash)
		user = hash["userId"]

		rs = DataBase.getData("UserId, NetworkID","Users","UserName = "+user)
		if(rs.length == 0)
			template_vn = <<-BLOCK
				NAME = 
				TYPE = RANGED
				BRIDGE = vbr0
				NETWORK_SIZE = 
				NETWORK_ADDRESS = 
				GATEWAY = 
				DNS = 
				LOAD_BALANCER = 
			BLOCK
			xml_vn = OpenNebula::VirtualNetwork.build_xml
			vn = OpenNebula::VirtualNetwork.new(xml_vn, @oneClient)
			vn_id = vn.id
			rc_vn = vn.allocate(template_vn)
			if OpenNebula.is_error?(rc_vn)
				status = "ERR_CREATE_VN"
			else
				DataBase.insertUser(vn.id.to_s,user)
			end
		else
			vn_id = rs.first["NetworkId"]
		end
		#CRIA A IMAGEM
		
		# Precisa verificar por erros de execução nos comandos
		system('mount_image.sh ' + user)
		system('mkdir -p /mnt/'+user+'/etc/NebulaVisum')
		hash["softwares"].each do |software|
			s = @conf[software].split('/')
			system('cp '+@conf[software]+' /mnt/'+ user + '/etc/NebulaVisum/'+s.last)
			system('chroot /mnt/'+ user +' /etc/NebulaVisum/'+s.last)
		end
		system('umount_image.sh ' + user)
		
		#CRIA TEMPLATE
		template = <<-BLOCK
			
		BLOCK
		xml_template = OpenNebula::Template.build_xml
		tempalte = OpenNebula::Templatenew(xml_template, @oneClient)
		rc_template = template.allocate(template)
		name = ""
		if OpenNebula.is_error?(rc_vn)
			status = "ERR_CREATE_TEMPLATE"
		else
			name = user+'_'+rc_template.id.to_s
			DataBase.insertTemplate(user+rc_template.id.to_s,name)
			status = "OK"
		end

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
		where = "Users.UserName = " + "'"+hash["userId"]+"'"
		where += " AND Users.UserId = VMs.UserId"
		rs = DataBase.getData("VMs.Name","Users, VMs",where)

		vms = "[ "
		rs.each do |row|
			vms += "'"+row["VMs.Name"]+"'"
			vms += ","
		end
		vms[vms.length-1] = "]"
	
		response = '{"myVMs":'
		response += '{"status":' + status
		response += ', "VMs":' + vms + '}'
		response += '}'
	end

	def myTemplates(hash)
		where = "Users.UserName = " + "'"+hash["userId"]+"'"
		where += " AND Users.UserId = Templates.UserId"
		rs = DataBase.getData("Templates.Name","Users, Templates",where)

		templates = "[ "
		rs.each do |row|
			templates += "'"+row["Templates.Name"]+"'"
			templates += ","
		end
		templates[templates.length-1] = "]"

		#TRATAR STATUS
	
		response = '{"myTemplates":'
		response += '{"templates":' + templates
		response += ', "status":' + status + '}'
		response += '}'
	end
end

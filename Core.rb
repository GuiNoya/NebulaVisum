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
			template_vn = "NAME = "+user+"\n"
			template_vn += <<-BLOCK
				TYPE = RANGED
				BRIDGE = vbr0
				NETWORK_SIZE = C
				NETWORK_ADDRESS = 192.168.0.0
				GATEWAY = 192.168.0.1
				DNS = 192.168.0.1
				LOAD_BALANCER = 192.168.0.3
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
		
		# Precisa verificar por erros de execução nos comandos
		imageId = DataBase.addImage(user)
		system('mount_image.sh ' + user + imageId.to_s)
		system('mkdir -p /mnt/'+user+ imageId.to_s+'/etc/NebulaVisum')
		hash["softwares"].each do |software|
			s = @conf[software].split('/')
			system('cp '+@conf[software]+' /mnt/'+user+imageId.to_s+ '/etc/NebulaVisum/'+s.last)
			system('chroot /mnt/'+ user + imageId.to_s +' /etc/NebulaVisum/'+s.last)
		end
		system('umount_image.sh ' + user + imageId.to_s)
		
		#CRIA IMAGEM

		template_img = <<-BLOCK
			NAME = 
			PATH = 
		BLOCK

		xml_img = OpenNebula::Image.build_xml
		img = OpenNebula::Image.new(xml_img, @oneClient)
		rc_img = img.allocate(template_img)

		if OpenNebula.is_error?(rc_img)
			status = "ERR_CREATE_IMAGE"

		#CRIA TEMPLATE
		template = <<-BLOCK
			NAME = 
			MEMORY = 
			CPU = 
			ARCH = 
			NIC = 
			IMAGE = 
		BLOCK

		xml_template = OpenNebula::Template.build_xml
		template = OpenNebula::Template.new(xml_template, @oneClient)
		rc_template = template.allocate(template)
		name = " "
		if OpenNebula.is_error?(rc_vn)
			status = "ERR_CREATE_TEMPLATE"
			DataBase.delImage(user)
		else
			name = user+'_'+imageId.to_s
			DataBase.insertTemplate(user+rc_template.id.to_s,name)
			status = "OK"
		end

		response = '{"createTemplate":'
		response += '{"templateId":' + name
		response += ', "status":' + status + '}'
		response += '}'
	end

	def createVM(hash)
		
		rs = DataBase.getData("TemplateId, UserId, NebulaId, Name", "Templates", "Name = " + hash["templateId"])
		vms = []
		
		if (rs.length == 1)
			rs.each do |row|
				templateId = row["TemplateId"]
				userId = row["UserId"]
				nebulaId = row["NebulaId"]
				templateName = row["Name"]
			end
			
			xml = OpenNebula::Template.build_xml(nebulaId)
			template = OpenNebula::Template.new(xml, @oneClient)
			
			qty = hash["qty"]
			
			status = "OK"
			for i in 1..qty
				vmId = template.instantiate
				if (OpenNebula.is_error?(vmId))
					status = "ERR_COULD_NOT_INSTANTIATE"
					break
				else
					vms << vmId
					DataBase.insertVm(userId, templateId, vmId, templateName + "_" + vmId)
				end
			end
			
		else
			status = "ERR_INVALID_TEMPLATE"
		end
		
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

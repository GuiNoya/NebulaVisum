# Environment Configuration
ONE_LOCATION = ENV["ONE_LOCATION"]

if (!ONE_LOCATION)
	RUBY_LIB_LOCATION = "/usr/lib/one/ruby"
else
	RUBY_LIB_LOCATION = ONE_LOCATION + "/lib/ruby"
end

$: << RUBY_LIB_LOCATION

require 'json'
require 'rubygems'
require 'opennebula'

require_relative 'DataBase'

include OpenNebula

class Core

	attr_reader :oneClient, :conf;
	
	def initialize(credential, endpoint)

		@oneClient = Client.new(credential, endpoint)
		DataBase.open("/etc/NebulaVisum/nv.db")

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

		response += '{"status":"' + status + '",'
		softwares = '[ '

		@conf.each_pair do |key, _|
			softwares += '"'+ key +'"'
			softwares += ','
		end

		softwares[softwares.length-1] = ']'
		response += ', "softwares":' + softwares.to_s + '}'
		response += '}'
	end

	def createTemplate(hash)
	
		user = hash["userId"]
		rs = DataBase.getData("UserId, NetworkID", "Users", "UserName = " + user)
		
		if (rs.length == 0)
			template_vn = "NAME = " + user + "\n"
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
			if (OpenNebula.is_error?(rc_vn))
				status = "ERR_CREATE_VN"
				response = '{"createTemplate": {"templateId": "", "status": "' + status + '"}}'
				return response
			else
				DataBase.insertUser(vn.id.to_s, user)
			end
		else
			vn_id = rs.first["NetworkId"]
		end
		
		# Precisa verificar por erros de execução nos comandos
		imageId = DataBase.addImage(user)
		system('mount_image.sh ' + user + imageId.to_s)
		system('mkdir -p /mnt/' + user + imageId.to_s + '/etc/NebulaVisum')
		hash["softwares"].each do |software|
			s = @conf[software].split('/')
			system('cp ' + @conf[software] + ' /mnt/' + user + imageId.to_s + '/etc/NebulaVisum/' + s.last)
			system('chroot /mnt/' + user + imageId.to_s + ' /etc/NebulaVisum/' + s.last)
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

		if (OpenNebula.is_error?(rc_img))
			status = "ERR_CREATE_IMAGE"
			response = '{"createTemplate": {"templateId": "", "status": "' + status + '"}}'
			return response
		end

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
		name = '""'
		if OpenNebula.is_error?(rc_vn)
			status = "ERR_CREATE_TEMPLATE"
			DataBase.delImage(user)
		else
			name = user + '_' + imageId.to_s
			DataBase.insertTemplate(user + rc_template.id.to_s, name, hash["softwares"])
			status = "OK"
		end

		response = '{"createTemplate":'
		response += '{"templateId":"' + name '"'
		response += ', "status":"' + status + '"}'
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
			for _ in 1..qty
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
		response += '{"VMs":' + vms.to_s
		response += ', "status":"' + status + '"}'
		response += '}'
	end

	def infoVM(hash)
		
		rs = DataBase.getData("s.Software, v.NebulaId", "Softwares s, VMs v", "v.VMId = " + hash["VMId"] + " AND v.TemplateId = s.TemplateId")
		vmId = rs.first["v.NebulaId"]
		softwares = "[ "
		rs.each do |row|
			softwares += '"' + row["s.Software"] + '",'
		end
		softwares[softwares.length-1] = "]"
		
		xml = OpenNebula::VirtualMachine.build_xml(vmId)
		vm = OpenNebula::VirtualMachine.new(xml, @oneClient)
		vm.info # Returns nilClass if succeeded
		info = vm.to_hash["VM"]
		
		status = "OK"
		statusVM = vm.state_str
		hd = info["TEMPLATE"]["DISK"]["SIZE"]
		mem = info["TEMPLATE"]["MEMORY"]
		cpu = info["TEMPLATE"]["CPU"]
		ip = info["TEMPLATE"]["NIC"]["IP"]
		mask = info["TEMPLATE"]["CONTEXT"]["ETH0_MASK"]
		network = info["TEMPLATE"]["CONTEXT"]["ETH0_NETWORK"]
		mask_octets = mask.split('.').map(&:to_i)
		net_octets = network.split('.').map(&:to_i)
		broadcast = []
		broadcast << 7.downto(0).map{|n| (net_octets[0] | ~mask_octets[0])[n]}.join.to_i(2)
		broadcast << 7.downto(0).map{|n| (net_octets[1] | ~mask_octets[1])[n]}.join.to_i(2)
		broadcast << 7.downto(0).map{|n| (net_octets[2] | ~mask_octets[2])[n]}.join.to_i(2)
		broadcast << 7.downto(0).map{|n| (net_octets[3] | ~mask_octets[3])[n]}.join.to_i(2)
		broadcast = broadcast.join(".")
		
		xml = OpenNebula::VirtualNetwork.build_xml(info["TEMPLATE"]["NIC"]["NETWORK_ID"])
		vm = OpenNebula::VirtualNetwork.new(xml, @oneClient)
		vm.info # Returns nilClass if succeeded
		info = vm.to_hash["VNET"]
		gateway = info["GATEWAY"]
		
		response = '{"infoVM":'
		response += '{"status":"' + status + '"'
		response += '{"statusVM:"' + statusVM + '"' # vm.status | vm.state_str
		#INFO FISICAS
		response += ', "hd":' + hd.to_s
		response += ', "mem":' + mem.to_s #vm -> template -> memory (max) | vm -> memory (in use)
		response += ', "cpu":' + cpu.to_s #vm -> template -> cpu (max) | vm -> cpu (in use)
		#INFO REDE
		response += ', "ip":"' + ip + '"'
		response += ', "mask":"' + mask + '"'
		response += ', "broadcast":"' + broadcast + '"'
		response += ', "gateway":"' + gateway + '"'
		#INFO SOFTWARES
		response += ', "softwares":' + softwares.to_s + '}'
		response += '}'
	end

	def myVMs(hash)
		where = "Users.UserName = " + "'" + hash["userId"] + "'"
		where += " AND Users.UserId = VMs.UserId"
		rs = DataBase.getData("VMs.Name", "Users, VMs", where)

		status = "OK"

		vms = "[ "
		rs.each do |row|
			vms += "'" + row["VMs.Name"] + "'"
			vms += ","
		end
		vms[vms.length-1] = "]"
	
		response = '{"myVMs":'
		response += '{"status":"' + status + '"'
		response += ', "VMs":' + vms.to_s + '}'
		response += '}'
	end

	def myTemplates(hash)
		where = "Users.UserName = " + "'" + hash["userId"] + "'"
		where += " AND Users.UserId = Templates.UserId"
		rs = DataBase.getData("Templates.Name", "Users, Templates", where)

		status = "OK"

		templates = "[ "
		rs.each do |row|
			templates += "'" + row["Templates.Name"] + "'"
			templates += ","
		end
		templates[templates.length-1] = "]"

		#TRATAR STATUS
	
		response = '{"myTemplates":'
		response += '{"templates":' + templates.to_s
		response += ', "status":"' + status + '"}'
		response += '}'
	end
	
	def actionVM(hash)
		rs = DataBase.getData("NebulaId", "VMs", "VMId = " + hash["VMId"])
		vmId = rs.first["NebulaId"]
		
		xml = OpenNebula::VirtualMachine.build_xml(vmId)
		vm = OpenNebula::VirtualMachine.new(xml, @oneClient)
		
		rc_vm = case hash["action"]
			when "resume" then vm.resume
			when "stop" then vm.stop
			when "shutdown" then vm.shutdown
			when "delete" then vm.delete
			else "ERR_INVALID_OPERATION"
		
		if (OpenNebula.is_error?(rc_vm))
			status = rc_vm.to_str
		elsif (rc_vm == "")
			status = rc_vm
		else
			status = "OK"
		end
		
		response = '{"actionVM": {"status": "' + status + '"}}'
end

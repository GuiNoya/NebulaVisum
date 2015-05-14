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
			@conf[key] = value.chomp
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
		response += ' "softwares":' + softwares.to_s + '}'
		response += '}'
	end

	def createTemplate(hash)
		puts("Checking user...")
		user = hash["userId"]
		rs = DataBase.getData("UserId, NetworkId", "Users", "Name = \"" + user + "\"")
		
		if (rs.first == nil)
			puts("Creating user...")
			template_vn = "NAME = " + user + "\n"
			template_vn += <<-BLOCK
			TYPE = RANGED
			BRIDGE = br1
			NETWORK_SIZE = C
			NETWORK_ADDRESS = 192.168.0.0
			GATEWAY = 192.168.0.1
			DNS = 8.8.8.8
			BLOCK
			puts(template_vn)
			xml_vn = OpenNebula::VirtualNetwork.build_xml
			vn = OpenNebula::VirtualNetwork.new(xml_vn, @oneClient)
			rc_vn = vn.allocate(template_vn)
			vn_id = vn.id

			if (OpenNebula.is_error?(rc_vn))
				puts(rc_vn.errno)
				puts(rc_vn.message)
				status = "ERR_CREATE_VN"
				response = '{"createTemplate": {"templateId": "", "status": "' + status + '"}}'
				return response
			else
				DataBase.insertUser(vn.id.to_s, user)
			end
			rs_user = DataBase.getData("UserId, NetworkId", "Users", "Name = \"" + user + "\"")
			user_id = rs_user.first["UserId"]
			puts("Created user...")
		else
			vn_id = rs.first["NetworkId"]
			user_id = rs.first["UserId"]
		end
		puts("Criando imagem DB..")
		# Precisa verificar por erros de execução nos comandos
		imageId = DataBase.addImage(user)
		puts("Copiando/montando imagem...")
		system('./mount_image.sh ' + user + '_' + imageId.to_s)
		#system('mkdir -p /mnt/' + user + '_' + imageId.to_s)
		puts("Instalando Softwares..")
		hash["softwares"].each do |software|
			s = @conf[software].split('/')
			system('cp ' + @conf[software] + ' /mnt/' + user + "_" + imageId.to_s + '/etc/NebulaVisum/' + s.last)
			system('chmod 777 /mnt/' + user + "_" + imageId.to_s + '/etc/NebulaVisum/' + s.last)
			system('chroot /mnt/' + user + "_" + imageId.to_s + ' bash /etc/NebulaVisum/' + s.last)
		end
		puts("Desmontando Softwares..")
		system('./umount_image.sh ' + user + "_" + imageId.to_s)
		
		#CRIA IMAGEM
		puts("Criando imagem ONE..")
		template_img = "NAME = " + user + "_" + imageId.to_s + "\n"
		template_img += "PATH = /etc/NebulaVisum/images/" + user + "_" + imageId.to_s + ".img"

		xml_img = OpenNebula::Image.build_xml
		img = OpenNebula::Image.new(xml_img, @oneClient)
		rc_img = img.allocate(template_img, 100)

		if (OpenNebula.is_error?(rc_img))
			status = "ERR_CREATE_IMAGE"
			response = '{"createTemplate": {"templateId": "", "status": "' + status + '"}}'
			return response
		end

		#CRIA TEMPLATE
		puts("Criando template ONE..")
		template_des = "NAME = \"" + user + "_" + imageId.to_s + "\"\n"
		template_des += "MEMORY = \"" + hash["mem"].to_s + "\"\n"
		template_des += "CPU = \"" + hash["cpu"].to_s + "\"\n"
		template_des += "ARCH = \"x86_64\" \n"
		template_des += "NIC = [ NETWORK_ID = \"" + vn_id.to_s + "\" ]\n"
		template_des += "IMAGE = [ IMAGE_ID = \"" + img.id.to_s + "\" ]\n"
		
		puts template_des
		
		xml_template = OpenNebula::Template.build_xml
		template = OpenNebula::Template.new(xml_template, @oneClient)
		rc_template = template.allocate(template_des)
		name = '""'
		if OpenNebula.is_error?(rc_template)
			status = "ERR_CREATE_TEMPLATE"
			puts rc_template.message
			puts rc_template.errno
			DataBase.delImage(user)
		else
			name = user + '_' + imageId.to_s
			puts 1
			puts user_id
			puts 2
			puts template.id
			puts 3
			puts name
			puts 4
			puts hash["softwares"]
			DataBase.insertTemplate(user_id, template.id, name, hash["softwares"])
		puts 8
			status = "OK"
		end

		response = '{"createTemplate":'
		response += '{"templateId":"' + name + '"'
		response += ', "status":"' + status + '"}'
		response += '}'
	end

	def createVM(hash)
		rs = DataBase.getData("TemplateId, UserId, NebulaId, Name", "Templates", "Name = \"" + hash["templateId"] + '"')
		vms = []
		hash_rs = rs.first
		if (hash_rs)			
			puts hash_rs
			#rs.first.each_pair do |row|
			templateId = hash_rs["TemplateId"]
			userId = hash_rs["UserId"]
			nebulaId = hash_rs["NebulaId"]
			templateName = hash_rs["Name"]

			#end
			xml = OpenNebula::Template.build_xml(nebulaId)
			template = OpenNebula::Template.new(xml, @oneClient)
			qty = hash["qty"]

			status = "OK"
			for _ in 1..qty
				vmId = template.instantiate
				if (OpenNebula.is_error?(vmId))
					puts  vmId.message
					puts vmId.errno
					status = "ERR_COULD_NOT_INSTANTIATE"
					break
				else
					vms << vmId
					DataBase.insertVm(userId, templateId, vmId, templateName + "_" + vmId.to_s)
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
		rs = DataBase.getData("s.Software, v.NebulaId", "Softwares s, VMs v", "v.Name = \"" + hash["VMId"] + "\" AND v.TemplateId = s.TemplateId")
		softwares = "[ "
		vmId = ""
		rs.each do |row|
			vmId = row["NebulaId"]
			softwares += '"' + row["Software"] + '",'
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
		
		xml = OpenNebula::VirtualNetwork.build_xml(info["TEMPLATE"]["NIC"]["NETWORK_ID"])
		vm = OpenNebula::VirtualNetwork.new(xml, @oneClient)
		vm.info # Returns nilClass if succeeded

		info = vm.to_hash["VNET"]
		mask = info["TEMPLATE"]["NETWORK_MASK"]

		#network = info["TEMPLATE"]["CONTEXT"]["ETH0_NETWORK"]
		network = info["TEMPLATE"]["NETWORK_ADDRESS"]
		mask_octets = mask.split('.').map(&:to_i)
		net_octets = network.split('.').map(&:to_i)
		broadcast = []
		broadcast << 7.downto(0).map{|n| (net_octets[0] | ~mask_octets[0])[n]}.join.to_i(2)
		broadcast << 7.downto(0).map{|n| (net_octets[1] | ~mask_octets[1])[n]}.join.to_i(2)
		broadcast << 7.downto(0).map{|n| (net_octets[2] | ~mask_octets[2])[n]}.join.to_i(2)
		broadcast << 7.downto(0).map{|n| (net_octets[3] | ~mask_octets[3])[n]}.join.to_i(2)
		broadcast = broadcast.join(".")

		gateway = info["TEMPLATE"]["GATEWAY"]
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
		puts 1
		where = "Users.Name = \"" + hash["userId"] + '"'
		puts 2
		where += " AND Users.UserId = VMs.UserId"
		puts 3
		rs = DataBase.getData("VMs.Name", "Users, VMs", where)
		puts 4
		status = "OK"
		puts 5
		vms = "[ "
		puts 6
		rs.each do |row|
			puts row
			vms += '"' + row["Name"] + '"'
			vms += ','
		end
		vms[vms.length-1] = ']'
		puts vms
		response = '{"myVMs":'
		response += '{"status":"' + status + '"'
		response += ', "VMs":' + vms + '}'
		response += '}'
	end

	def myTemplates(hash)
		where = "Users.Name = \"" + hash["userId"] + '"'
		where += " AND Users.UserId = Templates.UserId"
		rs = DataBase.getData("Templates.Name", "Users, Templates", where)

		status = "OK"

		templates = '[ '
		rs.each do |row|
			templates += '"' + row["Name"] + '"'
			templates += ','
		end
		templates[templates.length-1] = ']'

		#TRATAR STATUS
	
		response = '{"myTemplates":'
		response += '{"templates":' + templates
		response += ', "status":"' + status + '"}'
		response += '}'
	end
	
	def actionVM(hash)
		rs = DataBase.getData("NebulaId", "VMs", "VMId = \"" + hash["VMId"] + '"')
		vmId = rs.first["NebulaId"]
		
		xml = OpenNebula::VirtualMachine.build_xml(vmId)
		vm = OpenNebula::VirtualMachine.new(xml, @oneClient)
		
		rc_vm = case hash["action"]
			when "resume" then vm.resume
			when "stop" then vm.stop
			when "shutdown" then vm.shutdown
			when "delete" then vm.delete
			else "ERR_INVALID_OPERATION"
		end
		
		if (OpenNebula.is_error?(rc_vm))
			status = rc_vm.to_str
		elsif (rc_vm == "")
			status = rc_vm
		else
			status = "OK"
		end
		
		response = '{"actionVM": {"status": "' + status + '"}}'
	end
end

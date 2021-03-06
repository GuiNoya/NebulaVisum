require 'sqlite3'

class DataBase

	attr_reader :db
	
	def initialize()
	end

	def DataBase.open(path)
		@@db = SQLite3::Database.open(path)
		@@db.results_as_hash = true
		@@db.execute("CREATE TABLE IF NOT EXISTS Users(UserId INTEGER PRIMARY KEY, NetworkId INTEGER, Name TEXT UNIQUE, ImgCount INTEGER)")
		@@db.execute("CREATE TABLE IF NOT EXISTS Templates(TemplateId INTEGER PRIMARY KEY, UserId INTEGER, NebulaId INTEGER, Name TEXT UNIQUE, FOREIGN KEY(UserId) REFERENCES Users(UserId))")
		@@db.execute("CREATE TABLE IF NOT EXISTS VMs(VMId INTEGER PRIMARY KEY, UserId INTEGER, TemplateId INTEGER, NebulaId INTEGER, Name TEXT UNIQUE, FOREIGN KEY(UserId) REFERENCES Users(UserId), FOREIGN KEY(TemplateId) REFERENCES Templates(TemplateId))")
		@@db.execute("CREATE TABLE IF NOT EXISTS Softwares(SId INTEGER PRIMARY KEY, TemplateId INTEGER NOT NULL, Software TEXT NOT NULL, FOREIGN KEY(TemplateId) REFERENCES Templates(TemplateId))")
	end

	def DataBase.insertUser(networkId, name)
		string = "INSERT INTO Users VALUES(NULL," + networkId + ",'" + name + "',0)"
		@@db.execute(string)
	end

	def DataBase.removeUser(userId)
		string = "DELETE FROM Users WHERE UserId = " + userId
		@@db.execute(string)
	end

	def DataBase.insertTemplate(userId, nebulaId, name, softwares)
		puts "IN"
		string = "INSERT INTO Templates VALUES(NULL," + userId.to_s + "," + nebulaId.to_s + ",'" + name.to_s + "')"
		puts string
		@@db.execute(string)
		rs = DataBase.getData("TemplateId", "Templates", "name = '" + name.to_s + "'")
		templateId = rs.first["TemplateId"]
		softwares.each do |software|
			DataBase.insertSoftware(templateId, software)
		end
	end

	def DataBase.removeTemplate(templateId)
		string = "DELETE FROM Templates WHERE TemplateId = " + templateId
		@@db.execute(string)
	end

	def DataBase.insertVm(userId, templateId, nebulaId, name)
		string = "INSERT INTO VMs VALUES(NULL," + userId.to_s + "," + templateId.to_s + "," + nebulaId.to_s + ",'" + name + "')"
		@@db.execute(string)
	end

	def DataBase.removeVm(vmId)
		string = "DELETE FROM VMs WHERE VMId = " + vmId
		@@db.execute(string)
	end

	def DataBase.insertSoftware(templateId, software)
		string = "INSERT INTO Softwares VALUES(NULL, " + templateId.to_s + ",'" + software.to_s + "')"
		puts string
		@@db.execute(string)
	end

	def DataBase.removeSoftware(templateId, software)
		string = "DELETE FROM Softwares WHERE TemplateId = " + templateId + " AND Software = '" + software + "')"
		@@db.execute(string)
	end

	def DataBase.getData(select, from, where = '1')
		string = "SELECT " + select + " FROM " + from + " WHERE " + where
		puts string
		stmt = @@db.prepare(string)
		rs = stmt.execute
		return rs
	end

	def DataBase.addImage(userName)
		rs = DataBase.getData("UserId, ImgCount","Users","Name = '" + userName + "'")
		i = rs.first["ImgCount"] + 1
		string = "UPDATE Users SET ImgCount = " + i.to_s + " WHERE Name = '" + userName + "'"
		@@db.execute(string)
		return i
	end

	def DataBase.delImage(userName)
		rs = DataBase.getData("UserId, ImgCount","Users","Name = '" + userName + "'")
		i = rs.first["ImgCount"] - 1
		string = "UPDATE Users SET ImgCount = " + i.to_s + " WHERE Name = '" + userName + "'"
		puts string
		@@db.execute(string)
	end
end

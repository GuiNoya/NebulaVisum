require 'sqlite3'

class DataBase
	attr_reader :db;
	def initialize(path)
		@db = SQLite3::Database.open(path)
		@db.execute("CREATE TABLE IF NOT EXISTS Users(UserId INTEGER PRIMARY KEY, NetworkID INTEGER, Name TEXT)")
		@db.execute("CREATE TABLE IF NOT EXISTS Templates(TemplateId INTEGER PRIMARY KEY, UserId INTEGER, NebulaId INTEGER, Name TEXT, FOREIGN KEY(UserId) REFERENCES Users(UserId))")
		@db.execute("CREATE TABLE IF NOT EXISTS VMs(VMId INTEGER PRIMARY KEY, UserId INTEGER, TemplateId INTEGER, NebulaId INTEGER, Name TEXT, FOREIGN KEY(UserId) REFERENCES Users(UserId),FOREIGN KEY(TemplateId) REFERENCES Templates(TemplateId))")
	end

	def insertUser(networkId, name)
		string = "INSERT INTO Users VALUES(NULL,"+networkId+",'"+name+"')"
		database.db.execute(string)
	end

	def removeUser(userId)
		string = "DELETE FROM Users WHERE UserId = "+userId
		database.db.execute(string)
	end

	def insertTemplate(userId, nebulaId, name)
		string = "INSERT INTO Templates VALUES(NULL,"+userId+","+nebulaId+",'"+name+"')"
		database.db.execute(string)
	end

	def removeTemplate(templateId)
		string = "DELETE FROM Templates WHERE TemplateId = "+templateId
		database.db.execute(string)
	end

	def insertVm(userId, templateId, nebulaId, name)
		string = "INSERT INTO VMs VALUES(NULL,"+userId+","+templateId+","+nebulaId+",'"+name+"')"
		database.db.execute(string)
	end

	def removeVm(vmId)
		string = "DELETE FROM VMs WHERE VMId = "+vmid
		database.db.execute(string)
	end

	def getData(select,from,where = '1')
		string = "SELECT "+select+" FROM "+from+" WHERE "+where
		stmt = @db.prepare(string)
		rs = stmt.execute
		return rs
	end
end

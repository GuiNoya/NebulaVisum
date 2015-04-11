import socket

class Client:
	def __init__(self, host, port):
		self.host = host
		self.port = port
		self.s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

	def send(self,request):
		self.s.connect((self.host,self.port))
		self.s.sendall(request)
		data = self.s.recv(4096)
		data = data.rstrip('\n')
		self.s.close()
		return data

	def avblSoft(self, status):
		request = '{"avblSoft":{"status":'+status+'}}\n'
		return self.send(request)

	def createTemplate(self, hd, cpu, mem, softwares, user):
		request = '{"createTemplate":{"hd":'+hd+\
		', "cpu":'+cpu+', "mem":'+mem+\
		', "softwares": '+str(softwares)+\
		', "userId": '+user+'}}\n'
		return self.send(request)

	def createVM(self, templateId, qty):

	def infoVM(self, VMId):

	def myVMs(self, userId):

	def myTemplates(self, userId):

	def actionVM(self, VMId, action):


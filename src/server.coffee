restify = require('restify')

server = restify.createServer()

server.use restify.queryParser()
server.use restify.bodyParser()
server.use restify.gzipResponse()

module.exports = server

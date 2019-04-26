
app = {}

app.isProduction = process.env.NODE_ENV is 'production'

if process.env.NODE_ENV is "test"
  app.config   = require './config/config.test.coffee'
else
  app.config   = require './config/config.coffee'

app.helpers    = require './lib/helpers.coffee'

# Load Mongoose
app.mongoose   = require 'mongoose'
app.mongoose.promise = global.Promise
app.mongoose.connect app.config.mongodb.uri, { useNewUrlParser: true }

# Load libraries
RedisManager = require './lib/RedisManager'
app.r = new RedisManager app
app.f   = require './lib/finance'

app.models = app.helpers.loadModels app # load models

require('./lib/httpServer.coffee')(app) # load web server
require('./lib/socketServer')(app)      # load socket server

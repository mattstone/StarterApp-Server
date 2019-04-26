request  = require 'request'
async    = require 'async'

# Start Setup App
app = {}
app.config   = require '../config/config.coffee'
app.helpers  = require '../lib/helpers.coffee'
app.mongoose = require 'mongoose'
app.mongoose.promise = global.Promise
app.mongoose.connect app.config.mongodb.uri, { useNewUrlParser: true }

# load Redis
RedisManager = require '../lib/RedisManager'
app.r = new RedisManager app

# load models
app.models = app.helpers.loadModels app

query =
  email: "admin@starterapp.com"
  password: "P4ssw0rd!"
  permission: app.config.permissionLevels.ADMIN

app.models.User.create query, (err, admin) ->
  if err?
    console.log "admin@starterapp.com not created"
    console.log err
  else if admin?
    admin.confirmUser()
    console.log "admin@starterapp.com created"

query =
  email: "user@starterapp.com"
  password: "P4ssw0rd!"
app.models.User.create query, (err, user) ->
  if err?
    console.log "user@starterapp.com not created"
    console.log err
  else if user?
    user.confirmUser()
    console.log "user@starterapp.com created"

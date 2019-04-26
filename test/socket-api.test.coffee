request  = require 'request'
should   = require('chai').should()
async    = require 'async'
io       = require('socket.io-client')
helpers  = require '../lib/helpers'
mongoose = require 'mongoose'

arr = (args...) -> args

app = {}

app.config   = require('../config/config.test')
app.helpers  = require '../lib/helpers.coffee'
app.mongoose = require 'mongoose'
app.mongoose.promise = global.Promise
app.mongoose.connect app.config.mongodb.uri, { useNewUrlParser: true }

# load Redis
RedisManager = require '../lib/RedisManager'
app.r = new RedisManager app

# load models
app.models = app.helpers.loadModels app

# End Setup App

appEndPoint = app.config.appEndPoint + ":" + String app.config.port
apiEndPoint = app.config.apiEndPoint + ":" + String app.config.port

user        = null
adminUser   = null
password    = "P4thw0rd"
socket      = null
token       = null
userAccessToken  = null
adminAccessToken = null


describe 'Socket.io API', ->

  before (done) ->
    this.timeout = 30000

    # create user
    tasks =
      user: (done) ->
        user =
          email: "user@email.com"
          password: password
        app.models.User.create user, (err, data) ->
          user = data
          user.confirmUser()
          workingUser = user
          done()

      adminUser: (done) ->
        adminUser =
          email: "admin@email.com"
          password: password
          permission: app.config.permissionLevels.ADMIN
        app.models.User.create adminUser, (err, data) ->
          adminUser = data
          adminUser.confirmUser()
          done()

    async.auto tasks, done

  after (done) ->
    this.timeout = 30000
    app.mongoose.connection.db.dropDatabase (err) ->
      done()

  describe 'Connection', ->

    it 'should connect', (done) ->
      #@timeout 30000
      socket = io.connect "http://localhost:#{app.config.port}/"
      return done() if socket.socket?.connected
      socket.once 'connect', done
      socket.on 'reconnection', -> console.log 'reconnection', arguments
      socket.on 'error', -> console.log 'error', arguments
      socket.on 'event', -> console.log 'event', arguments

    it 'should return an error for an unknown api method', (done) ->
      socket.emit 'apiCall', 'startupAppIsGo', (err) ->
        should.exist err
        err.should.have.property 'code', 'methodNotFound'
        done()

  describe 'Authentication', ->

    it 'should loginWithToken', (done) ->
      token = helpers.createId()
      ttl = 24 * 3600 * 1000 # 24hours

      app.r.setAccessToken token, user, ttl, (err, result) ->
        user_id = user.id
        user_email = user.email
        socket.emit 'apiCall', 'loginWithToken', token,  (err, user) ->
          should.not.exist err
          user._id.should.be.equal user_id
          user.email.should.be.equal user_email
          done()

  describe 'User', ->
    it 'should getUser for a current user', (done) ->
      socket.emit 'apiCall', 'getUser', (err, userData) ->
        should.not.exist err
        userData.should.be.an('object')
        userData.email.should.be.equal user.email
        done()
          

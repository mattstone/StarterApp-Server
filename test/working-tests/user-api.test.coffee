should   = require('chai').should()
config   = require '../config/config.test.coffee'
request  = require 'request'
async    = require 'async'

# Start Setup App
app = {}
app.config   = require '../config/config.test.coffee'
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
apiEndPoint = app.config.apiEndPoint + ":" + String app.config.port + '/api/rest'

user        = null
adminUser   = null
password    = "P4thw0rd"
userAccessToken  = null
adminAccessToken = null

workingUser = null

describe 'User API', () ->

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

  it 'should have valid user and admin records', (done) ->
    should.exist user
    should.exist adminUser
    done()

  it 'should login user', (done) ->
    opts =
      url: appEndPoint + "/login"
      json: true
      body: { user: { email: user.email, password: password }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.user.should.be.an 'object'
      body.token.should.be.a 'string'
      userAccessToken = body.token
      done()

  it 'should login admin', (done) ->
    opts =
      url: appEndPoint + "/login"
      json: true
      body: { user: { email: adminUser.email, password: password }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.user.should.be.an 'object'
      body.token.should.be.a 'string'
      adminAccessToken = body.token
      done()

  it 'should not get users when not logged in', (done) ->
    opts =
      url: apiEndPoint + "/users"
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 404
      body.should.be.a 'string'
      done()

  it 'should get users for logged in user', (done) ->
    opts =
      url: apiEndPoint + "/users"
      json: true
      headers:
        access_token: userAccessToken

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.meta.should.be.an 'object'
      body.meta.total.should.equal 2
      body.meta.offset.should.equal 0
      body.meta.limit.should.equal 20
      body.users.should.be.an 'array'
      body.users.length.should.equal 2

      for user in body.users
        user.confirmed.should.equal yes
        user.email.should.be.a 'string'
      done()

  it 'should get users for logged in admin', (done) ->
    opts =
      url: apiEndPoint + "/users"
      json: true
      headers:
        access_token: adminAccessToken

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.meta.should.be.an 'object'
      body.meta.total.should.equal 2
      body.meta.offset.should.equal 0
      body.meta.limit.should.equal 20
      body.users.should.be.an 'array'
      body.users.length.should.equal 2

      for user in body.users
        user.confirmed.should.equal yes
        user.email.should.be.a 'string'
      done()

  it 'should not get user for not logged in user', (done) ->
    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 404
      body.should.be.a 'string'
      done()

  it 'should get user for logged in user', (done) ->
    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true
      headers:
        access_token: userAccessToken

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.user.should.be.an 'object'
      body.user.id.should.equal String workingUser.id
      done()

  it 'should not update user for not logged in user', (done) ->
    updatedUser =
      firstName: 'updated'

    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true
      body:
        user: updatedUser

    request.put opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 404
      body.should.be.a 'string'
      done()

  it 'should update user for logged in user', (done) ->
    updatedUser =
      firstName: 'updated'

    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true
      headers:
        access_token: userAccessToken
      body:
        user: updatedUser

    request.put opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.user.should.be.an 'object'
      body.user.id.should.equal String workingUser.id
      body.user.first_name.should.equal 'updated'
      done()

  it 'should not update user for different user', (done) ->
    updatedUser =
      firstName: 'updated'

    opts =
      url: apiEndPoint + "/users/#{adminUser.id}"
      json: true
      headers:
        access_token: userAccessToken
      body:
        user: updatedUser

    request.put opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 403
      body.should.be.a 'string'
      done()

  it 'should update different user for admin user', (done) ->
    updatedUser =
      firstName: 'updated again'

    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true
      headers:
        access_token: adminAccessToken
      body:
        user: updatedUser

    request.put opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.user.should.be.an 'object'
      body.user.id.should.equal String workingUser.id
      body.user.first_name.should.equal 'updated again'
      done()

  it 'should not delete user for not logged in user', (done) ->
    updatedUser =
      firstName: 'updated again'

    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true

    request.delete opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 404
      body.should.be.a 'string'
      done()

  it 'should not delete user for logged in user', (done) ->
    updatedUser =
      firstName: 'updated again'

    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true
      headers:
        access_token: userAccessToken

    request.delete opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 403
      body.should.be.a 'string'
      done()

  it 'should not delete user for admin user', (done) ->
    updatedUser =
      firstName: 'updated again'

    opts =
      url: apiEndPoint + "/users/#{workingUser.id}"
      json: true
      headers:
        access_token: adminAccessToken

    request.delete opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 403
      body.should.be.a 'string'
      done()

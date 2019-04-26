should   = require('chai').should()
config   = require '../config/config.test.coffee'
request  = require 'request'

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
apiEndPoint = app.config.apiEndPoint + ":" + String app.config.port

validEmail      = "matthieu.stone@gmail.com"
invalidEmail    = "nol"

validPassword   = "validPathword23!"
invalidPassword = "foo"

user              = null
confirmationCode  = null

describe 'User Create Login', () ->

  before (done) ->
    this.timeout = 30000
    done()

  after (done) ->
    this.timeout = 30000
    app.mongoose.connection.db.dropDatabase (err) ->
      done()

  it 'should not create user with no details', (done) ->

    opts =
      url: appEndPoint + "/signup"
      json: true

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should not create user without email', (done) ->
    opts =
      url: appEndPoint + "/signup"
      json: true
      body: {user: {password: validPassword }}

    request.post opts, (err, response, body) ->

      should.not.exist err

      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should not create user without password', (done) ->
    opts =
      url: appEndPoint + "/signup"
      json: true
      body: { user: { email: validEmail }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should not create user with invalid email', (done) ->
    opts =
      url: appEndPoint + "/signup"
      json: true
      body: { user: { email: invalidEmail, password: validPassword }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should create user with valid email and password', (done) ->
    opts =
      url: appEndPoint + "/signup"
      json: true
      body: { user: { email: validEmail, password: validPassword }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.user.should.be.an 'object'

      user = body.user
      user.email.should.equal validEmail
      user.createdAt.should.not.be.empty
      user.updatedAt.should.not.be.empty
      done()

  it 'should have salt and hash in user database record', () ->
    query = { email: validEmail }

    app.models.User.findOne query
    .then( (data) ->
      data.email.should.equal validEmail
      data.confirmed.should.equal false
      data.salt.should.not.be.empty
      data.hash.should.not.be.empty
      user = data
    )
    .catch( (err) ->
      should.not.exist err
    )

  it 'should have one QEmail Record', () ->
    app.models.QEmail.find()
    .then( (data) ->
      console.log ""
      data.length.should.equal 1
      data[0].emailToSend.should.equal 1
      data[0].users.length.should.equal 1
      String(data[0].users[0]).should.equal String(user.id)
      data[0].from.should.equal app.config.email.marketing
      data[0].custom.should.be.an 'object'
      data[0].custom.confirmationCode.should.be.a 'string'
      confirmationCode = data[0].custom.confirmationCode

      app.models.QEmail.deleteMany {}, (err, data) ->
        should.not.exist err
        data.ok.should.equal 1
        data.n.should.equal 1
    )
    .catch( (err) ->
      should.not.exist err
    )
  it 'should take some to let the QEmail delete finish', (done) ->
    for i in [0 .. 100000000]
      x = 1
    done()

  it 'should not login with empty email', (done) ->
    opts =
      url: appEndPoint + "/login"
      json: true
      body: { user: { email: "", password: validPassword }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should not login with invalid email', (done) ->
    opts =
      url: appEndPoint + "/login"
      json: true
      body: { user: { email: invalidEmail, password: validPassword }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should not login with invalid password', (done) ->
    opts =
      url: appEndPoint + "/login"
      json: true
      body: { user: { email: validEmail, password: invalidPassword }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should get confirmation error when attempting to login with valid password and email', (done) ->
    opts =
      url: appEndPoint + "/login"
      json: true
      body: { user: { email: validEmail, password: validPassword }}

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.error.should.be.a 'string'
      done()

  it 'should not confirm user email address without a confirmation code', (done) ->
    opts =
      url: appEndPoint + '/confirm/'
      json: true

    request.post opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal(404)
      done()

  it 'should not confirm user email address with invalid confirmation code', (done) ->
    opts =
      url: appEndPoint + "/confirm/" + "invalidConfirmationCode"
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.error.should.be.a 'string'
      done()

  it 'should not request a new confirmation code with an invalid email address', (done) ->
    opts =
      url: appEndPoint + "/resend-confirmation-code/asdfasdf"
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.error.should.be.a 'string'
      done()

  it 'should request a new confirmation code with a valid email address', (done) ->
    opts =
      url: appEndPoint + "/resend-confirmation-code/" + validEmail + "?test=true",
      json: true

    request.get opts, (err, response, body) ->
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      body.success.should.equal 'OK'
      done()

  it 'should have one QEmail Record', () ->
    app.models.QEmail.find()
    .then( (data) ->
      console.log ""
      data.length.should.equal 1
      data[0].emailToSend.should.equal 1
      data[0].users.length.should.equal 1
      String(data[0].users[0]).should.equal String(user.id)
      data[0].from.should.equal app.config.email.marketing
      data[0].custom.should.be.an 'object'
      data[0].custom.confirmationCode.should.be.a 'string'
      confirmationCode = data[0].custom.confirmationCode

      app.models.QEmail.deleteMany {}, (err, data) ->
        should.not.exist err
        data.ok.should.equal 1
        data.n.should.equal 1
    )
    .catch( (err) ->
      should.not.exist err
    )

  it 'should take some to let the QEmail delete finish', (done) ->
    for i in [0 .. 1000000000]
      x = 1
    done()

  it 'should confirm user email address', (done) ->
    opts =
      url: appEndPoint + "/confirm/" + confirmationCode
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.user.should.be.an 'object'
      done()

  it 'should have one QEmail Record', () ->
    app.models.QEmail.find()
    .then( (data) ->
      console.log ""
      data.length.should.equal 1
      data[0].emailToSend.should.equal 5
      data[0].users.length.should.equal 1
      String(data[0].users[0]).should.equal String(user.id)
      data[0].from.should.equal app.config.email.marketing

      app.models.QEmail.deleteMany {}, (err, data) ->
        should.not.exist err
        data.ok.should.equal 1
        data.n.should.equal 1
    )
    .catch( (err) ->
      console.log "Am I happening: 1"
      console.log err
    )

  it 'should take some to let the QEmail delete finish', (done) ->
    for i in [0 .. 1000000000]
      x = 1
    done()


  it 'should not send password reset email code with an invalid email address', (done) ->
    opts =
      url: appEndPoint + "/reset-password/asdfasdf"
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.error.should.be.a 'string'
      done()


  it 'should send password reset email code with a valid email address', (done) ->
    opts =
      url: appEndPoint + "/reset-password/" + validEmail
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.an 'object'
      should.not.exist body.error
      body.success.should.equal 'OK'
      done()

  it 'should have one QEmail Record', () ->
    app.models.QEmail.find()
    .then( (data) ->
      console.log ""
      data.length.should.equal(1);
      data[0].emailToSend.should.equal(3);
      data[0].users.length.should.equal(1);
      String(data[0].users[0]).should.equal(String(user.id));
      data[0].from.should.equal(app.config.email.marketing);

      app.models.QEmail.deleteMany {}, (err, data) ->
        should.not.exist err
        data.ok.should.equal 1
        data.n.should.equal 1
    )
    .catch( (err) ->
      console.log "Am I happening: 2"
      console.log err
      # should.not.exist err
    )

  # it 'should take some to let the QEmail delete finish', (done) ->
  #   for i in [0 .. 10000000]
  #     x = 1
  #   done()

  it 'should logout', (done) ->
    opts =
      url: appEndPoint + "/logout"
      json: true

    request.get opts, (err, response, body) ->
      should.not.exist err
      response.statusCode.should.equal 200
      body.should.be.a 'string'
      done()
###

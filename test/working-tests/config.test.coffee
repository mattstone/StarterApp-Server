should = require('chai').should()
config = require '../config/config.coffee'

describe 'Config', ->

  it 'should be sane', (done) ->
    config.appName.should.not.be.empty
    config.port.should.be.a 'number'
    config.appEndPoint.should.not.be.empty
    config.apiEndPoint.should.not.be.empty
    config.permissionLevels.should.be.an 'object'
    config.redis.should.be.an 'object'
    done()

  it 'should have valid permissionLevels', (done) ->
    config.permissionLevels.USER.should.be.a 'number'
    config.permissionLevels.SUBSCRIBER.should.be.a 'number'
    config.permissionLevels.ADMIN.should.be.a 'number'
    done()

  it 'should have valid redis', (done) ->
    config.redis.host.should.be.a 'string'
    config.redis.port.should.be.a 'number'
    config.redis.db.should.be.a 'number'
    done()

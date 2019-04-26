redis = require 'redis'
require('redis-delete-wildcard')(redis) # Note: Use with care
ms  = require 'ms'
EventEmitter = require('events').EventEmitter


module.exports = class RedisManager extends EventEmitter
  constructor: (@app) ->
    super()

    @d = "::" # delimiter
    @r = @createClient()
    @app.config.redis.db
    @r.select @app.config.redis.db
    @pub = @createClient()
    @sub = @createClient()

    @sub.psubscribe "feed#{@d}*"

    @sub.on 'pmessage', (pattern, channel, msg) =>
      type = switch pattern
        when "feed#{@d}*"  then 'feed'

      @emit type, JSON.parse msg

  createClient: ->
    redis.createClient()

  publish: (args...) -> @pub.publish.apply @pub, args

  exists: (key, cb) ->
    @r.exists key, (err, result) =>
      cb err, result

  addDelimiter: (array) ->
    string = ""
    for element in array
      string += String element
      string += @d
    string

  removeDelimiter: (string) ->
    string.split @d

  hmset: (key, hash, ttl, cb) ->
    @r.hmset key, hash, (err, response) =>
      @r.expire key, ttl
      cb(err, response)

  setAccessToken: (token, user, ttl, cb) ->
    key = @addDelimiter ['api', 'Token', token]
    hash =
      user:  user.id
      email: user.email
    @hmset key, hash, ttl, cb

  checkAccessToken: (token, cb) ->
    key = @addDelimiter ['api', 'Token', token]
    @r.hgetall key, cb

  setConfirmationCode: (user, confirmationCode, ttl, cb) ->
    key  = @addDelimiter ["cCode", confirmationCode]
    hash = { user: user.id }
    @hmset key, hash, ttl, cb

  getConfirmationCode: (confirmationCode, cb) ->
    key = @addDelimiter ["cCode", confirmationCode]
    @r.hgetall key, cb

  setUserEmail: (user, ttl, cb) ->
    key  = @addDelimiter ["email", user.email]
    hash = { id: String(user.id) }
    @hmset key, hash, ttl, cb

  getUserByEmail: (email, cb) ->
    key = @addDelimiter ["email", email]
    @r.hgetall key, cb

  setModel: (name, model, ttl, cb) ->
    key  = @addDelimiter [name, String(model.id)]
    hash = { model: JSON.stringify(model)}
    @hmset key, hash, ttl, cb

  getModel: (name, id, cb) ->
    key = @addDelimiter [name, String(id)]
    @r.get key, (err, data) ->
      if err then cb(err, null) else cb err, JSON.parse(data)

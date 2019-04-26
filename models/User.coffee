helpers    = require '../lib/helpers.coffee'
mongoose   = require 'mongoose'
crypto     = require 'crypto'
validator  = require 'validator'
emailValidator  = require 'email-validator'

BaseSchema = require './BaseSchema.coffee'

User      = new BaseSchema
User.name = "user"

User.add {firstName:  { type: String,  required: false }}
User.add {lastName:   { type: String,  required: false }}
User.add {confirmed:  { type: Boolean, required: true, default: false }}
User.add {email:      { type: String,  required: true, unique: true, index: true, lowercase: true }}
User.add {password:   { type: String,  required: false }}
User.add {hash:       { type: String,  required: true }}
User.add {salt:       { type: String,  required: true }}
User.add {permission: { type: Number,  required: true, default:  1}}
User.add {isSuspended:{ type: Boolean, required: true, default: false }}

# Statics

validatePassword = (password) ->
  validator.matches(password, /([a-z]|[A-Z])+[0-9]/) && validator.isLength(password, 6)

validateEmail = (email) ->
  emailValidator.validate email.toLowerCase()

User.statics.create = (data, cb) ->

  if  !validateEmail data.email
    cb 'Please use a valid email address.', null
  else if !validatePassword data.password
    cb 'Your password should be at least 6 letters and contain 1 number.', null
  else
    user = new Users { email: data.email }
    user.setPassword data.password
    user.permission = data.permission if data.permission?
    user.save (err) ->
      cb err, user

User.statics.validateEmail = (email) ->
  emailValidator.validate email.toLowerCase()

User.statics.findByEmail = (email) ->
  user.find { email: email.toLowerCase()  }

# Methods

User.methods.toJSON = () ->   # do not send secret data via api
  user = this.toObject()
  delete user.salt
  delete user.hash
  #delete user.permission
  user

User.methods.setPassword = (password) ->
  @salt = crypto.randomBytes(16).toString 'hex'
  @hash = crypto.pbkdf2Sync(password, this.salt, 10000, 512, 'sha512').toString 'hex'

User.methods.validatePassword = (password) ->
  return @hash == crypto.pbkdf2Sync(password, @salt, 10000, 512, 'sha512').toString 'hex'

User.methods.confirmationCode = () ->
  helpers.createId()

User.methods.confirmUser = () ->
  @confirmed = true
  @save()

User.methods.isAdmin = () ->
  this.permission > 1000

User.post 'save', (doc) ->
  Users.r.setUserEmail doc, Users.config.redis.ttl, (err, data) ->

  Users.r.setModel 'user', doc, Users.config.redis.ttl, (err, data) ->

Users = mongoose.model User.name, User

module.exports = (config, redis) ->
  Users.config = config
  Users.r = redis
  Users

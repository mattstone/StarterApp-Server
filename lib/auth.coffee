passport         = require 'passport'
LocalStrategy    = require('passport-local').Strategy
#OAuthStrategy    = require('passport-oauth2').Strategy
helpers = require './helpers'
url     = require 'url'
util    = require 'util'

module.exports = (app) ->
  exp  = app.exp
  User = app.models.User

  passport.serializeUser (user, cb)-> cb null, user.id

  passport.deserializeUser (id, cb) ->
    User.findById id, (err, user)->
      cb err, user

  passport.use new LocalStrategy usernameField: 'user[email]', passwordField: 'user[password]', (email, password, cb) ->
    query =
      email: email.toLowerCase()

    User.findOne query, (err, user) ->
      return cb err if err
      return cb 'Invalid email and password combination', null unless user
      return cb 'Invalid email and password combination', null unless user.validatePassword password
      return cb 'Sorry, but your account is suspended',   null if user.isSuspended
      return cb 'You need to confirm your email',         null unless user.confirmed is true
      cb err, user

  exp.use passport.initialize()
  exp.use passport.session()

  exp.ensureAuthenticated = (req, res, next)->
    return next() if req.isAuthenticated()
    res.redirect '/'

  exp.adminsOnly = (req, res, next) ->
    return next() if req.user? and req.user.isAdmin
    res.send 403

  # auth by token
  exp.use (req, res, next) ->
    query = url.parse(req.url, true).query

    # token = req.body.access_token or query.access_token
    token = req.headers.access_token

    if token?
      req.logout()
      app.r.checkAccessToken token, (err, hash) ->
        if hash? and hash.user?
          User.findById hash.user, (err, user) ->
            req.login user, (err) ->
              next()
        else
          next()
    else
      next()

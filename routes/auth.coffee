passport = require('passport');

module.exports = (app) ->
  exp        = app.exp
  helpers    = app.helpers

  exp.post '/login', (req, res) ->
    if !req.body.user?             then return res.json { error: "invalid email and password combination", user: null }
    if !req.body.user["email"]?    then return res.json { error: "invalid email and password combination", user: null }
    if !req.body.user["password"]? then return res.json { error: "invalid email and password combination", user: null }

    if req.body.user["email"] is '' or req.body.user["password"] is ''
      return res.json { error: "invalid email and password combination", user: null }

    auth = (err, user, info) ->
      return res.send error: err if err
      return res.send error: info unless user

      token = helpers.createId()
      ttl   = (60 * 60 * 24) * 2 # 48 hours

      app.r.setAccessToken token, user, ttl, (err, response) ->
        if err? then return res.send { error: err}

        req.logIn user, (err) ->
          if err? then return res.send { error: String err }
          return res.send { user: user.toJSON(), token: token }

    passport.authenticate('local', auth)(req, res)

  exp.get '/logout', (req, res) ->
    req.logout()
    res.send 'Logged Out'

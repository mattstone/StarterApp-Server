path = require 'path'
fs   = require 'fs'

module.exports = (app) ->
  exp        = app.exp
  User       = app.models.User
  isEmpty    = app.helpers.isEmpty
  isNotEmpty = app.helpers.isNotEmpty

  exp.post '/signup', (req, res) ->
    # validate form
    user = req.body.user

    if !user?             then return res.json { error: 'invalid request' }
    if !user["email"]?    then return res.json { error: 'email is required' }
    if !user["password"]? then return res.json { error: 'password is required' }

    data =
      email:    user["email"]
      password: user["password"]

    User.create data, (err, user) ->
      if err
        res.json { error: err, user: null }
      else
        confirmationCode = user.confirmationCode()
        app.r.setConfirmationCode user, confirmationCode, app.config.email.confirmationCodeTTL, (err, data) ->
          app.models.QEmail.sendConfirmationEmail user, app.config.email.marketing, confirmationCode
          res.json { error: err, user: user.toJSON() }

  exp.get '/confirm/:confirmationCode', (req, res) ->
    if !req.params or !req.params.confirmationCode
      return res.json { error: 'Invalid confirmation code', user: null }
    else
      app.r.getConfirmationCode req.params.confirmationCode, (err, data) ->
        if err
          return res.json { error: 'There was a problem. Please try again later', user: null }
        else if !data || !data.user
          return res.json { error: 'This confirmation code is invalid. Please request another', user: null }
        else
          query =
            _id: data.user

          app.models.User.findOne query, (err, user) ->
            if err
              return res.json { error: 'There was a problem. Please try again later', user: null }
            else if !user
              return res.json { error: 'This confirmation code is invalid. Please request another', user: null }
            else
              user.confirmUser()
              app.models.QEmail.sendWelcomeEmail(user, app.config.email.marketing);
              return res.json { error: 'null', user: user.toJSON() }

  exp.get '/resend-confirmation-code/:email', (req, res) ->
    if !req.params or !req.params.email
      return res.json { error: 'Invalid resend confirmation code request: 1', user: null }
    else
      # test email exists in redis - much faster and does not hit DB for false requests
      app.r.getUserByEmail req.params.email, (err, data) ->
        if err
          return res.json { error: err, success: null }
        else if !data
          return res.json { error: 'Invalid resent confirmation code request: 2', success: null }
        else
          query = { _id: data.id }
          app.models.User.findOne query, (err, user) ->
            confirmationCode = user.confirmationCode()
            app.r.setConfirmationCode user, confirmationCode, app.config.email.confirmationCodeTTL, (err, data) ->
              app.models.QEmail.sendConfirmationEmail user, app.config.email.marketing, confirmationCode
              res.json { error: err, success: 'OK' }

  exp.get '/reset-password/:email', (req, res) ->
    if !req.params or !req.params.email
      return res.json { error: 'Invalid reset password code request: 1', user: null }
    else
      # test email exists in redis - much faster and does not hit DB for false requests
      app.r.getUserByEmail req.params.email, (err, data) ->
        if err
          return res.json { error: err, success: null }
        else if !data
          return res.json { error: 'Invalid reset password code request: 2', success: null }
        else
          query = { _id: data.id }
          app.models.User.findOne query, (err, user) ->
            if err or !user
              return res.json { error: 'Invalid resend confirmation code request: 3', success: null }
            else
              app.models.QEmail.sendResetPasswordEmail user, app.config.email.marketing
              res.json { error: err, success: 'OK' }

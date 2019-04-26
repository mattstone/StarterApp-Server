helpers    = require '../lib/helpers.coffee'
mongoose   = require 'mongoose'
Schema     = require('mongoose').Schema

BaseSchema = require './BaseSchema.coffee'

QEmail  = new BaseSchema
QEmail.name = "qemail"

QEmail.emails =
  "ConfirmEmail" : 1
  "ResendConfirmEmail" : 2
  "ResetPassword" : 3
  "Welcome"       : 5

QEmail.add { users:         { type: [Schema.Types.ObjectId], required: false }} # send to site users
QEmail.add { to:            { type: [String],   required: false }} # send to non site users
QEmail.add { from:          { type: String,     required: true }}
QEmail.add { emailToSend:   { type: Number,     required: true }}
QEmail.add { custom:        { type: Object,     required: false, default: {} }}
QEmail.add { sendAfterDate: { type: Date,     default: Date.now()}}

QEmail.statics.sendConfirmationEmail = (user, from, confirmationCode) ->
  custom = { confirmationCode: confirmationCode }
  qemail = new QEmails { users: [user.id], from: from, emailToSend: QEmail.emails["ConfirmEmail"], custom: custom }
  qemail.save (err) ->


QEmail.statics.sendWelcomeEmail = (user, from) ->
  qemail = new QEmails({ users: [user.id], from: from, emailToSend: QEmail.emails["Welcome"] })
  qemail.save (err) ->

QEmail.statics.sendResetPasswordEmail = (user, from) ->
  qemail = new QEmails { users: [user.id], from: from, emailToSend: QEmail.emails["ResetPassword"] }
  qemail.save (err) ->

QEmails = mongoose.model QEmail.name, QEmail

module.exports = (config, redis) ->
  QEmails.config = config
  QEmails.r = redis
  QEmails

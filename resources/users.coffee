util = require 'util'

module.exports =
  before: (method, req, res, next) ->
    if method in ['create', 'destroy']
      # return res.send 403 unless req.user? and req.user.isAdmin()
      return res.send 403
    next()

  index: (req, res) ->
    req.dbQueryOpts.sort ?= created: -1
    @findAndSend req, res

  show: (req, res) ->
    cb = @sendJSON req, res

    # if req.query.initialiseBadgeNumber?
    #   initialiseBadgeNumber = true
    #   delete req.dbQuery.initialiseBadgeNumber

    @model.findOne req.dbQuery, (err, user) ->
      # if initialiseBadgeNumber? && user?
      #   user.initialiseBadgeNumber()
      cb null, user

  create: (req, res)  ->
    req.doc.save (err) => @sendJSON(req, res)(err, req.doc)

  update: (req, res)  ->
    req.dbQuery._id = req.user._id unless req.user.isAdmin
    update = @camelizeObject(req.body[@model_name])

    cb = @sendJSON req, res

    @model.findOne req.dbQuery, (err, doc) ->
      return cb err if err?

      # security check - user cannot update another user, unless admin
      if req.user.id isnt doc.id and !req.user.isAdmin()
        return res.send 403

      doc[key] = value for key, value of update
      doc.save (err) ->
        return cb err if err?
        cb null, doc

  destroy: (req, res) ->
    @model.remove req.dbQuery, (err, reply) ->
      res.send user: null

inflection = require "inflection"
h          = require('./helpers')
ObjectId   = require('mongoose').Schema.Types.ObjectId
mongoose   = require 'mongoose'
typeOf     = h.type
util       = require 'util'

propsToRemove = ['_id', '__v', 'password', 'hash', 'salt']

module.exports = class ResourceController
    constructor: (@app, @modelName, @methods = {}) ->
      @setModel()

    setModel: ->
      @idName = '_id'
      @model = @app.models[@modelName]
      @model_name = inflection.underscore @modelName
      @model_name_plural = inflection.pluralize @model_name

      @restNamesList = []
      @restNames = {}
      @restNamesRev = {}

      @rels =
        one2one: []
        one2many: []

      for name, value of @model.schema.tree
        @idName = name if value.alias? and value.alias is 'id'
        if value.restName?
          @restNames[name] = value.restName
          @restNamesRev[value.restName] = name
          @restNamesList.push value.restName

        type = if h.type(value) is 'object' then value.type else value

        if type is ObjectId and name isnt '_id'
          @rels.one2one.push name
        else if h.type(type) is 'array' and type[0]?.ref?
          @rels.one2many.push name

    getResource: ->
      controller = @
      index:   (req, res) -> controller.invoke 'index',   req, res
      show:    (req, res) -> controller.invoke 'show',    req, res
      create:  (req, res) -> controller.invoke 'create',  req, res
      update:  (req, res) -> controller.invoke 'update',  req, res
      destroy: (req, res) -> controller.invoke 'destroy', req, res

    invoke: (method, req, res) ->
      return res.sendStatus 404 unless @methods[method]?

      if req.isAuthenticated()
        @authenticated method, req, res
      else
        # Not authenticated, so check access_token
        token = req.headers.access_token

        # Note - strip extra , which is added by NSMutableURL
        if token?
          # token = token.slice(1) if token.charAt(0) is ","
          arr   = token.split(",")
          token = arr[0]

        return res.sendStatus 404 unless token? and token

        @app.r.checkAccessToken token, (err, hash) =>

          if hash?  # Add the user to the request.
            query =
              email: hash.email.toLowerCase()
              base:  hash.app

            @app.models.User.findOne query, (err, user) =>
              if err?
                return res.sendStatus 403
              req.user = user
              @authenticated method, req, res
          else
            return res.sendStatus 403

    authenticated: (method, req, res) =>
      @before method, req, res, =>
        @methods[method].apply @, [req, res]

    before: (method, req, res, next) ->

      if method is 'index'

        # TODO: relationship queries
        #add relationship queries
        # for key, value of req.dbQuery
        #   if key.substring(0,4) == "rel_"
        #     delete req.dbQuery[key]
        #     req.dbQuery[key.replace("rel_", "")] = { $eq : mongoose.Types.ObjectId value }
        #     #req.dbQuery[key.replace("rel_", "")] = { $eq : value }

        if req.dbQuery.ids?
          req.dbQuery[@idName] = req.dbQuery.ids
          delete req.dbQuery.ids

        unless req.dbQueryOpts.limit? and req.dbQueryOpts.limit < 50
          unless req.user? and req.user.isAdmin
            req.dbQueryOpts.limit = 50

      if method in ['show', 'update']
        req.dbQuery[@idName] = req.params[@model_name]

      if method is 'create'
        if req.body[@model_name_plural]?
          req.isBatch = yes
        else
          req.isBatch = no
          req.doc = new @model @deserialize req.body[@model_name]

      if method is 'destroy'
        req.dbQuery._id = req.params[@model_name]

      if @methods.before?
        @methods.before.apply @, [method, req, res, next]
      else
        next()

    serialize: (data = []) ->
      for doc in data when doc?

        d = if doc.toJSON? then doc.toJSON() else doc
        d.id = d[@idName]

        d["#{name}_id"] = d[name] for name in @rels.one2one
        for name in @rels.one2many
          newName = inflection.underscore inflection.singularize name
          d["#{newName}_ids"] = JSON.parse JSON.stringify d[name]

        delete d[name] for name in propsToRemove.concat @rels.one2one.concat @rels.one2many

        for name, restName of @restNames
          d[restName] = d[name]
          delete d[name]

        h.underscoreObject d

    sendJSON: (req, res, meta, custom) -> (err, data) =>
      return res.json error: err if err?

      isSingle = no

      unless Array.isArray data
        data     = [data]
        isSingle = yes

      data = @serialize data

      json = {}
      json.meta   = meta   if meta?
      json.custom = custom if custom?

      if isSingle
        json[@model_name] = data[0] or null
      else
        json[@model_name_plural] = data

      res.json json

    findAndSend: (req, res, custom) ->
      @model.count req.dbQuery, (err, total) =>
        return res.json error: err if err?

        meta =
          total:  total
          offset: req.dbQueryOpts.skip  or 0
          limit:  req.dbQueryOpts.limit or 20

        @model.find req.dbQuery, req.minusFields, req.dbQueryOpts, @sendJSON req, res, meta, custom

    camelizeObject: (obj) -> @deserialize obj

    deserialize: (obj) ->
      if typeOf(obj) is 'array'
        return (@deserialize o for o in obj)

      newObj = h.camelizeObject obj

      for name, restName of @restNames when newObj[restName]?
        newObj[name] = newObj[restName]
        delete newObj[restName]
      newObj

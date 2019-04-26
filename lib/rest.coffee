h = require('./helpers')
fetchFiles = h.fetchFiles
typeOf = h.type
inflection = require "inflection"
util = require 'util'

ResourceController = require './ResourceController'

module.exports = (app) ->
  exp = app.exp

  # parse request query
  exp.use '/api/rest' , (req, res, next) ->

    ###

    MQL cannot send PUT requests..

    So hack here.. if POST and req.body.method = "PUT"
      then change to put

    ###

    if req.method? and req.body.method?
      if req.method.toUpperCase() is "POST" and req.body.method.toUpperCase() == "PUT"
        req.method = "PUT"

      if req.method.toUpperCase() is "PATCH"
        req.method = "PUT"

    req.dbQuery     = {}
    req.dbQueryOpts = {}
    req.minusFields = {}

    if req.query.access_token?
      req.access_token = req.query.access_token
      delete req.query.access_token

    if req.query.limit?
      req.dbQueryOpts.limit = Number req.query.limit
      delete req.query.limit

    if req.query.skip?
      req.dbQueryOpts.skip = Number req.query.skip
      delete req.query.skip

    if req.query.sort?
      req.dbQueryOpts.sort = if typeOf(req.query.sort) is 'object'
        sort = {}
        sort[key]= 1 for key, value of req.query.sort when value in ['asc', 'ascending', '1', 1, 'ASC', 'ASCENDING']
        sort[key]= -1 for key, value of req.query.sort when value in ['desc',  'descending', '-1',-1, 'DESC', 'DESCENDING']
        sort
      else req.query.sort
      delete req.query.sort

    if req.query.minusFields?
      fields = req.query.minusFields.split ' '
      delete req.query.minusFields
      req.minusFields[f] = 0 for f in fields

    if req.query.startsWithProp? and req.query.startsWithStr?
      req.dbQuery[req.query.startsWithProp] = new RegExp("^#{req.query.startsWithStr}.*")
      delete req.query.startsWithProp
      delete req.query.startsWithStr

    for key, value of req.query when typeOf(value) is 'array'
      req.dbQuery[key] = $in: (v for v in value when typeOf(v) is 'string')
      delete req.query[key]

    req.dbQuery[name] = value for name, value of req.query
    next()

  # load model controllers
  addResource = (name, modelName, filepath = './BaseResource') ->
    controller = new ResourceController app, modelName, require filepath
    exp.resource "api/rest/#{name}", controller.getResource()
    app["#{modelName}RestController"] = controller

  for r in fetchFiles __dirname + '/../resources'
    name = r.split('/').pop().split('.')[0]
    modelName = inflection.camelize inflection.singularize name

    inflection.camelize inflection.singularize(name)
    addResource name, modelName, r

  for modelName of app.models when not app["#{modelName}RestController"]?
    name = inflection.underscore inflection.pluralize modelName
    addResource name, modelName

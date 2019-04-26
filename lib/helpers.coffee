rack       = require('hat').rack()
findit     = require 'findit'
path       = require 'path'
moment     = require "moment"
inflection = require 'inflection'
util       = require 'util'

# Crypto
algorithm = "aes-256-ctr"
password = 'J0hn31!^F0rG0dS0L0v#dTh#W)Rld'

module.exports.loadAll = (that) ->
  that[key] ?= @[key] for key in keysOf @

module.exports.isBuffer = isBuffer = require('buffer').Buffer.isBuffer

module.exports.basename = basename = (filename) ->
  path.basename filename, '.coffee'

module.exports.coffeescriptFiles = coffeescriptFiles = (files) ->
  coffeeFiles = []

  for element in files
    array    = element.split '/'
    filename = array[array.length - 1]
    array    = filename.split '.'
    ext      = array[array.length - 1].toLowerCase()
    if ext is 'coffee' then coffeeFiles.push element
  coffeeFiles


module.exports.filesInDirectory = filesInDirectory = (folder) ->
  files = []
  path = require("path").join __dirname, folder
  require("fs").readdirSync(path).forEach (file) ->
    files.push(path + file)
  files


module.exports.fetchFiles = fetchFiles = (folder, ext = 'coffee') ->
  basedir = if folder[0] is '/'
      folder
    else if module.parent?
      path.dirname(module.parent.filename) + '/' + folder
    else __dirname+'/'+folder

  files = findit.sync basedir
  if ext
    files.filter (f) -> f.indexOf(".#{ext}") > 0
  else files

module.exports.debug = (data) ->
  console.log "debug: #{util.inspect data}"

module.exports.loadMessages = (that = {}) ->
  that[basename file] = require file for file in fetchFiles __dirname+'/messages'
  that

module.exports.makeArray = (data)->
  if Array.isArray data
    data
  else if data?
    [data]
  else []

module.exports.createId = -> rack()

module.exports.keysOf = keysOf = Object.keys

module.exports.sortObject = (obj) ->
  sorted = {}
  sorted[key] = obj[key] for key in keysOf(obj).sort()
  sorted

module.exports.workingDays = (startDate, endDate) ->
  datesArray = []
  return datesArray if startDate > endDate # Sanity check

  while (startDate <= endDate)
    day = startDate.getDay()
    datesArray.push new Date(startDate.getTime()) if day != 0 and day != 6  # No trading occurs on saturdays & sundays
    startDate.setDate(startDate.getDate() + 1)
  datesArray

module.exports.startOfDay = (date) ->
  startDate = new Date(date.getTime())
  startDate.setHours 0,0,0,0

module.exports.endOfDay = (date) ->
  endDate = new Date(date.getTime())
  endDate.setHours 23,59,59,999

module.exports.type = type = (obj) ->
  if obj == undefined or obj == null
    return String obj
  classToType = new Object
  for name in "Boolean Number String Function Array Date RegExp".split(" ")
    classToType["[object " + name + "]"] = name.toLowerCase()
  myClass = Object.prototype.toString.call obj
  if myClass of classToType
    return classToType[myClass]
  return "object"

module.exports.md5 = md5 = (str) ->
  require('crypto').createHash('md5').update(str).digest("hex")

module.exports.encrypt = encrypt = (str) ->
  crypto   = require('crypto')
  cipher   = crypto.createCipher(algorithm, password)
  crypted  = cipher.update str, 'utf8', 'hex'
  crypted += cipher.final 'hex'
  crypted

module.exports.decrypt = decrypt = (str) ->
  crypto = require('crypto')

  decipher = crypto.createDecipher(algorithm, password)
  dec = decipher.update str, 'hex', 'utf8'
  dec += decipher.final 'utf8'
  dec

module.exports.randomString = randomString = (possible, len = 6)->
  text = ''
  for i in [1..len]
    text += possible.charAt(Math.floor(Math.random() * possible.length))
  text

module.exports.getSolt = getSolt = (len = 6) ->
  possible = "_!@#$%^&*~.,?|ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  randomString possible, len

module.exports.isEmpty = (_object) -> Object.keys(_object).length == 0

module.exports.loadModels = (app) ->
  models = {}
  files = fetchFiles __dirname + '/../models/'
  files.forEach (file) ->
    modelName = basename file
    if modelName.substring(0, 4) isnt "Base"
      models[modelName] = require(file)(app.config, app.r)
  models

module.exports.defaults = defaults = (obj, defaultObjs...) ->
  for source in defaultObjs
    for prop of source
      if not obj[prop]?
        obj[prop] = source[prop]
      else
        if type(source[prop]) is 'object'
          obj[prop] = defaults obj[prop], source[prop]
  obj

module.exports.getConfig = (env = '') ->
  env = ".#{env}" if env.length
  config = require "#{__dirname}/../config/config#{env}"
  defaults config, require "#{__dirname}/../config/config.defaults"

module.exports.clone = clone = (obj) ->
  return obj if not obj? or typeof obj isnt 'object'
  return new Date(obj.getTime()) if obj instanceof Date

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags)

  newInstance = new obj.constructor()

  newInstance[key] = clone obj[key] for key of obj

  return newInstance

module.exports.parseDate = parseDate = (date, format = "YYYY-MM-DD") ->
  return unless date?
  moment.utc(date, format).toDate()

module.exports.requireFolder = (path, ns = null) ->
  modules = {}

  fetchFiles(path).forEach (file) ->
    name = basename file
    modules[name] = if ns? then require(file)(ns) else require(file)
  modules


module.exports.underscoreObject = underscoreObject = (orig) ->
  orig = orig.toObject() if orig.toObject?
  result = {}

  for name, value of orig when value?
    if name is 'id' or name[-3..] is '_id'
      if name[-3..] is '_id'
        name = inflection.underscore(name[...-3]) + '_id'
      result[name] = value.toString()
    else
      if type(value) is 'object'
        value = underscoreObject value

      if type(value) is 'array'
        value = for v in value
          if type(v) is 'object'
            v = v.toObject() if v.toObject?
            v = underscoreObject v
          v

      resName = inflection.underscore name
      resName = 'option_otc' if name is 'optionOTC'
      result[resName] = value
  result

module.exports.camelizeObject = camelizeObject = (orig) ->
  result = {}
  for name, value of orig
    value = camelizeObject value if type(value) is 'object'
    if type(value) is 'array'
      value = for v in value
        if type(v) is 'object'
          v = camelizeObject v
        v

    resName = inflection.camelize name, true
    resName = 'optionOTC' if name is 'option_otc'
    result[resName] = value
  result

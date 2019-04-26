path           = require 'path'
express        = require 'express'
cors           = require 'cors'
require 'express-resource'
compression    = require 'compression'
cookieParser   = require 'cookie-parser'
bodyParser     = require 'body-parser'
methodOverride = require 'method-override'
session        = require 'express-session'
RedisStore     = require('connect-redis')(session)
path           = require 'path'
logger         = require 'morgan'
errorHandler   = require 'errorhandler'

http  = require 'http'
https = require 'https'
fs    = require 'fs'

module.exports = (app, ready = ->) ->
  helpers = app.helpers
  app.exp = exp = express()
  app.sessionStore = new RedisStore()

  app.publicPath = publicPath = path.resolve __dirname, "./public"

  exp.use compression()
  exp.use cookieParser()
  exp.use methodOverride()

  exp.use session(
    secret: app.config.session.secret
    store: app.sessionStore
    resave: true
    saveUninitialized: true)

  exp.use(bodyParser.json { limit: '50mb', type: 'application/json' })
  exp.use(bodyParser.urlencoded({
    limit:    '50mb',
    extended: true,
    parameterLimit: 50000
  }))

  require('./auth.coffee')(app)

  exp.use cors()
  exp.use express.static(publicPath)
  exp.use require('morgan')('dev')

  exp.use (req, res, next) ->
    res.locals.csrf = req.session._csrf

    res.header 'Access-Control-Allow-Origin',         '*'
    res.header 'Access-Control-Allow-Credentials', 'true'
    res.header 'Access-Control-Allow-Methods',  'GET,HEAD,PUT,PATCH,POST,DELETE'
    res.header 'Access-Control-Expose-Headers', 'Content-Length'
    res.header 'Access-Control-Allow-Headers',  'Accept,Authorization,Content-Type,X-Requested-With,Range'

    if req.method is 'OPTIONS' then return(res.send 200) else next()

  require('./rest')(app)

  # attach routes
  routes = helpers.coffeescriptFiles(helpers.filesInDirectory '../routes/')
  for route in routes
    require(route)(app)
    route = route.split '/'
    console.log "loading route: " + route[route.length - 1].replace '.coffee', ''

  app.httpServer = http.createServer(exp).listen app.config.port, "::", () ->
      console.log app.config.appName + " alive and listening on port: " + String(app.config.port)

sio       = require 'socket.io'
typeOf    = require 'typeof'
parse     = require("cookie").parse
util      = require 'util'
cookieParser = require 'cookie-parser'

module.exports = (app) ->

  setApi = (socket, name) ->
    require("./socketApis/#{name}")(app, socket)

  User = app.models.User

  io = app.sio = sio.listen app.httpServer

  io.use (socket, cb) ->
    return cb null, true unless socket.request.headers.cookie

    # parse cookie for sid
    cookies = parse(socket.request.headers.cookie)

    #return cb false, "error" if !cookies['connect.sid']?  # Fail if no sid - TODO: why
    #sid = cookieParser.signedCookie cookies['connect.sid'], app.config.session.secret
    sid = ""
    if cookies['connect.sid']?
      sid = cookieParser.signedCookie cookies['connect.sid'], app.config.session.secret

    app.sessionStore.get sid, (err, session) ->
      return cb null, true unless session?
      return cb null, true unless session? and session.passport?
      return cb null, true unless session? and session.passport.user?

      User.findById session.passport.user, (err, user) ->
        if err
          cb false, "error"

        socket.session = session
        socket.user = user
        cb null, true

  io.sockets.on 'connection', (socket) ->
    socket.api        ?= {}
    socket.apiMethods ?= []

    setApis = ->
      setApi socket, 'user'

      if socket.user.isAdmin
        setApi socket, 'admin'
        socket.join "admins"

    if socket.user?
      setApis()

    socket.apiMethods.push 'loginWithToken'

    socket.api.loginWithToken = (token, cb = ->) ->

      app.r.checkAccessToken token, (err, hash) ->
        if hash? and hash.user?
          User.findById hash.user, (err, user) ->
            if socket.user = user
              setApis()
              cb null, user
              socket.emit 'apiMethods', socket.apiMethods
            else
              socket.disconnect()
        else
          socket.disconnect()

    socket.emit 'apiMethods', socket.apiMethods

    # api calls from browser
    socket.on 'apiCall', (method, args...) ->
      # app.logger.debug "apiCall: 1: #{method}, #{util.inspect args}"
      # app.logger.debug socket.apiMethods

      unless method in socket.apiMethods
        # unless app.isTesting()
        #   app.logger.error "Method '#{method}' not found"

        if typeOf(args[args.length-1]) is 'function'
          args[args.length-1]
            code: "methodNotFound"
            message: "Method '#{method}' not found"
        return null

      api = socket.api
      api[method].apply api, args

      return null

    # socket.on 'subscribeToChart', (feedId) -> socket.join "chart"
    # socket.on 'subscribeToFeed',  (feedId) -> socket.join "feed:#{feedId}"
    #
    # socket.on 'getFeedPosts', (data, cb = ->) ->
    #   opts =
    #     limit: data.limit
    #     sort:
    #       created: -1
    #   FeedPost.find({feed: data.feed}, null, opts).populate('author', postAuthorFields).exec cb

  # app.r?.on 'feedUpdate', (msg) -> io.sockets.in("feed:#{msg.feed}").emit 'feedUpdate', msg
  # app.r?.on 'admin',      (msg) -> io.sockets.in("admins").emit 'admin', msg
  # app.r?.on 'chart',      (msg) -> io.sockets.in("chart").emit 'chart',  msg

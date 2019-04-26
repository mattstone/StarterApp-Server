fs = require 'fs'
# twitter = require 'ntwitter'
path = require 'path'

# makes compatability with Node.js v0.6.*
isExists = (file, cb) ->
  ver = process.versions.node.split('.')[1]
  if ver >= 8
    fs.exists file, cb
  else
    path.exists file, cb


module.exports = (app, socket) ->
  User = app.models.User
  Post = app.models.Post
  # twit = new twitter app.config.twitter

  api =
    getResourcesList: (cb) ->
      cb (model for model of app.models)

    rest: (req, cb) ->
      model = app.models[req.resource]

      if req.resource is 'FeedPost' and req.method is 'create'
        callback = cb
        cb = (err, model) ->
          callback err, model


          User.findById model.author, app.config.postAuthorFields, (err, author) ->
            m = model.toObject()
            m.author = author
            app.r.publish "feedUpdate::#{model.feed}", JSON.stringify m

      if req.args?
        req.args.push cb
        model[req.method].apply model, req.args
      else
        model[req.method](req.params, cb)

    searchByEmail: (query, cb)->
      reg = new RegExp(".*#{query}.*", "i")
      User.find {email: reg}, cb

    mail: (msg, cb)-> app.mail.plain msg, cb
    createBlogPost: (data, cb) ->
      app.r.getNewBlogPostId (err, id)->
        return cb err if err?
        data.numId = id
        Post.create data, cb
    tweet: (msg,cb)->
      console.log "tweet disabled.."
      # twit.updateStatus msg, cb

    getConfig: (cb)->
      app.config.web.cdn = app.config.s3.host
      cb
        hostname: app.config.web.hostname
        port: app.config.web.port
        cdn: app.config.s3.host

    uploadFile: (file, data, cb) ->
      lastModifiedDate = if file.lastModifiedDate? then new Date(file.lastModifiedDate) else new Date
      modified = lastModifiedDate.getTime().toString(36)
      fileName = "#{modified}_#{file.name}"
      assetsPath = path.resolve __dirname, '../../webapp/public/assets'

      handleError = (err) ->
        app.logger.error err
        cb null

      save = ->
        filePath = "#{assetsPath}/#{fileName}"
        data = new Buffer data
        fs.writeFile filePath, data, (err) ->
          if err? then handleError err else cb(fileName)

      isExists assetsPath, (exists) ->
        if exists then save()
        else fs.mkdir assetsPath, (err) ->
          if err? then handleError err else save()

  for name, method of api
    socket.api[name] = method
    socket.apiMethods.push name

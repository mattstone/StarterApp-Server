
module.exports = (app, socket)->
  User = app.models.User
  UserFollow = app.models.UserFollow

  api =
    getUser: (user, cb) ->
      if arguments.length is 1
        [user, cb] = [socket.user, arguments[0]]

      User.findById(user).lean().exec (err, doc) ->
        return cb code: 'userNotFound' unless doc?
        cb null, doc

    getUsers: (users, cb) ->
      User.where("_id").in(users).lean().exec cb

    follow: (user, cb) ->
      socket.user.follow user, (err) -> cb err

    unfollow: (user, cb) ->
      socket.user.unfollow user, (err) -> cb err

    getFollowers: (user, cb) ->
      if arguments.length is 1
        [user, cb] = [socket.user, arguments[0]]

      UserFollow.getFollowers user, cb

    getFollowing: (user, cb) ->
      if arguments.length is 1
        [user, cb] = [socket.user, arguments[0]]

      UserFollow.getFollowing user, cb

  for name, method of api
    socket.api[name] = method
    socket.apiMethods.push name

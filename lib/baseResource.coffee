
module.exports =
  index: (req, res) ->
    @findAndSend req, res

  show: (req, res) ->
    @model.findOne req.dbQuery, @sendJSON req, res

  create: (req, res)  ->
    req.doc.save (err) => @sendJSON(req, res)(err, req.doc)

  update: (req, res)  ->
    update = @deserialize req.body[@model_name]
    cb = @sendJSON req, res

    @model.findOne req.dbQuery, (err, doc) ->
      return cb err if err?
      doc[key] = value for key, value of update
      doc.save (err) ->
        return cb err if err?
        cb null, doc

  destroy: (req, res) ->
    response = {}
    response[@model_name] = null
    @model.remove req.dbQuery, (err, reply) -> res.json response

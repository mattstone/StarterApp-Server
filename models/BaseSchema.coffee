mongoose = require 'mongoose'
Schema   = mongoose.Schema
util     = require 'util'
uniqueValidator = require 'mongoose-unique-validator'

class BaseSchema extends Schema
  constructor: (@app) ->
    super()

    @set 'timestamps', true
    @set 'toJSON', { virtuals: true } # serialise virtual fields

    @.plugin uniqueValidator

  # virtual('id').get( () ->
  #    @._id.toHexString()
  # )
  #
  # findById = (cb) ->
  #   @model(@name).find { id: this.id }, cb

# util.inherits BaseSchema, Schema

module.exports = BaseSchema

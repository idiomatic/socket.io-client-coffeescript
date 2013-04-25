
###
Module dependencies.
###
Emitter = undefined
try
    Emitter = require("emitter")
catch e
    Emitter = require("emitter-component")

###
Module exports.
###
module.exports = Emitter

###
Node-compatible `EventEmitter#removeListener`

@api public
###
Emitter::removeListener = (event, fn) ->
    @off event, fn


###
Node-compatible `EventEmitter#removeAllListeners`

@return {Emitter} self
@api public
###
Emitter::removeAllListeners = ->
    @_callbacks = {}
    this

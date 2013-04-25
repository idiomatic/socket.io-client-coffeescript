
###
Module exports.
###

module.exports = on_

###
Helper for subscriptions.

@param {Object|EventEmitter} obj with `Emitter` mixin or `EventEmitter`
@param {String} event name
@param {Function} callback
@api public
###
on_ = (obj, ev, fn) ->
    obj.on ev, fn
    destroy: ->
        obj.removeListener ev, fn

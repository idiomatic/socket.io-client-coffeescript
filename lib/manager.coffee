
###
Module dependencies.
###

###
Module exports
###

###
`Manager` constructor.

@param {Socket|String} engine instance or engine uri/opts
@param {Object} options
@api public
###
Manager = (socket, opts) ->
  return new Manager(socket, opts)  unless this instanceof Manager
  opts = opts or {}
  opts.path = opts.path or "/socket.io"
  @nsps = {}
  @subs = []
  @reconnection opts.reconnection
  @reconnectionAttempts opts.reconnectionAttempts or Infinity
  @reconnectionDelay opts.reconnectionDelay or 1000
  @reconnectionDelayMax opts.reconnectionDelayMax or 5000
  @timeout (if null is opts.timeout then 10000 else opts.timeout)
  @readyState = "closed"
  socket = eio(socket, opts)  if not socket or not socket.write
  @engine = socket
  @connected = 0
  @attempts = 0
  @open()
url = require("./url")
eio = require("./engine")
Socket = require("./socket")
Emitter = require("./emitter")
parser = require("socket.io-parser")
on_ = require("./on")
debug = require("debug")("socket.io-client:manager")
object = undefined
bind = undefined
module.exports = Manager

###
Mix in `Emitter`.
###
Emitter Manager::

###
Sets the `reconnection` config.

@param {Boolean} true/false if it should automatically reconnect
@return {Manager} self or value
@api public
###
Manager::reconnection = (v) ->
  return @_reconnection  unless arguments_.length
  @_reconnection = !!v
  this


###
Sets the reconnection attempts config.

@param {Number} max reconnection attempts before giving up
@return {Manager} self or value
@api public
###
Manager::reconnectionAttempts = (v) ->
  return @_reconnectionAttempts  unless arguments_.length
  @_reconnectionAttempts = v
  this


###
Sets the delay between reconnections.

@param {Number} delay
@return {Manager} self or value
@api public
###
Manager::reconnectionDelay = (v) ->
  return @_reconnectionDelay  unless arguments_.length
  @_reconnectionDelay = v
  this


###
Sets the maximum delay between reconnections.

@param {Number} delay
@return {Manager} self or value
@api public
###
Manager::reconnectionDelayMax = (v) ->
  return @_reconnectionDelayMax  unless arguments_.length
  @_reconnectionDelayMax = v
  this


###
Sets the connection timeout. `false` to disable

@return {Manager} self or value
@api public
###
Manager::timeout = (v) ->
  return @_timeout  unless arguments_.length
  @_timeout = v
  this


###
Sets the current transport `socket`.

@param {Function} optional, callback
@return {Manager} self
@api public
###
Manager::open = Manager::connect = (fn) ->
  return this  if ~@readyState.indexOf("open")
  socket = @engine
  self = this
  timerSub = undefined
  @readyState = "opening"
  
  # emit `open`
  openSub = on_(socket, "open", bind(this, "onopen"))
  
  # emit `connect_error`
  errorSub = on_(socket, "error", (data) ->
    self.cleanup()
    self.emit "connect_error", data
    if fn
      err = new Error("Connection error")
      err.data = data
      fn err
  )
  
  # emit `connect_timeout`
  if false isnt @_timeout
    timeout = @_timeout
    debug "connect attempt will timeout after %d", timeout
    
    # set timer
    timer = setTimeout(->
      debug "connect attempt timed out after %d", timeout
      openSub.destroy()
      socket.close()
      socket.emit "error", "timeout"
      self.emit "connect_timeout", timeout
    , timeout)
    
    # create handle
    timerSub = destroy: ->
      clearTimeout timer

    @subs.push timerSub
  @subs.push openSub
  @subs.push errorSub
  this


###
Called upon transport open.

@api private
###
Manager::onopen = ->
  
  # clear old subs
  @cleanup()
  
  # mark as open
  @readyState = "open"
  @emit "open"
  
  # add new subs
  socket = @engine
  @subs.push on_(socket, "data", bind(this, "ondata"))
  @subs.push on_(socket, "error", bind(this, "onerror"))
  @subs.push on_(socket, "close", bind(this, "onclose"))


###
Called with data.

@api private
###
Manager::ondata = (data) ->
  @emit "packet", parser.decode(data)


###
Called upon socket error.

@api private
###
Manager::onerror = (err) ->
  @emit "error", err


###
Creates a new socket for the given `nsp`.

@return {Socket}
@api public
###
Manager::socket = (nsp) ->
  socket = @nsps[nsp]
  unless socket
    socket = new Socket(this, nsp)
    @nsps[nsp] = socket
    self = this
    socket.on "connect", ->
      self.connected++

  socket


###
Called upon a socket close.

@param {Socket} socket
###
Manager::destroy = (socket) ->
  @connected--
  @close()  unless @connected


###
Writes a packet.

@param {Object} packet
@api private
###
Manager::packet = (packet) ->
  debug "writing packet %j", packet
  @engine.write parser.encode(packet)


###
Clean up transport subscriptions.

@api private
###
Manager::cleanup = ->
  sub = undefined
  sub.destroy()  while sub = @subs.shift()


###
Close the current socket.

@api private
###
Manager::close = Manager::disconnect = ->
  @skipReconnect = true
  @cleanup()
  @engine.close()


###
Called upon engine close.

@api private
###
Manager::onclose = ->
  @cleanup()
  unless @skipReconnect
    self = this
    @reconnect()


###
Attempt a reconnection.

@api private
###
Manager::reconnect = ->
  self = this
  @attempts++
  if @attempts > @_reconnectionAttempts
    @emit "reconnect_failed"
    @reconnecting = false
  else
    delay = @attempts * @reconnectionDelay()
    delay = Math.min(delay, @reconnectionDelayMax())
    debug "will wait %dms before reconnect attempt", delay
    @reconnecting = true
    timer = setTimeout(->
      debug "attemptign reconnect"
      self.open (err) ->
        if err
          debug "reconnect attempt error"
          self.reconnect()
          self.emit "reconnect_error", err.data
        else
          debug "reconnect success"
          self.onreconnect()

    , delay)
    @subs.push destroy: ->
      clearTimeout timer



###
Called upon successful reconnect.

@api private
###
Manager::onreconnect = ->
  attempt = @attempts
  @attempts = 0
  @reconnecting = false
  @emit "reconnect", attempt


###
Get bind component for node and browser.
###
try
  bind = require("bind")
  object = require("object")
catch e
  bind = require("bind-component")
  object = require("object-component")

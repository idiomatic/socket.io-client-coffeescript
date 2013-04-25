
###
Module dependencies.
###

url = require("./url")
eio = require("./engine")
Socket = require("./socket")
Emitter = require("./emitter")
parser = require("socket.io-parser")
on_ = require("./on")
debug = require("debug")("socket.io-client:manager")
object = undefined
bind = undefined

###
Module exports
###

module.exports = Manager

###
`Manager` constructor.

@param {Socket|String} engine instance or engine uri/opts
@param {Object} options
@api public
###
class Manager extends Emitter
    constructor: (socket, opts) ->
        return new Manager(socket, opts) unless this instanceof Manager
        opts or= {}
        opts.path or= "/socket.io"
        @nsps = {}
        @subs = []
        @reconnection opts.reconnection
        @reconnectionAttempts opts.reconnectionAttempts or Infinity
        @reconnectionDelay opts.reconnectionDelay or 1000
        @reconnectionDelayMax opts.reconnectionDelayMax or 5000
        @timeout opts.timeout ? 10000
        @readyState = "closed"
        socket = eio(socket, opts) unless socket?.write
        @engine = socket
        @connected = 0
        @attempts = 0
        @open()

    ###
    Sets the `reconnection` config.

    @param {Boolean} true/false if it should automatically reconnect
    @return {Manager} self or value
    @api public
    ###
    reconnection: (reconnect) ->
        return @_reconnection unless reconnect?
        @_reconnection = !!reconnect
        this


    ###
    Sets the reconnection attempts config.

    @param {Number} max reconnection attempts before giving up
    @return {Manager} self or value
    @api public
    ###
    reconnectionAttempts: (attempts) ->
        return @_reconnectionAttempts unless attempts?
        @_reconnectionAttempts = attempts
        this


    ###
    Sets the delay between reconnections.

    @param {Number} delay
    @return {Manager} self or value
    @api public
    ###
    reconnectionDelay: (delay) ->
        return @_reconnectionDelay unless delay?
        @_reconnectionDelay = delay
        this


    ###
    Sets the maximum delay between reconnections.

    @param {Number} delay
    @return {Manager} self or value
    @api public
    ###
    reconnectionDelayMax: (delay) ->
        return @_reconnectionDelayMax unless delay?
        @_reconnectionDelayMax = delay
        this


    ###
    Sets the connection timeout. `false` to disable

    @return {Manager} self or value
    @api public
    ###
    timeout: (timeout) ->
        return @_timeout unless timeout?
        @_timeout = timeout
        this


    ###
    Sets the current transport `socket`.

    @param {Function} optional, callback
    @return {Manager} self
    @api public
    ###
    connect: (fn) ->
        return this unless @readyState.indexOf("open") is -1
        socket = @engine
        timerSub = undefined
        @readyState = "opening"

        # emit `open`
        openSub = on_(socket, "open", bind(this, "onopen"))

        # emit `connect_error`
        errorSub = on_ socket, "error", (data) =>
            @cleanup()
            @emit "connect_error", data
            if fn
                err = new Error("Connection error")
                err.data = data
                fn err

        # emit `connect_timeout`
        unless @_timeout is false
            timeout = @_timeout
            debug "connect attempt will timeout after %d", timeout

            # set timer
            timer = setTimeout =>
                debug "connect attempt timed out after %d", timeout
                openSub.destroy()
                socket.close()
                socket.emit "error", "timeout"
                @emit "connect_timeout", timeout
            , timeout

            # create handle
            timerSub = destroy: ->
                clearTimeout timer

            @subs.push timerSub
        @subs.push openSub
        @subs.push errorSub
        this

    open: @connect


    ###
    Called upon transport open.

    @api private
    ###
    onopen: ->

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
    ondata: (data) ->
        @emit "packet", parser.decode(data)


    ###
    Called upon socket error.

    @api private
    ###
    onerror: (err) ->
        @emit "error", err


    ###
    Creates a new socket for the given `nsp`.

    @return {Socket}
    @api public
    ###
    socket: (nsp) ->
        socket = @nsps[nsp]
        unless socket
            socket = new Socket(this, nsp)
            @nsps[nsp] = socket
            socket.on "connect", =>
                @connected++

        socket


    ###
    Called upon a socket close.

    @param {Socket} socket
    ###
    destroy: (socket) ->
        @connected--
        @close() unless @connected


    ###
    Writes a packet.

    @param {Object} packet
    @api private
    ###
    packet: (packet) ->
        debug "writing packet %j", packet
        @engine.write parser.encode(packet)


    ###
    Clean up transport subscriptions.

    @api private
    ###
    cleanup: ->
        sub = undefined
        sub.destroy() while sub = @subs.shift()


    ###
    Close the current socket.

    @api private
    ###
    close: ->
        @skipReconnect = true
        @cleanup()
        @engine.close()

    disconnect: @close


    ###
    Called upon engine close.

    @api private
    ###
    onclose: ->
        @cleanup()
        unless @skipReconnect
            @reconnect()


    ###
    Attempt a reconnection.

    @api private
    ###
    reconnect: ->
        @attempts++
        if @attempts > @_reconnectionAttempts
            @emit "reconnect_failed"
            @reconnecting = false
        else
            delay = @attempts * @reconnectionDelay()
            delay = Math.min(delay, @reconnectionDelayMax())
            debug "will wait %dms before reconnect attempt", delay
            @reconnecting = true
            timer = setTimeout =>
                debug "attemptign reconnect"
                @open (err) =>
                    if err
                        debug "reconnect attempt error"
                        @reconnect()
                        @emit "reconnect_error", err.data
                    else
                        debug "reconnect success"
                        @onreconnect()

            , delay
            @subs.push destroy: ->
                clearTimeout timer



    ###
    Called upon successful reconnect.

    @api private
    ###
    onreconnect: ->
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


###
Module dependencies.
###

parser = require("socket.io-parser")
Emitter = require("./emitter")
toArray = require("to-array")
debug = require("debug")("socket.io-client:socket")
on_ = require("./on")

###
Module exports.
###

module.exports = exports = Socket

###
Internal events (blacklisted).
These events can't be emitted by the user.
###

events = exports.events = ["connect", "disconnect", "error"]

###
Shortcut to `Emitter#emit`.
###

bind = undefined
emit = Emitter::emit

###
`Socket` constructor.

@api public
###
class Socket extends Emitter
    constructor: (io, nsp) ->
        @io = io
        @nsp = nsp
        @json = this # compat
        @ids = 0
        @acks = {}
        @open()
        @buffer = []
        @connected = false
        @disconnected = true

    ###
    Called upon engine `open`.

    @api private
    ###
    open: ->
        io = @io
        io.open() # ensure open
        @onopen() if "open" is @io.readyState
        @subs = [
            on_(io, "open", bind(this, "onopen")),
            on_(io, "error", bind(this, "onerror"))
        ]

    connect: @open

    ###
    Sends a `message` event.

    @return {Socket} self
    @api public
    ###
    send: (args...) ->
        args.unshift "message"
        @emit.apply this, args
        this


    ###
    Override `emit`.
    If the event is in `events`, it's emitted normally.

    @param {String} event name
    @return {Socket} self
    @api public
    ###
    emit: (args...) ->
        [ ev ] = args
        if ~events.indexOf(ev)
            emit.apply this, args
        else
            packet =
                type: parser.EVENT
                data: args

            # event ack callback
            if "function" is typeof args[args.length - 1]
                debug "emitting packet with ack id %d", @ids
                @acks[@ids] = args.pop()
                packet.id = @ids++
            @packet packet
        this


    ###
    Sends a packet.

    @param {Object} packet
    @api private
    ###
    packet: (packet) ->
        packet.nsp = @nsp
        @io.packet packet


    ###
    Called upon `error`.

    @param {Object} data
    @api private
    ###
    onerror: (data) ->
        @emit "error", data


    ###
    "Opens" the socket.

    @api private
    ###
    onopen: ->
        debug "transport is open - connecting"
        
        # write connect packet if necessary
        @packet type: parser.CONNECT unless "/" is @nsp
        
        # subscribe
        io = @io
        @subs.push on_(io, "packet", bind(this, "onpacket")), on_(io, "close", bind(this, "onclose"))


    ###
    Called upon engine `close`.

    @param {String} reason
    @api private
    ###
    onclose: (reason) ->
        debug "close (%s)", reason
        @connected = false
        @disconnected = true
        @emit "disconnect", reason


    ###
    Called with socket packet.

    @param {Object} packet
    @api private
    ###
    onpacket: (packet) ->
        return unless packet.nsp is @nsp
        switch packet.type
            when parser.CONNECT
                @onconnect()
            when parser.EVENT
                @onevent packet
            when parser.ACK
                @onack packet
            when parser.DISCONNECT
                @ondisconnect()
            when parser.ERROR
                @emit "error", packet.data


    ###
    Called upon a server event.

    @param {Object} packet
    @api private
    ###
    onevent: (packet) ->
        args = packet.data or []
        debug "emitting event %j", args
        if packet.id
            debug "attaching ack callback to event"
            args.push @ack(packet.id)
        if @connected
            emit.apply this, args
        else
            @buffer.push args


    ###
    Produces an ack callback to emit with an event.

    @api private
    ###
    ack: (args...) ->
        [ id ] = args
        sent = false
        =>
            # prevent double callbacks
            return if sent
            debug "sending ack %j", args
            @packet
                type: parser.ACK
                id: id
                data: args



    ###
    Called upon a server acknowlegement.

    @param {Object} packet
    @api private
    ###
    onack: (packet) ->
        debug "calling ack %s with %j", packet.id, packet.data
        fn = @acks[packet.id]
        fn.apply this, packet.data
        delete @acks[packet.id]


    ###
    Called upon server connect.

    @api private
    ###
    onconnect: ->
        @connected = true
        @disconnected = false
        @emit "connect"
        @emitBuffered()


    ###
    Emit buffered events.

    @api private
    ###
    emitBuffered: ->
        for ev in @buffer
            emit.apply this, ev
        @buffer = []


    ###
    Called upon server disconnect.

    @api private
    ###
    ondisconnect: ->
        debug "server disconnect (%s)", @nsp
        @destroy()
        @onclose "io server disconnect"


    ###
    Cleans up.

    @api private
    ###
    destroy: ->
        debug "destroying socket (%s)", @nsp
        
        # manual close means no reconnect
        for sub in @subs
            sub.destroy()
        
        # notify manager
        @io.destroy this


    ###
    Disconnects the socket manually.

    @return {Socket} self
    @api public
    ###
    close: ->
        return this unless @connected
        debug "performing disconnect (%s)", @nsp
        @packet type: parser.PACKET_DISCONNECT
        
        # destroy subscriptions
        @destroy()
        
        # fire events
        @onclose "io client disconnect"
        this

    disconnect: @close


###
Load `bind`.
###
try
    bind = require("bind")
catch e
    bind = require("bind-component")

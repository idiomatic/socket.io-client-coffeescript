
###
Module dependencies.
###

url = require("./url")
parser = require("socket.io-parser")
Manager = require("./manager")

###
Module exports.
###

module.exports = exports = lookup

###
Managers cache.
###

cache = exports.managers = {}

###
Looks up an existing `Manager` for multiplexing.
If the user summons:

`io('http://localhost/a');`
`io('http://localhost/b');`

We reuse the existing instance based on same scheme/port/host,
and we initialize sockets for each namespace.

@api public
###
lookup = (uri, opts) ->
    opts or= {}
    parsed = url(uri)
    { href } = parsed
    io = undefined
    if opts.forceNew or opts.multiplex is false
        io = Manager(href, opts)
    else
        { id } = parsed
        cache[id] = Manager(href, opts) unless cache[id]
        io = cache[id]
    io.socket parsed.pathname or "/"

###
Expose standalone client source.

@api public
###
unless typeof process is "undefined"
    read = require("fs").readFileSync
    exports.source = read(__dirname + "/../socket.io-client.js")

###
Protocol version.

@api public
###
exports.protocol = parser.protocol

###
`connect`.

@param {String} uri
@api public
###
exports.connect = lookup

###
Expose constructors for standalone build.

@api public
###
exports.Manager = require("./manager")
exports.Socket = require("./socket")
exports.Emitter = require("./emitter")


###
Module dependencies.
###

###
Module exports.
###

###
Managers cache.
###

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
  opts = opts or {}
  parsed = url(uri)
  href = parsed.href
  io = undefined
  if opts.forceNew or false is opts.multiplex
    io = Manager(href, opts)
  else
    id = parsed.id
    cache[id] = Manager(href, opts)  unless cache[id]
    io = cache[id]
  io.socket parsed.pathname or "/"
url = require("./url")
parser = require("socket.io-parser")
Manager = require("./manager")
module.exports = exports = lookup
cache = exports.managers = {}

###
Expose standalone client source.

@api public
###
unless "undefined" is typeof process
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

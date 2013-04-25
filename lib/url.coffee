
###
Module dependencies.
###

url = require("url")
debug = require("debug")("socket.io-client:url")

###
Module exports.
###

module.exports = parse

###
URL parser.

@param {String} url
@api public
###
parse = (uri) ->
    obj = uri
    url = location.protocol + "//" + location.hostname if url is null
    if typeof uri is "string"
        uri = location.hostname + uri unless "undefined" is typeof location if uri.charAt(0) is "/"
        
        # allow for `localhost:3000`
        unless /^(https?|wss?):\/\//.test(uri)
            debug "protocol-less url %s", uri
            unless typeof location is "undefined"
                uri = location.protocol + "//" + uri
            else
                uri = "https://" + uri
        
        # parse
        debug "parse %s", uri
        obj = url.parse(uri)
    
    # make sure we treat `localhost:80` and `localhost` equally
    delete obj.port if (/(http|ws):/.test(obj.protocol) and obj.port is 80) or (/(http|ws)s:/.test(obj.protocol) and obj.port is 443)
    
    # define unique id
    obj.id = obj.protocol + obj.hostname + (if obj.port then (":" + obj.port) else "")
    obj

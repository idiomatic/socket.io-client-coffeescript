
###
Module dependencies.
###

###
Module exports.
###

###
URL parser.

@param {String} url
@api public
###
parse = (uri) ->
  obj = uri
  url = location.protocol + "//" + location.hostname  if null is url
  if "string" is typeof uri
    uri = location.hostname + uri  unless "undefined" is typeof location  if "/" is uri.charAt(0)
    
    # allow for `localhost:3000`
    unless /^(https?|wss?):\/\//.test(uri)
      debug "protocol-less url %s", uri
      unless "undefined" is typeof location
        uri = location.protocol + "//" + uri
      else
        uri = "https://" + uri
    
    # parse
    debug "parse %s", uri
    obj = url.parse(uri)
  
  # make sure we treat `localhost:80` and `localhost` equally
  delete obj.port  if (/(http|ws):/.test(obj.protocol) and 80 is obj.port) or (/(http|ws)s:/.test(obj.protocol) and 443 is obj.port)
  
  # define unique id
  obj.id = obj.protocol + obj.hostname + ((if obj.port then (":" + obj.port) else ""))
  obj
url = require("url")
debug = require("debug")("socket.io-client:url")
module.exports = parse

new HE(
  entryPoint: 'http://klarna.apiary.io/'
  callbacks:
    parseReqHeaders: (method, headers, body) ->
      headers
    parseResHeaders: (method, headers, body) ->
      headers
    parseResLinks: (headers, body) ->
      []
)
Backbone.history.start()

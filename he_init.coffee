new HE(
  entryPoint: 'http://klarna.apiary.io/'
  callbacks:
    # parseResHeaders: (res) ->
    parseResLinks: (res) ->
      type = 'json'  if /json$/.test(res.headers?['content-type'])
      return  unless type is 'json'
      body = JSON.parse res.body
      body.links or= []
      links = body.links
      for link in links
        linkClone = _.clone link
        delete linkClone.rel
        delete linkClone.href
        link.props = JSON.stringify linkClone, null, ' '
        link.relShort = link.rel.replace /^https?:\/\/[^\/]+/, ''
        if /^http/.test link.rel
          link.relURI = link.rel
      links
    parseResBodyState: (res) ->
      if res.body
        type = 'json'  if /json$/.test(res.headers?['content-type'])
        return  unless type is 'json'
        body = JSON.parse res.body
        delete body.links
        body
      else
        res.headers
    # parseResBody: (res) ->
    # prettifyResBody: (res) ->
)

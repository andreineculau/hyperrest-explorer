(->
  window.HE = HE = class HE extends Backbone.Router
    constructor: (args...) ->
      HE.__super__.constructor.apply @, args # Redux FIXME

    initialize: (@opts = {}) ->
      delete window.HE
      self = this
      @event = _.extend {}, Backbone.Events

      @$reqMethod = $ '#req-method'
      @$reqAddressBar = $ '#req-address-bar > li:eq(0)'
      @$reqAddress = $ '#req-address'
      @$req = $ '#req'
      @$reqHeaders = $ '#req-headers'
      @$reqBody = $ '#req-body'
      @$res = $ '#res'
      @$resHeaders = $ '#res-headers'
      @$resBody = $ '#res-body'
      @$resource = $ '#resource'

      @callbacks = _.assign {}, HE.callbacks, @opts.callbacks

      @addressBar = new HE.Views.AddressBar(
        el: @$reqAddressBar
        HE: @
      )
      @resource = new HE.Views.Resource(
        el: @$resource
        HE: @
      )
      @req = new HE.Views.Request(
        el: @$req
        HE: @
      )
      @res = new HE.Views.Response(
        el: @$res
        HE: @
      )
      $('button', @$reqMethod).click (e) -> self.ajax {type: $(this).attr('title')}
      $('#req-refresh').click (e) -> self.ajax()
      window.location.hash = @opts.entryPoint  if @opts.entryPoint and window.location.hash is ''
      Backbone.history.start()

    @callbacks =
      parseResHeaders: (res) ->
        res.status + ' ' + res.statusText + '\n' + res.jqXHR.getAllResponseHeaders()
      parseResLinks: (res) ->
        []
      parseResBodyState: (res) ->
        if res.body
          JSON.parse res.body
        else
          res.headers
      prettifyResBody: (res) ->
        type = 'json'  if /json$/.test(res.headers?['content-type'])
        @prettifyBody type, res.body
      prettifyBody: (type, body) ->
        prettyBody = body
        switch type
          when 'json'
            try
              prettyBody = JSON.stringify JSON.parse(body), undefined, 2
            catch e
              prettyBody
        prettyBody

    routes:
      '*url': 'getResource'

    getResource: (url) ->
      hash = location.hash.slice 1
      @ajax {url: url}  if hash.slice(0, 8) isnt 'NON-GET:'

    ajax: (opts = {}) ->
      self = @
      @$reqAddressBar.hide()
      if opts.url
        @event.trigger 'req-address-change',
          HE: self
          url: opts.url
      else
        opts.url = @$reqAddress.val()

      unless opts.type
        opts.type = $('button.active', @$reqMethod).attr('title')

      opts.crossDomain = true
      opts.headers = HE.util.parseHeaders @$reqHeaders.val()

      jqXHR = $.ajax(opts).always(->
        self.$reqAddressBar.show()
        unless jqXHR and jqXHR.status isnt 0
          window.alert 'no can do.'
          return
        self.event.trigger 'res',
          HE: self
          jqXHR: jqXHR
          status: jqXHR.status
          statusText: jqXHR.statusText
          headers: HE.util.parseHeaders jqXHR.getAllResponseHeaders()
          body: jqXHR.responseText
      )

  HE.Models = {}
  HE.Views = {}
  HE.util = {}


  # AddressBar -----------------------------------------------------------------
  HE.Views.AddressBar = Backbone.View.extend(
    initialize: (opts) ->
      self = this
      @HE = opts.HE
      @HE.event.bind 'req-address-change', (e) ->
        self.HE.$reqAddress.val e.url

    events:
      'keypress #req-address': 'go'

    go: (e) ->
      e.stopPropagation()
      return  if e.keyCode and e.keyCode isnt 13
      window.location.hash = @HE.$reqAddress.val()
  )


  # Resource -------------------------------------------------------------------
  HE.Views.Resource = Backbone.View.extend(
    initialize: (opts) ->
      self = this
      @HE = opts.HE
      _.bindAll @, 'render'
      _.bindAll @, 'followLink'
      _.bindAll @, 'showDocs'
      @HE.event.bind 'res', @render

    events:
      'click .links-buttons button': 'followLink'
      'click .links-docs button': 'showDocs'

    render: (e) ->
      self = @
      @$el.html @template(
        state: self.HE.callbacks.parseResBodyState e
        links: self.HE.callbacks.parseResLinks e
      )

    followLink: (e) ->
      e.stopPropagation()
      $this = $(e.target)
      uri = $this.attr 'data-href'
      method = $this.attr 'title'
      @HE.$reqMethod.find('button').removeClass 'active'
      @HE.$reqMethod.find('button[title=' + method + ']').addClass 'active'
      window.location.hash = uri

    showDocs: (e) ->
      e.stopPropagation()
      $this = $(e.target)
      uri = $this.attr 'href'
      @HE.event.trigger 'show-docs',
        url: uri

    template: _.template($('#resource-template').html())
  )


  # Request --------------------------------------------------------------------
  HE.Views.Request = Backbone.View.extend(
    initialize: (opts) ->
      self = this
      @HE = opts.HE
  )


  # Response -------------------------------------------------------------------
  HE.Views.Response = Backbone.View.extend(
    initialize: (opts) ->
      @HE = opts.HE
      _.bindAll @, 'showRes'
      @HE.event.bind 'res', @showRes

    showRes: (e) ->
      @HE.$resHeaders.html @HE.callbacks.parseResHeaders e
      output = @HE.callbacks.prettifyResBody(e) or ''
      @HE.$resBody.html _.escape output
  )




  # Misc -------------------------------------------------------------------

  # Util -------------------------------------------------------------------
  HE.util.parseHeaders = (string) ->
    header_lines = string.split('\n')
    headers = {}
    _.each header_lines, (line) ->
      parts = line.split(':')
      if parts.length > 1
        name = parts.shift().trim().toLowerCase()
        value = parts.join(':').trim()
        headers[name] = value

    headers
)()

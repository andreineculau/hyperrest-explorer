(->
  HAL =
    Models: {}
    Views: {}
    currentDocument: {}
    jsonIndent: 2

  HAL.client = (opts) ->
    @vent = opts.vent
    @headers = HAL.parseHeaders($("#req-headers").val())
    @get = (url) ->
      self = this
      @vent.trigger "location-change",
        url: url

      jqxhr = $.ajax(
        url: url
        dataType: "json"
        headers: @headers
        success: (resource, textStatus, jqXHR) ->
          self.vent.trigger "response",
            resource: resource
            headers: jqXHR.getAllResponseHeaders()

      ).error(->
        self.vent.trigger "fail-response",
          jqxhr: jqxhr

      ).always(->
        self.vent.trigger "response-headers",
          jqxhr: jqxhr

      )
    @

  HAL.Router = Backbone.Router.extend(
    initialize: (opts) ->
      self = this
      opts = opts or {}
      vent = _.extend({}, Backbone.Events)
      vent.bind "response", (e) ->
        window.HAL.currentDocument = e.resource or {}

      @client = new HAL.client({vent: vent})
      $.ajaxSetup headers:
        Accept: "application/hal+json, application/json, */*; q=0.01"

      @browser = new HAL.Views.Browser(
        el: $("#req")
        vent: vent
      )
      @inspectorView = new HAL.Views.Inspector(
        el: $("#res")
        vent: vent
      )
      if window.location.hash is ""
        entry = opts.entryPoint or "/"
        window.location.hash = entry

    routes:
      "*url": "resourceRoute"

    resourceRoute: (url) ->
      url = location.hash.slice(1)
      @client.get url  if url.slice(0, 8) isnt "NON-GET:"
  )
  HAL.Models.Resource = Backbone.Model.extend(
    initialize: (representation) ->
      @links = representation._links
      @embeddedResources = @buildEmbeddedResources(representation._embedded)  if representation._embedded isnt `undefined`
      @set representation
      @unset "_embedded",
        silent: true

      @unset "_links",
        silent: true


    buildEmbeddedResources: (embeddedResources) ->
      result = {}
      _.each embeddedResources, (obj, rel) ->
        if $.isArray(obj)
          arr = []
          _.each obj, (resource, i) ->
            newResource = new HAL.Models.Resource(resource)
            newResource.identifier = rel + "[" + i + "]"
            newResource.embed_rel = rel
            arr.push newResource

          result[rel] = arr
        else
          newResource = new HAL.Models.Resource(obj)
          newResource.identifier = rel
          newResource.embed_rel = rel
          result[rel] = newResource

      result
  )
  HAL.Views.Browser = Backbone.View.extend(
    initialize: (opts) ->
      self = this
      @vent = opts.vent
      @locationBar = new HAL.Views.LocationBar(
        el: @$("#res-address-bar")
        vent: @vent
      )
      @resourceView = new HAL.Views.Resource(
        el: $("#res-resource")
        vent: @vent
      )

    events:
      "blur #req-headers": "updateRequestHeaders"

    updateRequestHeaders: (e) ->
      headers = HAL.parseHeaders(@$("#req-headers").val())
      $.ajaxSetup headers: headers
  )
  HAL.Views.Resource = Backbone.View.extend(
    initialize: (opts) ->
      self = this
      @vent = opts.vent
      _.bindAll this, "followLink"
      _.bindAll this, "showNonSafeRequestDialog"
      _.bindAll this, "showUriQueryDialog"
      _.bindAll this, "showDocs"
      @vent.bind "response", (e) ->
        self.render new HAL.Models.Resource(e.resource)

      @vent.bind "fail-response", (e) ->
        self.vent.trigger "response",
          resource: null
          jqxhr: e.jqxhr



    events:
      "click .links a.follow": "followLink"
      "click .links a.non-get": "showNonSafeRequestDialog"
      "click .links a.query": "showUriQueryDialog"
      "click .links a.dox": "showDocs"

    render: (resource) ->
      @$el.html @template(
        state: resource.toJSON()
        links: resource.links
      )
      $embres = @$(".embedded-resources")
      $embres.html @renderEmbeddedResources(resource.embeddedResources)
      $embres.accordion()
      this

    followLink: (e) ->
      e.preventDefault()
      $target = $(e.target)
      uri = $target.attr("href") or $target.parent().attr("href")
      window.location.hash = uri

    showUriQueryDialog: (e) ->
      e.preventDefault()
      $target = $(e.target)
      uri = $target.attr("href") or $target.parent().attr("href")
      d = new HAL.Views.QueryUriDialog(href: uri).render()
      d.$el.dialog
        title: "Query URI Template"
        width: 400

      window.foo = d

    showNonSafeRequestDialog: (e) ->
      e.preventDefault()
      d = new HAL.Views.NonSafeRequestDialog(
        href: $(e.target).attr("href")
        vent: @vent
      ).render()
      d.$el.dialog
        title: "Non Safe Request"
        width: 500


    showDocs: (e) ->
      e.preventDefault()
      $target = $(e.target)
      uri = $target.attr("href") or $target.parent().attr("href")
      @vent.trigger "show-docs",
        url: uri


    renderEmbeddedResources: (embeddedResources) ->
      self = this
      result = ""
      _.each embeddedResources, (obj) ->
        if $.isArray(obj)
          _.each obj, (resource) ->
            result += self.embeddedResourceTemplate(
              state: resource.toJSON()
              links: resource.links
              name: resource.identifier
              embed_rel: resource.embed_rel
            )

        else
          result += self.embeddedResourceTemplate(
            state: obj.toJSON()
            links: obj.links
            name: obj.identifier
            embed_rel: obj.embed_rel
          )

      result

    template: _.template($("#resource-template").html())
    embeddedResourceTemplate: _.template($("#embedded-resource-template").html())
  )
  HAL.Views.LocationBar = Backbone.View.extend(
    initialize: (opts) ->
      self = this
      @vent = opts.vent
      @vent.bind "location-change", (e) ->
        self.setLocation e.url


    setLocation: (url) ->
      @address.attr 'value', url

    address: $("#req-address")
  )
  HAL.Views.Inspector = Backbone.View.extend(
    initialize: (opts) ->
      @vent = opts.vent
      _.bindAll this, "showDocs"
      _.bindAll this, "showRawResource"
      _.bindAll this, "showResponseHeaders"
      @vent.bind "show-docs", @showDocs
      @vent.bind "response", @showRawResource
      @vent.bind "response-headers", @showResponseHeaders

    showResponseHeaders: (e) ->
      @$("#res-headers").html e.jqxhr.status + ' ' + e.jqxhr.statusText + '\n' + e.jqxhr.getAllResponseHeaders()

    showDocs: (e) ->
      @$("#res-body").html "<iframe src=" + e.url + "></iframe>"

    showRawResource: (e) ->
      output = "n/a"
      if e.resource isnt null
        output = JSON.stringify(e.resource, null, HAL.jsonIndent)
      else

        # The Ajax request "failed", but there may still be an
        # interesting response body (possibly JSON) to show.
        content_type = e.jqxhr.getResponseHeader("content-type")
        responseText = e.jqxhr.responseText
        unless content_type.indexOf("json") is -1

          # Looks like json... try to parse it.
          try
            obj = JSON.parse(responseText)
            output = JSON.stringify(obj, null, HAL.jsonIndent)
          catch err

            # JSON parse failed. Just show the raw text.
            output = responseText
        else output = responseText  if content_type.indexOf("text/") is 0
      @$("#res-body").html _.escape(output)
  )
  HAL.Views.QueryUriDialog = Backbone.View.extend(
    initialize: (opts) ->
      @href = opts.href
      @uriTemplate = uritemplate(@href)
      _.bindAll this, "submitQuery"
      _.bindAll this, "renderPreview"

    events:
      "submit form": "submitQuery"
      "keyup textarea": "renderPreview"
      "change textarea": "renderPreview"

    submitQuery: (e) ->
      e.preventDefault()
      input = undefined
      try
        input = JSON.parse(@$("textarea").val())
      catch err
        input = {}
      @$el.dialog "close"
      window.location.hash = @uriTemplate.expand(input)

    renderPreview: (e) ->
      input = undefined
      result = undefined
      try
        input = JSON.parse($(e.target).val())
        result = @uriTemplate.expand(input)
      catch err
        result = "Invalid json input"
      @$(".preview").html result

    render: ->
      @$el.html @template(href: @href)
      @$("textarea").trigger "keyup"
      this

    template: _.template($("#query-uri-template").html())
  )
  HAL.Views.NonSafeRequestDialog = Backbone.View.extend(
    initialize: (opts) ->
      @href = opts.href
      @vent = opts.vent
      @uriTemplate = uritemplate(@href)
      _.bindAll this, "submitQuery"

    events:
      "submit form": "submitQuery"

    headers: ->
      HAL.parseHeaders @$(".headers").val()

    submitQuery: (e) ->
      e.preventDefault()
      self = this
      headers = @headers()
      method = @$(".method").val()
      body = @$(".body").val()
      jqxhr = $.ajax(
        url: @href
        dataType: "json"
        type: method
        headers: headers
        data: body
      ).done((response) ->
        self.vent.trigger "response",
          resource: response

      ).fail((response) ->
        self.vent.trigger "fail-response",
          jqxhr: jqxhr

      ).always(->
        self.vent.trigger "response-headers",
          jqxhr: jqxhr

        self.vent.trigger "location-change",
          url: self.href

        window.location.hash = "NON-GET:" + self.href
      )
      @$el.dialog "close"

    render: ->
      @$el.html @template(
        href: @href
        user_defined_headers: $("#req-headers").val()
      )
      this

    template: _.template($("#non-safe-request-template").html())
  )
  urlRegex = /(http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?/
  HAL.isUrl = (str) ->
    str.match(urlRegex) or isCurie(str)

  HAL.truncateIfUrl = (str) ->
    replaceRegex = /(http|https):\/\/([^\/]*)\//
    str.replace replaceRegex, ".../"

  isCurie = (string) ->
    string.split(":").length > 1

  HAL.buildUrl = (rel) ->
    if not rel.match(urlRegex) and isCurie(rel) and HAL.currentDocument._links.curies
      parts = rel.split(":")
      curies = HAL.currentDocument._links.curies
      i = 0

      while i < curies.length
        if curies[i].name is parts[0]
          tmpl = uritemplate(curies[i].href)
          return tmpl.expand(rel: parts[1])
        i++

    # Backward compatible with <04 version of spec.
    else if not rel.match(urlRegex) and isCurie(rel) and HAL.currentDocument._links.curie
      tmpl = uritemplate(HAL.currentDocument._links.curie.href)
      tmpl.expand rel: rel.split(":")[1]

    # End BC.
    else
      rel

  HAL.parseHeaders = (string) ->
    header_lines = string.split("\n")
    headers = {}
    _.each header_lines, (line) ->
      parts = line.split(":")
      if parts.length > 1
        name = parts.shift().trim()
        value = parts.join(":").trim()
        headers[name] = value

    headers

  window.HAL = HAL
)()

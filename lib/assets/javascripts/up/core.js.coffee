###*
Page flow.

@class up.core
###
up.core = (->
  
  presence = up.util.presence

  setSource = (element, sourceUrl) ->
    $element = $(element)
    sourceUrl = up.util.normalizeUrl(sourceUrl) if up.util.isPresent(sourceUrl)
    $element.attr("up-source", sourceUrl)

  source = (element) ->
    $element = $(element).closest("[up-source]")
    $element.attr("up-source") || location.href

  ###*
  Replaces elements on the current page with corresponding elements
  from a new page fetched from the server.

  The current and new elements must have the same CSS selector.

  @method up.replace
  @param {String|Element|jQuery} selectorOrElement
    The CSS selector to update. You can also pass a DOM element or jQuery element
    here, in which case a selector will be inferred from the element's class and ID.
  @param {String} url
    The URL to fetch from the server.
  @param {String} [options.history.url=url]
    An alternative URL to use for the browser's location bar and history.
  @param {String} [options.history.method='push']
  @param {String} [options.transition]
  @param {String|Boolean} [options.source]
  ###
  replace = (selectorOrElement, url, options) ->

    selector = if presence(selectorOrElement)
      selectorOrElement
    else
      up.util.createSelectorFromElement($(selectorOrElement))

    options = up.util.options(options, history: { url: url })
    
    if up.util.isMissing(options.source) || options.source == true
      options.source = url
      
    up.util.get(url, selector: selector)
      .done (html) -> implant(selector, html, options)
      .fail(up.util.error)

  ###*
  @method up.flow.implant
  @protected
  @param {String} selector
  @param {String} html
  @param {String} [options.source]
  @param {String} [options.history.url]
  @param {String} [options.history.method='push']
  @param {String} [options.transition]
  ###
  implant = (selector, html, options) ->
    
    options = up.util.options(options, history: { method: 'push' })
    # jQuery cannot construct transient elements that contain <html> or <body> tags,
    # so we're using the native browser API to grep through the HTML
    htmlElement = up.util.createElementFromHtml(html)

    options.title ||= htmlElement.querySelector("title")?.textContent # todo: extract title from header

    for step in implantSteps(selector, options)
      $old =
        # always prefer to replace content in popups or modals
        presence($(".up-popup " + step.selector)) || 
        presence($(".up-modal " + step.selector)) || 
        presence($(step.selector)) 
      if fragment = htmlElement.querySelector(step.selector)
        $new = $(fragment)
        swapElements $old, $new, step.pseudoClass, step.transition, options
      else
        up.util.error("Could not find selector (#{step.selector}) in response (#{html})")
        
  elementsInserted = ($new, options) ->
    $new.each ->
      $element = $(this)
      options.insert?($element)
      if options.history?.url
        document.title = options.title if options.title
        up.history[options.history.method](options.history.url)
      # Remember where the element came from so we can
      # offer reload functionality.
      setSource($element, options.source || history.url)
      autofocus($element)
      # The fragment should be readiet before the transition,
      # so transitions see .up-current classes
      up.ready($element)

  swapElements = ($old, $new, pseudoClass, transition, options) ->
    transition ||= 'none'
    if pseudoClass
      insertionMethod = if pseudoClass == 'before' then 'prepend' else 'append'
      # Keep a reference to the children append/prepend because
      # we need to compile them further down
      $addedChildren = $new.children()
      # Insert contents() instead of $children since contents()
      # also includes text nodes.
      $old[insertionMethod]($new.contents())
      up.util.copyAttributes($new, $old)
      elementsInserted($addedChildren, options)
      # Since we're adding content instead of replacing, we'll only
      # animate $new instead of morphing between $old and $new
      up.animate($new, transition)
    else
      # Wrap the replacement as a destroy animation, so $old will
      # get marked as .up-destroying right away.
      destroy $old, animation: ->
        $new.insertAfter($old)
        elementsInserted($new, options)
        if $old.is('body') && transition != 'none'
          up.util.error('Cannot apply transitions to body-elements', transition)
        up.morph($old, $new, transition)

  implantSteps = (selector, options) ->
    transitionString = options.transition || options.animation || 'none'
    comma = /\ *,\ */
    disjunction = selector.split(comma)
    transitions = transitionString.split(comma) if up.util.isPresent(transitionString)    
    for selectorAtom, i in disjunction
      # Splitting the atom
      selectorParts = selectorAtom.match(/^(.+?)(?:\:(before|after))?$/)
      transition = transitions[i] || up.util.last(transitions)
      selector: selectorParts[1]
      pseudoClass: selectorParts[2]
      transition: transition

  autofocus = ($element) ->
    selector = '[autofocus]:last'
    $control = up.util.findWithSelf($element, selector)
    if $control.length && $control.get(0) != document.activeElement
      $control.focus()
      
#  executeScripts = ($new) ->
#    $new.find('script').each ->
#      $script = $(this)
#      type = $script.attr('type')
#      if up.util.isBlank(type) || type.indexOf('text/javascript') == 0
#        code = $script.text()
#        console.log("Evaling javascript code", code)
#        eval(code)
      
  ###*
  Destroys the given element or selector.
  Takes care that all destructors, if any, are called.
  
  @method up.destroy
  @param {String|Element|jQuery} selectorOrElement 
  ###
  destroy = (selectorOrElement, options) ->
    $element = $(selectorOrElement)
    options = up.util.options(options, animation: 'none')
    $element.addClass('up-destroying')
    up.bus.emit('fragment:destroy', $element)
    animationPromise = presence(options.animation, up.util.isPromise) ||
      up.motion.animate($element, options.animation)
    animationPromise.then -> $element.remove()
    
      
  ###*
  Replaces the given selector or element with a fresh copy
  fetched from the server.

  @method up.reload
  @param {String|Element|jQuery} selectorOrElement
  ###
  reload = (selectorOrElement) ->
    sourceUrl = source(selectorOrElement)
    replace(selectorOrElement, sourceUrl)

  ###*
  Resets Up.js to the state when it was booted.
  All custom event handlers, animations, etc. that have been registered
  will be discarded.
  
  This is an internal method for to enable unit testing.
  Don't use this in production.
  
  @protected
  @method up.reset
  ###
  reset = ->
    up.bus.emit('framework:reset')
  
  up.bus.on('app:ready', ->
    setSource(document.body, location.href)
  )

  replace: replace
  reload: reload
  destroy: destroy
  implant: implant
  reset: reset

)()

up.replace = up.flow.replace
up.reload = up.flow.reload
up.destroy = up.flow.destroy
up.reset = up.flow.reset
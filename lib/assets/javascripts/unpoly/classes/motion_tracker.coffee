u = up.util

class up.MotionTracker

  constructor: (name) ->
    @activeClass = "up-#{name}"
    @dataKey = "up-#{name}-finished"
    @selector = ".#{@activeClass}"
    @finishEvent = "up:#{name}:finish"
    @finishCount = 0
    @clusterCount = 0

  ###**
  Finishes all animations in the given element cluster's ancestors and descendants,
  then calls the animator.

  The animation returned by the animator is tracked so it can be
  [`finished`](/up.MotionTracker.finish) later.

  @method claim
  @param {jQuery} $cluster
  @param {Function(jQuery): Promise} animator
  @param {Object} memory.trackMotion = true
    Whether
  @return {Promise} A promise that is fulfilled when the new animation ends.
  ###
  claim: ($cluster, animator, memory = {}) =>
    console.debug("motionTracker<%o>.claim(%o, { trackMotion = %o })", @activeClass, $cluster.get(), memory.trackMotion)
    memory.trackMotion = u.option(memory.trackMotion, up.motion.isEnabled())
    if memory.trackMotion is false
      # Since we don't want recursive tracking or finishing, we could run
      # the animator() now. However, since the else branch is async, we push
      # the animator into the microtask queue to be async as well.
      u.microtask(animator)
    else
      memory.trackMotion = false
      @finish($cluster).then =>
        promise = @whileForwardingFinishEvent($cluster, animator)
        promise = promise.then => @unmarkCluster($cluster)
        # Attach the modified promise to the cluster's elements
        @markCluster($cluster, promise)
        promise

  ###**
  @method finish
  @param {jQuery} [elements]
    If no element is given, finishes all animations in the documnet.
    If an element is given, only finishes animations in its subtree and ancestors.
  @return {Promise} A promise that is fulfilled when animations have finished.
  ###
  finish: (elements) =>
    @finishCount++
    console.debug("motionTracker<%o>.finish(%o)", @activeClass, elements)
    $elements = @expandFinishRequest(elements)
    console.debug("... effective elements that need finishing are %o", $elements.get())
    allFinished = u.map($elements, @finishOneElement)
    Promise.all(allFinished).then => console.debug("MotionTracker %o done finishing on %o", @activeClass, $elements.get())

  expandFinishRequest: (elements) =>
    console.debug("@@@ expandFinishRequest(%o) with @clusterCount == %o", elements, @clusterCount)

    if @clusterCount == 0 || !up.motion.isEnabled()
      return $([])
    else if elements
      u.selectInDynasty($(elements), @selector)
    else
      $(@selector)

  isActive: (element) =>
    u.hasClass(element, @activeClass)

  finishOneElement: (element) =>
    $element = $(element)

    # Animating code is expected to listen to this event, fast-forward
    # the animation and resolve their promise. All built-ins like
    # `up.animate`, `up.morph`, or `up.scroll` behave that way.
    @emitFinishEvent($element)

    # If animating code ignores the event, we cannot force the animation to
    # finish from here. We will wait for the animation to end naturally before
    # starting the next animation.
    @whenElementFinished($element)

  emitFinishEvent: ($element, eventAttrs = {}) =>
    eventAttrs = u.merge({ $element: $element, message: false }, eventAttrs)
    up.emit(@finishEvent, eventAttrs)

  whenElementFinished: ($element) =>
    # There are some cases related to element ghosting where an element
    # has the class, but not the data value. In that case simply return
    # a resolved promise.
    console.debug("--- whenElementFinished on %o with data %o, attached is %o", $element.get(0), $element.data(@dataKey), !u.isDetached($element))
    $element.data(@dataKey) || Promise.resolve()

  markCluster: ($cluster, promise) =>
    @clusterCount++
    console.debug("@@@ clusterCount increased to %o", @clusterCount)
    $cluster.addClass(@activeClass)
    $cluster.data(@dataKey, promise)

  unmarkCluster: ($cluster) =>
    @clusterCount--
    console.debug("@@@ clusterCount reduced to %o", @clusterCount)
    console.debug("--- removing data from %o", $cluster.get(0))
    $cluster.removeClass(@activeClass)
    $cluster.removeData(@dataKey)

  forwardFinishEvent: ($original, $ghost, duration) =>
    @start $original, =>
      doForward = => $ghost.trigger(@finishEvent)
      # Forward the finish event to the $ghost that is actually animating
      $original.on @finishEvent, doForward
      # Our own pseudo-animation finishes when the actual animation on $ghost finishes
      duration.then => $original.off @finishEvent, doForward

  whileForwardingFinishEvent: ($elements, fn) =>
    return fn() if $elements.length < 2
    doForward = (event) =>
      unless event.forwarded
        u.each $elements, (element) =>
          $element = $(element)
          if element != event.target && @isActive($element)
            console.debug("Forwarding finishEvent to %o", element)
            @emitFinishEvent($element, forwarded: true)

    # Forward the finish event to the $ghost that is actually animating
    $elements.on @finishEvent, doForward
    # Our own pseudo-animation finishes when the actual animation on $ghost finishes
    fn().then => $elements.off @finishEvent, doForward

  reset: =>
    @finish().then =>
      @finishCount = 0
      @clusterCount = 0
      console.debug("@@@ RESET clusterCount to %o", @clusterCount)

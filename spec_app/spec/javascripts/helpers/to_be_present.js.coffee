beforeEach ->
  jasmine.addMatchers
    toBePresent: (util, customEqualityTesters) ->
      compare: (actual) ->
        pass: up.util.isPresent(actual)

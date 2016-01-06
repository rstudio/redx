library = require 'library'  -- from redx

describe "strip function", ->

    it "should remove leading and trailing characters", () ->

        assert.are.same(library.strip('/derp', '/'), 'derp')
        assert.are.same(library.strip('derp', '/'), 'derp')
        assert.are.same(library.strip('derp ', '/'), 'derp ')
        assert.are.same(library.strip(' /derp', '/'), ' /derp')
        assert.are.same(library.strip('//derp//', '/'), 'derp')
        assert.are.same(library.strip('//derp// ', '/'), 'derp// ')

describe "trim function", ->

    it "should remove leading and trailing whitespace", () ->

        assert.are.same(library.trim('  derp '), 'derp')
        assert.are.same(library.trim('derp'), 'derp')
        assert.are.same(library.trim('derp\n'), 'derp')
        assert.are.same(library.trim('\nderp\n'), 'derp')


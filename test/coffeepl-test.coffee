assert = require 'assert'
coffeepl = require '../src/coffeepl.js'

assert.ok coffeepl?

assert.ok coffeepl.CoffeePL?
c = new coffeepl.CoffeePL

assert.equal "a", c.createParser().parse("a").render()
assert.equal ">test<", c.createParser().parse(">${val}$<").render({ val : "test" })
assert.equal "a<test>", c.createParser().parse("a<${val}$>").render({ val: "test" })
assert.equal "Xa<<test>>b", c.createParser()
	.parse("X<!-- {block} --><${valTest}$><!-- {/block} -->a<${include('block', {valTest:val})}$>b")
	.render({ val: "test" })
assert.equal "items: 1, 2, 3, ", c.createParser().parse("items: <!-- @ for(var k in items) { @ -->${items[k]}$, <!-- @ } @ -->").render({ items: [1,2,3] })

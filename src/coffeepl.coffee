######################################################
#
# COFFEE SCRIPT TEMPLATE ENGINE
#
# Author: Moises P. Sena <moisespsena@gmail.com>
#
######################################################

this.console = console
_root = this

if window?
	window.coffeePL = {}
	coffeePL = window.coffeePL
else
	coffeePL = this

coffeePL.globals =
	debugEnabled: false

class coffeePL.DefaultLogger
	constructor: (@name, options) ->
		@debugEnabled = if options?.debugEnabled then true else false

	debug: (msg) ->
		console = _root.console
		console ?= {}
		console.debug ?= (msg) ->
		console.debug @name, msg

class coffeePL.LoggerFactory
	constructor: (@loggerClass, options) ->
		@options = if options? then options else {}

	getLogger: (name) ->
		new @loggerClass(name, @options)

coffeePL.loggerFactory = new coffeePL.LoggerFactory(coffeePL.DefaultLogger, coffeePL.globals)

class coffeePL.Template
	constructor: (@config, @blocks, @renderFunction) ->

	# arguments to string
	argsts: (args) ->
		val = @config.argsAdapter.toStr args

	# arguments from string
	argsfs: (args) ->
		val = @config.argsAdapter.fromStr args

	include: (blockId, parameters) ->
		if not @blocks[blockId]?
			throw new Error("The block #{blockId} does not exists")

		block = @blocks[blockId]

		parameters ?= {}
		parameters.parentTemplate = @
		
		result = block.render(parameters, @)
		result

	render: (parameters, parentTemplate) ->
		parameters ?= {}
		
		buffer = []
		write = (data) ->
			buffer.push data

		@renderFunction(@, write, parameters, parentTemplate)

		res = buffer.join ''
		res

class coffeePL.Delimiter
	constructor: (delimiter) ->
		@delimiter = delimiter.replace /[-\[\]\/\{\}\(\)\*\+\?\.\\\^\$\|]/g, "\\$&"
		@len = delimiter.length
	
	match: (data, modifiers) ->
		re = new RegExp @delimiter, modifiers
		rs = data.match re
		rs

	search: (data, modifiers) ->
		re = new RegExp @delimiter, modifiers
		rs = data.search re
		rs

class coffeePL.ArgsAdapter
	fromStr: (argStr) ->
		throw new Error("Not Implemented")

	toStr: (args) ->
		throw new Error("Not Implemented")

class coffeePL.URLEncodedArgsAdapter extends coffeePL.ArgsAdapter
	constructor: (@fnToJSON, @fnFromJSON) ->

	fromStr: (argStr) ->
		val = decodeURIComponent argsStr
		val = @fnFromJSON val
		val

	toStr: (args) ->
		val = @fnToJSON args
		val = encodeURIComponent val
		val

class coffeePL.Options
	constructor: ->
		@beginOpenBlock = '<!-- {'
		@endOpenBlock = '} -->'
		@validBlockName = /([\w]+)/

		@closeBlock = (blockName) ->
			return "<!-- {/#{blockName}} -->"

		@beginCode = '<!-- @'
		@endCode = '@ -->'

		@beginResultCode = '${'
		@endResultCode = '}$'

		@writeVar = '_write_'

		@codeContent = (content) ->
			content = content.replace /(^(\r\n|\r|\n)|(\r\n|\r|\n)$)/mg, ''
			return content
		@argsAdapter = new coffeePL.ArgsAdapter

class coffeePL.Config
	constructor: (options) ->
		@beginOpenBlock = new coffeePL.Delimiter options.beginOpenBlock
		@endOpenBlock = new coffeePL.Delimiter options.endOpenBlock

		@validBlockName = options.validBlockName
		@closeBlock = options.closeBlock

		@beginCode = new coffeePL.Delimiter options.beginCode
		@endCode = new coffeePL.Delimiter options.endCode

		@beginResultCode = new coffeePL.Delimiter options.beginResultCode
		@endResultCode = new coffeePL.Delimiter options.endResultCode

		@writeVar = options.writeVar
		@codeContent = options.codeContent

		@argsAdaptor = options.argsAdapter

class coffeePL.CoffeePL
	constructor: (config) ->
		@config = if config? then config else (new coffeePL.Config(new coffeePL.Options))

	createParser: (src, inheritedVariables) ->
		new coffeePL.Parser @config, src, inheritedVariables

class coffeePL.Parser
	constructor: (@config, @inheritedVariables) ->
		@template = null
		@logger = coffeePL.loggerFactory.getLogger("coffeePL.Parser")
		@src = null
	
	_parseBlock: (beginOpenBlockPos, blocks) ->
		endOpenBlockPos = @config.endOpenBlock.search @src
		
		if endOpenBlockPos < 0
			throw new Error "The begin of block in #{beginOpenBlockPos} position does not ends."
		else if endOpenBlockPos <= @config.beginOpenBlock.len
			throw new Error "The end of begin block in #{beginOpenBlockPos} position is invalid."
		
		blockName = @src.substring beginOpenBlockPos + @config.beginOpenBlock.len, endOpenBlockPos
		
		if not @config.validBlockName.test(blockName)
			throw new Error "The block name '#{blockName}' is invalid."

		endBlockDelimiter = new coffeePL.Delimiter @config.closeBlock blockName

		endPos = endBlockDelimiter.search @src

		if endPos < 0
			throw new Error "The block '#{blockName}' does not ends."

		content = @src.substring endOpenBlockPos + @config.endOpenBlock.len, endPos
		content = @config.codeContent content

		tmp = @config.codeContent(@src.substring 0, beginOpenBlockPos)
		tmp += @src.substring endPos + endBlockDelimiter.len

		@src = tmp
		tmp = null

		blockParser = new coffeePL.Parser(@config, @inheritedVariables)
		blockTemplate = blockParser.parse content
		blocks[blockName] = blockTemplate

		true

	_codeId: (i) ->
		"_~~{{~~{{~~_#{i}_~~}}~~}}~~_"

	_parseCode: (startPos, codes, i) ->
		endPos = @config.endCode.search @src

		if endPos < 0
			throw new Error "The code '#{i}', on #{startPos} position does not ends."
		
		if endPos <= startPos
			throw new Error "Ends of result code block '#{i}', in #{endPos} does not be valid."

		content = @src.substring(startPos + @config.beginCode.len, endPos)
		tmp = @config.codeContent(@src.substring 0, startPos)
		tmp += @_codeId(i)
		tmp += @src.substring endPos + @config.endCode.len
		@src = tmp
		tmp = null
		codes[i] = content

		true

	_codeReturnId: (i) ->
		"_~~{{~~{{~~~~_#{i}_~~~~}}~~}}~~_"

	_parseCodeReturn: (startPos, codes, i) ->
		endPos = @config.endResultCode.search @src

		if endPos < 0
			throw new Error "The result code block '#{i}', in #{startPos} position doe not ends."
		
		if endPos <= startPos
			throw new Error "Ends of result code block '#{i}', in #{endPos} does not be valid."

		content = @src.substring(startPos + @config.beginResultCode.len, endPos)
		tmp = @src.substring(0, startPos)
		tmp += @_codeReturnId(i)
		tmp += @src.substring endPos + @config.beginResultCode.len
		@src = tmp
		tmp = null
		codes[i] = content

		true

	parse: (@src) ->
		blocks = {}
		wv = @config.writeVar

		while ((blockPos = @config.beginOpenBlock.search @src) != -1)
			@_parseBlock blockPos, blocks

		codes = {}
		i = 0

		while ((startPos = @config.beginCode.search @src) != -1)
			@_parseCode startPos, codes, i++

		codeReturns = {}
		i = 0

		while ((startPos = @config.beginResultCode.search @src) != -1)
			@_parseCodeReturn startPos, codeReturns, i++

		replaces = [
			[/\r/g, " "]
			[/\n/g, "\\n\\\n"]
			[/\'/g, "\\\u0027"]
			[/(_~~\{\{~~\{\{~~~~_\d+_~~~~\}\}~~\}\}~~_)/g, "');\n\t #{wv}( $1 );\n\t #{wv}('"]
			[/(_~~\{\{~~\{\{~~_)/g, "');\n\t$1"]
			[/(_~~\}\}~~\}\}~~_)/g, "$1\n\t#{wv}('"]
			]

		@src = @src.replace(s, r) for [s, r] in replaces

		for k, v of codes
			@src = @src.replace @_codeId(k), v

		for k2, v2 of codeReturns
			@src = @src.replace @_codeReturnId(k2), v2

		renderSource = """
var out = #{wv};

with(template) {

with(variables) {
	#{wv}('#{@src}');
}

}
		"""

		@src = null

		if @logger.debugEnabled
			@logger.debug "renderSource: #{renderSource}"

		render = new Function("template, #{wv}, variables, parentTemplate", renderSource);

		template = new coffeePL.Template(@config, blocks, render)
		template

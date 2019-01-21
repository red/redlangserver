Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

red-syntax: context [
	throw-error: register-error 'red-syntax

	error-code: [
		'miss-head-red			"missing 'Red' at head"
		'miss-head-block		"missing '[]' at head"
		'miss-expr				"missing 'expr'"
		'miss-block				"missing a block!"
		'unresolve 				"need resolve unknown type"
		'invalid-refine			"invalid refinement"
		'invalid-datatype		"invalid datatype! in block!"
		'invalid-arg			"invalid argument"
	]

	warning-code: [
		'unknown-word			"unknown word"
	]

	create-error-at: function [syntax [map!] type [word!] word [word!]][
		message: case [
			type = 'Error [error-code/(word)]
			type = 'Warning [warning-code/(word)]
		]
		error: make map! reduce [
			'severity DiagnosticSeverity/(type)
			'code to string! word
			'source "Syntax"
			'message message
		]
		either none? syntax/error [
			syntax/error: error
		][
			either block? syntax/error [
				append syntax/error error
			][
				old: syntax/error
				syntax/error: reduce [old error]
			]
		]
	]

	put-syntax: func [syn [map!] item [block!]][
		forall item [
			put syn item/1 item/2
			item: next item
		]
	]

	literal-type: reduce [
		binary! char! date! email! file! float!
		get-path! get-word! lit-path! lit-word!
		integer! issue! logic! map! pair! path!
		percent! refinement! string! tag! time!
		tuple! url!
	]

	symbol-type?: function [type][
		case [
			find reduce [date! float! integer! percent! time! tuple! pair!] type [
				SymbolKind/Number
			]
			type = logic! [
				SymbolKind/Boolean
			]
			find reduce [string! char! email! file! issue! tag! url!] type [
				SymbolKind/String
			]
			type = binary! [
				SymbolKind/Array
			]
			find reduce [lit-word! get-word!] type [
				SymbolKind/Constant
			]
			find reduce [get-path! lit-path! path! refinement!] type [
				SymbolKind/Object
			]
			type = map! [
				SymbolKind/Key
			]
		]
	]

	simple-literal?: function [value][
		either find literal-type value [true][false]
	]

	check-func-args: function [blk [block!]][
		forall blk [
			expr: blk/1/expr
			either any [
				word? expr
				lit-word? expr
				get-word? expr
				refinement? expr
			][
				if all [
					not tail? next blk
					block? expr2: blk/2/expr
				][
					if refinement? expr [
						create-error-at blk/2/syntax 'Error 'invalid-refine
					]
					forall expr2 [
						expr3: expr2/1/expr
						unless any [
							all [
								value? expr3
								datatype? get expr3
							]
							all [
								value? expr3
								typeset? get expr3
							]
						][
							create-error-at blk/2/syntax 'Error 'invalid-datatype
						]
					]
					blk: next blk
				]
			][
				create-error-at blk/1/syntax 'Error 'invalid-arg
			]
		]
	]

	exp-type?: function [pc [block! paren!]][
		if tail? pc [
			syntax: make map! 1
			create-error-at syntax 'Error 'miss-expr
			return reduce [syntax 0]
		]
		expr: pc/1/expr
		expr-type: type? expr
		syntax: pc/1/syntax
		ret: none
		type: none
		blk: none
		step: none

		semicolon-type?: [
			if any [
				all [
					string? expr
					not empty? expr
					expr/1 = #";"
				]
				expr = none
			][
				put-syntax syntax reduce [
					'name "semicolon"
					'CompletionItemKind CompletionItemKind/Text
					'SymbolKind SymbolKind/Null
				]
				ret: exp-type? next pc
				ret/2: ret/2 + 1
				return ret
			]
		]

		include-type?: [
			if all [
				expr-type = issue! 
				"include" = to string! expr
			][
				ret: exp-type? next pc
				put-syntax syntax reduce [
					'name "include"
					'cast ret/1
					'follow ret/2
					'CompletionItemKind CompletionItemKind/Module
					'SymbolKind SymbolKind/Package
				]
				ret/2: ret/2 + 1
				return ret
			]
		]

		slit-type?: [
			if simple-literal? expr-type [
				put-syntax syntax reduce [
					'name "literal"
					'type expr-type
					'CompletionItemKind CompletionItemKind/Constant
					'SymbolKind symbol-type? expr-type
				]
				return reduce [syntax 1]
			]
		]

		set-word-type?: [
			if set-word? expr [
				ret: exp-type? next pc
				put-syntax syntax reduce [
					'name "set-word"
					'cast ret/1
					'follow ret/2
				]
				ret/2: ret/2 + 1
				return ret
			]
		]

		set-path-type?: [
			if set-path? expr [
				ret: exp-type? next pc
				put-syntax syntax reduce [
					'name "set-path"
					'cast ret/1
					'follow ret/2
				]
				ret/2: ret/2 + 1
				return ret
			]
		]

		block-type?: [
			if block? expr [
				unless empty? expr [
					exp-all expr
				]
				put-syntax syntax reduce [
					'name "block"
				]
				return reduce [syntax 1]
			]
		]

		paren-type?: [
			if paren? expr [
				unless empty? expr [
					exp-all expr
				]
				put-syntax syntax reduce [
					'name "paren"
				]
				return reduce [syntax 1]
			]
		]

		keyword-type?: [
			if all [
				expr-type = word!
				find system-words/system-words expr
			][
				type: type? get expr
				put-syntax syntax reduce [
					'name "keyword"
					'expr expr
					'type type
					'CompletionItemKind CompletionItemKind/Keyword
					'SymbolKind SymbolKind/Method
				]

				step: 1
				if all [
					not tail? next pc
					block? pc/2/expr
				][
					case [
						find [has func function] expr [
							step: step + 1
							put-syntax pc/2/syntax reduce [
								'ctx expr
								'ctx-index 1
							]
							check-func-args pc/2/expr
							if all [
								not tail? next next pc
								block? pc/3/expr
							][
								put-syntax pc/3/syntax reduce [
									'ctx expr
									'ctx-index 2
									'spec pc/2/expr
								]
								exp-type? next next pc
								step: step + 1
							]
						]
						find [does context] expr [
							put-syntax pc/2/syntax reduce [
								'ctx expr
								'ctx-index 1
							]
							exp-type? next pc
							step: step + 1
						]
						;find [action! native! function! routine!] type [
						;	step: step
						;]
					]
				]
				if step > 1 [
					put-syntax syntax reduce [
						'follow step - 1
					]
				]
				return reduce [syntax step]
			]
		]

		unknown-type?: [
			if expr-type = word! [
				put-syntax syntax reduce [
					'name "unknown"
					'expr expr
				]
				return reduce [syntax 1]
			]
		]

		do semicolon-type?
		do include-type?
		do slit-type?
		do set-word-type?
		do set-path-type?
		do block-type?
		do paren-type?
		do keyword-type?
		do unknown-type?
		throw-error 'exp-type "not support!" pc/1/expr
	]

	exp-all: function [pc [block! paren!]][
		while [not tail? pc][
			either map? pc/1 [
				type: exp-type? pc
				pc: skip pc type/2
			][
				pc: next pc
			]
		]
	]

	analysis: function [pc [block!]][
		unless pc/1/expr = 'Red [
			create-error-at pc/1/syntax 'Error 'miss-head-red
		]
		unless block? pc/2/expr [
			create-error-at pc/2/syntax 'Error 'miss-head-block
		]
		exp-all pc
		raise-global pc
		resolve-unknown pc
		put-syntax pc/1/syntax ['meta 1]
		put-syntax pc/2/syntax ['meta 2]
	]

	collect-errors: function [top [block! paren!]][
		ret: clear []
		collect-errors*: function [pc [block! paren!]][
			blk: [
				if all [
					pc/1/syntax
					pc/1/syntax/error
				][
					error: copy pc/1/syntax/error
					error/range: red-lexer/to-range pc/1/start pc/1/end
					append ret error
				]
			]
			forall pc [
				either all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					do blk
					collect-errors* pc/1/expr
				][
					if map? pc/1 [
						do blk
					]
				]
			]
		]
		collect-errors* top
		ret
	]

	raise-global: function [top [block!]][
		globals: clear []
		append/only top globals

		raise-set-word: function [pc [block! paren!]][
			raise-set-word*: function [npc [block! paren!]][
				forall npc [
					if all [
						npc/1/syntax
						npc/1/syntax/name = "set-word"
						pc/1/expr = npc/1/expr
					][
						return false
					]
				]
				return true
			]
			if top = head pc [return false]
			par: get-parent top pc/1

			unless any [
				all [
					par/1/syntax/ctx = 'does
					par/1/syntax/ctx-index = 1
				]
				all [
					par/1/syntax/ctx = 'has
					par/1/syntax/ctx-index = 2
				]
				all [
					par/1/syntax/ctx = 'func
					par/1/syntax/ctx-index = 2
				]
			][
				return false
			]
			if any [
				par/1/syntax/ctx = 'has
				par/1/syntax/ctx = 'func
			][
				spec: par/1/syntax/spec
				forall spec [
					if spec/1/expr = to word! pc/1/expr [
						return false
					]
				]
			]
			until [
				unless raise-set-word* head par [return false]
				par: get-parent top par/1
				if empty? par [
					return raise-set-word* top
				]
				par = false
			]
			return true
		]
		raise-global*: function [pc [block! paren!]][
			forall pc [
				either all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					raise-global* pc/1/expr
				][
					if all [
						map? pc/1
						pc/1/syntax
						pc/1/syntax/name = "set-word"
					][
						if raise-set-word pc [
							append/only globals pc/1
						]
					]
				]
			]
		]

		raise-global* top
	]

	resolve-unknown: function [top [block!]][
		globals: last top
		resolve-set-word: function [pc [block! paren!]][
			resolve-set-word*: function [npc [block! paren!]][
				forall npc [
					if all [
						npc/1/syntax
						npc/1/syntax/name = "set-word"
						pc/1/expr = to word! npc/1/expr
					][
						pc/1/syntax/cast: npc/1/syntax/cast
						pc/1/syntax/start: npc/1/start
						pc/1/syntax/end: npc/1/end
						pc/1/syntax/name: "resolved"
						return true
					]
				]
				return false
			]
			if resolve-set-word* head pc [return true]
			if top = head pc [return false]
			par: pc
			while [par: get-parent top par/1][
				if empty? par [
					return resolve-set-word* top
				]
				if resolve-set-word* par/1/expr [return true]
			]
			return false
		]
		resolve-extra: function [item [map!]][
			forall globals [
				if globals/1/expr = item/expr [
					item/syntax/cast: globals/1/syntax/cast
					item/syntax/start: globals/1/start
					item/syntax/end: globals/1/end
					item/syntax/name: "resolved"
					return true
				]
			]
			false
		]
		resolve-unknown*: function [pc [block! paren!]][
			forall pc [
				either all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					resolve-unknown* pc/1/expr
				][
					if all [
						map? pc/1
						pc/1/syntax
						pc/1/syntax/name = "unknown"
					][
						unless resolve-set-word pc [
							unless resolve-extra pc/1 [
								create-error-at pc/1/syntax 'Warning 'unknown-word
							]
						]
					]
				]
			]
		]

		resolve-unknown* top
	]

	get-parent: function [top [block!] item [map!]][
		get-parent*: function [pc [block! paren!] par [block!]][
			forall pc [
				if all [
					map? pc/1
					item/start = pc/1/start
					item/end = pc/1/end
				][return par]
				if all [
					map? pc/1
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					if temp: get-parent* pc/1/expr pc [return temp]
				]
			]
			false
		]
		get-parent* top clear []
	]

	position?: function [top [block! paren!] line [integer!] column [integer!]][
		position*: function [pc [block! paren!] line [integer!] column [integer!]][
			cascade: [
				either all [
					any [
						block? pc/1/expr
						paren? pc/1/expr
					]
					not empty? pc/1/expr
				][
					if ret: position* pc/1/expr line column [return ret]
					return pc
				][
					return pc
				]
			]
			ret: none
			forall pc [
				if all [
					map? pc/1
					any [
						pc/1/start/1 < line
						all [
							pc/1/start/1 = line
							pc/1/start/2 <= column
						]
					]
				][
					either any [
						pc/1/end/1 > line
						all [
							pc/1/end/1 = line
							pc/1/end/2 > column
						]
					][
						do cascade
					][
						if all [
							pc/1/end/1 = line
							pc/1/end/2 = column
							any [
								tail? next pc
								all [
									map? pc/2
									pc/2/start/1 >= line
									pc/2/start/2 <> column
								]
							]
						][
							do cascade
						]
					]
				]
			]
			return none
		]
		if ret: position* top line column [return ret]
		top
	]

	collect-completions: function [top [block!] str [string! none!] line [integer!] column [integer!]][
		words: clear []
		unique?: function [word [string!]][
			forall words [
				if words/1/1 = word [return false]
			]
			true
		]
		collect-set-word: function [pc [block! paren!]][
			forall pc [
				if all [
					map? pc/1
					pc/1/syntax
					pc/1/syntax/name = "set-word"
				][
					word: to string! pc/1/expr
					if any [
						empty? str
						find/match word str
					][
						if unique? word [
							append/only words reduce [word pc/1]
						]
					]
				]
			]
		]
		pc: position? top line column
		if all [
			any [
				block? pc/1/expr
				paren? pc/1/expr
			]
			not empty? pc/1/expr
			any [
				pc/1/end/1 > line
				all [
					pc/1/end/1 = line
					pc/1/end/2 > column
				]
			]
		][
			collect-set-word pc/1/expr
		]
		collect-set-word head pc
		if top = head pc [return words]
		par: pc
		while [par: get-parent top par/1][
			either empty? par [
				break
			][
				collect-set-word head par
			]
		]
		words
	]

	get-completions: function [top [block!] str [string! none!] line [integer!] column [integer!]][
		if any [
			none? str
			empty? str
			#"%" = str/1
			find str #"/"
		][return none]
		if empty? resolve-block: collect-completions top str line column [return none]
		words: reduce ['word]
		forall resolve-block [
			kind: CompletionItemKind/Variable
			cast: resolve-block/1/2/syntax/cast
			if all [
				cast/expr
				find [does has func function] cast/expr
			][
				kind: cast/CompletionItemKind
			]
			append/only words reduce [resolve-block/1/1 kind]
		]
		words
	]

	resolve-completion: function [top [block!] str [string! none!] line [integer!] column [integer!]][
		if any [
			none? str
			empty? str
			#"%" = str/1
			find str #"/"
		][return ""]
		if empty? resolve-block: collect-completions top str line column [return ""]
		forall resolve-block [
			if resolve-block/1/1 = str [
				item: resolve-block/1/2
				cast: item/syntax/cast
				either all [
					cast/expr
					find [does has func function] cast/expr
				][
					return rejoin [str " is a " to string! cast/expr]
				][
					return rejoin [str " is a variable"]
				]
			]
		]
		""
	]

	hover: function [top [block!] line [integer!] column [integer!]][
		pc: position? top line column
		range: red-lexer/to-range pc/1/start pc/1/end
		case [
			pc/1/syntax/name = "set-word" [
				res: rejoin [to string! pc/1/expr " is a variable"]
				return reduce [res range]
			]
			word? pc/1/expr [
				if find system-words/system-words pc/1/expr [
					either datatype? get word [
						res: rejoin [text " is a base datatype!"]
						return reduce [res range]
					][
						res: system-words/get-word-info pc/1/expr
						return reduce [res range]
					]
				]
				res: rejoin [to string! pc/1/expr " is a resolved word"]
				return reduce [res range]
			]
		]
		return none
	]
]

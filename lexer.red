Red [
	Title:   "Red runtime lexer"
	Author:  "bitbegin"
	File: 	 %lexer.red
	Tabs:	 4
	Rights:  "Copyright (C) 2020 Red Foundation. All rights reserved."
]

lexer: context [
	uri-to-file: function [uri [string!] return: [file!]][
		src: copy find/tail uri "file:///"
		to-red-file dehex src
	]
	file-to-uri: function [file [file!] return: [string!]][
		src: to-local-file file
		replace/all src "\" "/"
		insert src "file:///"
		src
	]
	parse-line: function [stack [block!] src [string!]][
		append stack src
		append stack index? src
		while [src: find/tail src #"^/"][
			append stack index? src
		]
	]
	line-pos?: function [stack [block!] line [integer!] column [integer!] return: [string!]][
		pos: pick stack line + 1
		skip at stack/1 pos column - 1
	]
	index-line?: function [stack [block!] pos [integer!] return: [pair!]][
		stack: next stack
		forall stack [
			if all [
				stack/1 <= pos
				any [
					none? stack/2
					stack/2 > pos
				]
			][
				column: pos - stack/1
				return as-pair (index? stack) - 1 column + 1
			]
		]
		none
	]
	pos-line?: function [stack [block!] pos [string!] return: [pair!]][
		index-line? stack index? pos
	]
	pos-range?: function [stack [block!] s [string!] e [string!] return: [block!]][
		range: make block! 4
		append range pos-line? stack s
		append range pos-line? stack e
		range
	]
	;-- Range in lsp is zero-based position, use /keep for print
	form-range: function [range [block!] return: [map!] /keep][
		make map! reduce [
			'start make map! reduce [
				'line either keep [range/1/x][range/1/x - 1]
				'character either keep [range/1/y][range/1/y - 1]
			]
			'end make map! reduce [
				'line either keep [range/2/x][range/2/x - 1]
				'character either keep [range/2/y][range/2/y - 1]
			]
		]
	]
	load-range: function [stack [block!] range [block!]][
		start: line-pos? stack range/1/x range/1/y
		stop: line-pos? stack range/2/x range/2/y
		try [load copy/part start stop]
	]

	remove-last-empty-nested: func [
		item	[block!]
	][
		if all [
			item/nested
			empty? item/nested
		][
			item/nested: none
		]
	]

	insert-node: function [
		stack		[block!]
		lines		[block!]
		src			[string!]
		index		[integer!]
		return:		[block!]
	][
		add-node: func [
			base	[integer!]
			x		[integer!]
			y		[integer!]
			type	[datatype!]
			expr
			error
			/local nested
		][
			nested: select last stack 'nested
			repend/only nested [
				'range reduce [index-line? lines base + x index-line? lines base + y]
				'type  type
				'upper back tail stack
			]
			if expr [
				repend last nested ['expr reduce [expr]]
			]
			if error [
				repend last nested ['error error]
			]
		]
		push-node: func [
			base	[integer!]
			x		[integer!]
			type	[datatype!]
			return:	[block!]
			/local nested
		][
			nested: select last stack 'nested
			repend/only nested [
				'range reduce [index-line? lines base + x]
				'type  type
				'upper back tail stack
			]
			repend last nested ['nested reduce []]
			stack: nested
		]
		lex: func [
			event	[word!]
			input	[string! binary!]
			type	[datatype! word! none!]
			line	[integer!]
			token
			return:	[logic!]
			/local ltype x y err str
		][
			[prescan scan load open close error]
			match-pair: func [
				x	[integer!]
				y	[integer!]
				p?	[logic!]
				err
				/local ntype wtype range nstop item
			][
				nstop: none
				forever [
					unless ntype: select last stack 'type [				;-- check if top
						add-node base x y type none 'only-closed
						break
					]
					wtype: to word! ntype
					if any [											;-- match the upper's type
						ntype = type
						all [
							ntype = path!
							type = set-path!
						]
						all [
							ntype = map!
							type = paren!
						]
						all [
							find [path! lit-path! get-path!] wtype
							type = path!
						]
					][
						item: last stack
						if type = set-path! [
							item/type: type
						]
						if all [
							p?
							find [path! lit-path! get-path!] wtype
						][
							unless err [err: 'unknown]
							either item/error [
								item/error: err
							][
								repend item ['error err]
							]
						]
						append item/range index-line? lines base + y
						remove-last-empty-nested item
						stack: item/upper
						break
					]
					unless nstop [
						nstop: index-line? lines base + y
					]
					item: last stack
					append item/range nstop
					either none? item/error [
						repend item ['error 'only-opened]
					][
						item/error: 'only-opened
					]
					remove-last-empty-nested item
					stack: item/upper
				]
			]
			in-path?: func [
				/local p? nstack ltype
			][
				p?: no
				nstack: stack
				while [
					all [
						nstack
						ltype: select last nstack 'type
						ltype
					]
				][
					if find [path! lit-path! get-path!] to word! ltype [
						p?: yes
						break
					]
					nstack: select last nstack 'upper
				]
				p?
			]

			;print [event mold type token mold input]
			switch event [
				prescan [
					pretoken: token
					true
				]
				scan [
					stoken: either all [start stop][							;-- string! need adjust the position
						as-pair start stop
					][token]
					stype: type
					true
				]
				load [
					add-node base stoken/x stoken/y stype token none
					either in-path? [
						true
					][
						throw stoken/y - 1
					]
				]
				open [
					either type = string! [
						if none? start [
							start: token/x
						]
						true
					][
						push-node base token/x type
						either in-path? [
							true
						][
							throw token/y
						]
					]
				]
				close [
					either type = string! [
						stop: token/y + 1
						true
					][
						nstop: none
						x: token/x
						either find [path! lit-path! get-path!] to word! type [
							y: token/y
						][
							y: token/y + 1
						]
						match-pair x y no none
						either in-path? [
							true
						][
							throw y - 1
						]
					]
				]
				error [
					if type = path! [
						case [
							input/1 = #"/" [			;-- eof after /
								y: token/y + 1
								err: 'slash
							]
							#"/" = input/-1 [			;-- slash
								y: token/y
								err: 'slash
							]
							true [
								y: token/y + 1
								err: 'unknown
							]
						]
						match-pair token/x y yes err
						throw y - 1
					]
					if in-path? [
						either all [					;-- path! like a/:
							token/x + 1 = token/y
							#"/" = input/-2
							#":" = input/-1
						][
							err: reduce ['code 'slash-get 'type type]
							type: path!
						][
							err: 'unknown
						]
						match-pair token/x token/y yes err
						throw token/y - 1
					]
					
					case [
						type = string! [
							;-- multiline
							either start [
								x: start
								y: token/y
							][
								;-- have scaned
								either stoken [
									x: pretoken/x
									y: pretoken/y + 1
								][
									x: token/x
									y: token/y + 1
								]
							]
							add-node base x y type none reduce ['code 'only-opened 'at token]
							throw y - 1
						]
						type = error! [
							either input/1 = #"}" [
								type: string!
								err: 'only-closed
							][
								err: 'only-opened
							]
							add-node base token/x token/y + 1 type none err
							throw token/y
						]
						type = char! [
							either input/1 = #"^"" [
								y: token/y + 1
								err: 'invalid
							][
								y: token/y
								err: 'not-closed
							]
							add-node base token/x y type none err
							throw y - 1
						]
						type = binary! [
							either input/1 = #"}" [
								y: token/y + 1
								err: 'invalid
							][
								y: token/y
								err: 'not-closed
							]
							add-node base token/x y type none err
							throw y - 1
						]
						true [
							add-node base token/x token/y type none 'unknown
							throw token/y - 1
						]
					]
				]
			]
		]

		top: stack
		forever [
			pretoken: none										;-- used for store prescan token
			start: none											;-- used for mark the begin of string!
			stop: none											;-- used for mark the end of string!
			stoken: none										;-- used for store scan token
			stype: none											;-- used for store scan type
			base: index + (index? src) - 1
			pos: catch [system/words/transcode/trace src :lex]
			if block? pos [break]
			;probe pos
			src: skip src pos
		]

		stop: none
		while [stack <> top][
			unless stop [
				stop: index-line? lines index + index? tail src
			]
			item: last stack
			append item/range stop
			either none? item/error [
				repend item ['error 'only-opened]
			][
				item/error: 'only-opened
			]
			remove-last-empty-nested item
			stack: item/upper
		]
		top
	]

	transcode: function [
		src			[string!]
		return:		[block!]
	][
		lines: make block! 64
		parse-line lines src
		range: make block! 1
		append range 1x1
		append range pos-line? lines tail src
		stack: reduce [reduce ['source src 'lines lines 'range range 'nested reduce []]]
		top: stack
		insert-node stack lines src 0
		if empty? top/1/nested [
			top/1/nested: none
		]
		top
	]

	format: function [top [block!]][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]

		format*: function [pc [block!] depth [integer!]][
			pad: depth * 4
			newline pad
			append buffer "["
			forall pc [
				newline pad + 2
				append buffer "["
				if pc/1/expr [
					newline pad + 4
					append buffer "expr: "
					append buffer mold/flat/part pc/1/expr/1 20
				]
				if pc/1/range [
					newline pad + 4
					append buffer "range: "
					append buffer mold/flat pc/1/range
				]
				if pc/1/type [
					newline pad + 4
					append buffer "type: "
					append buffer mold/flat pc/1/type
				]
				if pc/1/nested [
					newline pad + 4
					append buffer "nested: "
					format* pc/1/nested depth + 1
				]
				if pc/1/source [
					newline pad + 4
					append buffer "source: "
					append buffer mold/flat/part pc/1/source 10
				]
				if lines: pc/1/lines [
					newline pad + 4
					append buffer "lines: ["
					newline pad + 6
					append buffer mold/flat/part lines/1 10
					lines: next lines
					forall lines [
						newline pad + 6
						append buffer mold lines/1
					]
					newline pad + 4
					append buffer "]"
				]
				if upper: pc/1/upper [
					newline pad + 4
					append buffer "upper: "
					append buffer mold/flat upper/1/range
				]
				;unless empty? error: pc/1/error [
				;	newline pad + 4
				;	append buffer "error: ["
				;	newline pad + 6
				;	append buffer mold/flat/part error 30
				;	newline pad + 4
				;	append buffer "]"
				;]
				if error: pc/1/error [
					newline pad + 4
					append buffer "error: "
					append buffer mold/flat/part error 30
				]
				newline pad + 2
				append buffer "]"
			]
			newline pad
			append buffer "]"
		]
		format* top 0
		buffer
	]
]

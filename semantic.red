Red [
	Title:   "Red syntax for Red language server"
	Author:  "bitbegin"
	File: 	 %syntax.red
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2019 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

semantic: context [
	throw-error: register-error 'semantic

	create-error: function [pc [block!] type [word!] word [word!] message [string!]][
		error: reduce [
			'severity DiagnosticSeverity/(type)
			'code to string! word
			'source "Syntax"
			'message message
		]
		unless pc/error [
			repend pc ['error error]
			exit
		]
		either block? errors: pc/error [
			forall errors [
				if errors/1/code = error/code [exit]
			]
			repend/only pc/error error
		][
			if errors/code = error/code [exit]
			pc/error: reduce [errors error]
		]
	]

	literal-type: [
		binary! char! date! email! file! float!
		lit-path! lit-word!
		integer! issue! logic! map! pair!
		percent! refinement! string! tag! time!
		tuple! url!
	]

	find-expr: function [top [block!] s [integer!] e [integer!]][
		find-expr*: function [pc [block!] s [integer!] e [integer!]][
			forall pc [
				if all [
					pc/1/s = s
					pc/1/e = e
				][
					return pc
				]
				if pc/1/nested [
					if ret: find-expr* pc/1/nested pos [return ret]
				]
			]
			none
		]
		find-expr* top pos
	]

	position?: function [top [block!] pos [integer!] /outer][
		position*: function [pc [block!] pos [integer!]][
			cascade: [
				if pc/1/nested [
					if ret: position* pc/1/nested pos [return ret]
				]
				return pc
			]
			forall pc [
				if all [
					pc/1/s >= pos
					pc/1/e <= pos
				][
					if pc/1/e <> pos [do cascade]
					if all [
						outer
						any [
							tail? next pc
							pc/2/s <> pos
						]
					][
						return pc
					]
					break
				]
			]
			none
		]
		position* top line column
	]

	get-parent: function [top [block!] item [block!]][
		get-parent*: function [pc [block!] par [block!]][
			forall pc [
				if all [
					item/s = pc/1/s
					item/e = pc/1/e
				][return par]
				if pc/1/nested [
					if ret: get-parent* pc/1/nested pc [return ret]
				]
			]
			none
		]
		if top/1 = item [return none]
		get-parent* top/1/expr top
	]

	syntax-error: function [pc [block!] word [word!] args][
		switch word [
			miss-expr [
				create-error pc/1 'Error 'miss-expr
					rejoin [mold pc/1/expr " -- need a type: " args]
			]
			recursive-define [
				create-error pc/1 'Error 'recursive-define
					rejoin [mold pc/1/expr " -- recursive define"]
			]
			double-define [
				create-error pc/1 'Error 'double-define
					rejoin [mold pc/1/expr " -- double define: " args]
			]
			invalid-arg [
				create-error pc/1 'Error 'invalid-arg
					rejoin [mold pc/1/expr " -- invalid argument for: " args]
			]
			invalid-datatype [
				create-error pc/1 'Error 'invalid-datatype
					rejoin [mold pc/1/expr " -- invalid datatype: " args]
			]
			forbidden-refine [
				create-error pc/1 'Error 'forbidden-refine
					rejoin [mold pc/1/expr " -- forbidden refinement: " args]
			]
		]
	]

	check-func-spec: function [pc [block!] keyword [word!]][
		words: make block! 4
		word: none
		double-check: function [pc [block!]][
			either find words word: to word! pc/1/expr [
				syntax-error pc 'double-define to string! word
			][
				append words word
			]
		]
		check-args: function [npc [block!] par [block! paren! none!]][
			syntax: npc/1/syntax
			syntax/name: "func-param"
			syntax/args: make map! 3
			syntax/args/refs: par
			double-check npc
			ret: next-type npc
			npc2: ret/1
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/args/desc: npc2
					npc2/1/syntax/name: "func-desc"
					npc2/1/syntax/parent: npc
					ret: next-type npc2
					npc3: ret/1
					if tail? npc3 [return npc3]
					if block? npc3/1/expr [
						syntax-error npc3 'invalid-arg mold npc/1/expr
						return next npc3
					]
					return npc3
				]
				type = block! [
					syntax/args/type: npc2
					npc2/1/syntax/name: "func-type"
					npc2/1/syntax/parent: npc
					npc2/1/syntax/args: make map! 1
					npc2/1/syntax/args/types: make block! 4
					expr2: npc2/1/expr
					forall expr2 [
						expr3: expr2/1/expr
						either any [
							all [
								value? expr3
								datatype? get expr3
							]
							all [
								value? expr3
								typeset? get expr3
							]
						][
							append/only npc2/1/syntax/args/types expr3
						][
							syntax-error expr2 'invalid-datatype mold expr3
						]
						expr2/1/syntax/name: "func-type-item"
					]
					ret: next-type npc2
					npc3: ret/1
					if tail? npc3 [return npc3]
					if string? npc3/1/expr [
						syntax/args/desc: npc3
						npc3/1/syntax/name: "func-desc"
						npc3/1/syntax/parent: npc
						return next npc3
					]
					return npc3
				]
			]
			npc2
		]
		check-return: function [npc [block!]][
			syntax: npc/1/syntax
			syntax/name: "func-return"
			double-check npc
			ret: next-type npc
			npc2: ret/1
			if tail? npc2 [
				syntax-error npc 'miss-expr "block!"
				return npc2
			]
			unless block? npc2/1/expr [
				syntax-error npc 'miss-expr "block!"
				return npc2
			]
			syntax/args: make map! 1
			syntax/args/type: npc2
			npc2/1/syntax/name: "func-type"
			npc2/1/syntax/parent: npc
			npc2/1/syntax/args: make map! 1
			npc2/1/syntax/args/types: make block! 4
			expr2: npc2/1/expr
			forall expr2 [
				expr3: expr2/1/expr
				either any [
					all [
						value? expr3
						datatype? get expr3
					]
					all [
						value? expr3
						typeset? get expr3
					]
				][
					append/only npc2/1/syntax/args/types expr3
				][
					syntax-error expr2 'invalid-datatype mold expr3
				]
				expr2/1/syntax/name: "func-type-item"
			]
			ret: next-type npc2
			ret/1
		]
		check-refines: function [npc [block!]][
			collect-args: function [npc [block!] par [block!]][
				while [not tail? npc][
					either word? npc/1/expr [
						append par/1/syntax/args/params npc
						if tail? npc: check-args npc par [return npc]
					][
						either any [
							refinement? npc/1/expr
							npc/1/expr = to set-word! 'return
						][
							return npc
						][
							syntax-error npc 'invalid-arg mold par/1/expr
							npc: next npc
						]
					]
				]
				return npc
			]
			syntax: npc/1/syntax
			syntax/name: "func-refinement"
			syntax/args: make map! 2
			syntax/args/params: make block! 4
			double-check npc
			ret: next-type npc
			npc2: ret/1
			if tail? npc2 [return npc2]
			type: type? npc2/1/expr
			case [
				type = string! [
					syntax/args/desc: npc2
					npc2/1/syntax/name: "func-desc"
					npc2/1/syntax/parent: npc
					ret: next-type npc2
					npc3: ret/1
					return collect-args npc3 npc
				]
				type = word! [
					return collect-args npc2 npc
				]
				type = refinement! [
					return npc2
				]
				true [
					syntax-error npc2 'invalid-arg mold npc/1/expr
					return next npc2
				]
			]
		]
		par: pc
		pc: par/1/expr
		if all [
			block? pc
			empty? pc
		][
			exit
		]
		if string? pc/1/expr [
			par/1/syntax/desc: pc
			pc/1/syntax/name: "func-desc"
			ret: next-type pc
			if tail? pc: ret/1 [exit]
		]
		return-pc: none
		local-pc: none
		until [
			expr: pc/1/expr
			case [
				expr = to set-word! 'return [
					return-pc: pc
					pc: check-return pc
				]
				refinement? expr [
					if any [
						local-pc
						keyword = 'has
					][
						syntax-error pc 'forbidden-refine mold pc/1/expr
					]
					if expr = /local [local-pc: pc]
					pc: check-refines pc
				]
				find [word! lit-word! get-word!] type?/word expr [
					if return-pc [
						syntax-error return-pc 'invalid-arg mold expr
					]
					pc: check-args pc none
				]
				true [
					syntax-error pc 'invalid-arg mold expr
					ret: next-type pc
					pc: ret/1
				]
			]
			tail? pc
		]
	]

	func-arg?: function [spec [block!] word [word!]][
		if block? expr: spec/1/expr [
			forall expr [
				if all [
					find [word! lit-word! get-word! refinement!] type?/word expr/1/expr
					word = to word! expr/1/expr
				][
					return expr
				]
			]
		]
		none
	]

	spec-of-func-body: function [top [block!] pc [block!]][
		npc: head pc
		forall npc [
			if all [
				find [func function has] npc/1/syntax/word
				npc/1/syntax/resolved
				npc/1/syntax/resolved/body = pc
			][
				return npc/1/syntax/resolved/spec
			]
		]
		none
	]

	context-spec?: function [top [block!] pc [block!]][
		if top = pc [return true]
		npc: head pc
		forall npc [
			if all [
				npc/1/syntax/word = 'context
				npc/1/syntax/resolved
				npc/1/syntax/resolved/spec = pc
			][
				return true
			]
		]
		false
	]

	function-body?: function [top [block!] pc [block! paren!]][
		npc: head pc
		forall npc [
			if all [
				npc/1/syntax/word = 'function
				npc/1/syntax/resolved
				npc/1/syntax/resolved/body = pc
			][
				return true
			]
		]
		false
	]

	belong-to-function?: function [top [block!] pc [block! paren!]][
		until [
			if all [
				pc/1/syntax/name = "block"
				function-body? top pc
			][
				return true
			]
			pc: get-parent top pc/1
		]
		false
	]

	func-spec-declare?: function [top [block!] pc [block!]][
		word: to word! pc/1/expr
		find-func-spec: function [par [block!]][
			if all [
				block? par/1/expr
				par <> top
				spec: spec-of-func-body top par
				ret: func-arg? spec word
			][
				return ret
			]
			none
		]
		par: pc
		forever [
			unless par: get-parent top par/1 [
				return none
			]
			if ret: find-func-spec par [
				return ret
			]
		]
		none
	]

	recent-set?: function [top [block!] pc [block!]][
		word: to word! pc/1/expr
		find-set-word: function [npc [block! paren!]][
			forall npc [
				if all [
					pc <> npc
					any [
						set-word? npc/1/expr
						all [
							word? npc/1/expr
							npc/-1
							npc/-1/expr = 'set
						]
					]
					word = to word! npc/1/expr
				][
					return npc
				]
			]
			none
		]
		npc: pc
		until [
			if ret: find-set-word head npc [
				return ret
			]
			not npc: get-parent top npc/1
		]
		none
	]

	word-value?: function [top [block!] pc [block! paren!]][
		unless any-word? pc/1/expr [return none]
		word: to word! pc/1/expr
		find-set-word: function [npc [block! paren!]][
			forall npc [
				if all [
					pc <> npc
					set-word? npc/1/expr
					word = to word! npc/1/expr
				][
					;-- tail
					unless cast: npc/1/syntax/cast [
						return reduce [npc cast]
					]
					;-- recursive define
					if cast = pc [
						syntax-error npc 'recursive-define none
						return none
					]
					;-- nested define
					if all [
						any [
							word? cast/1/expr
							get-word? cast/1/expr
						]
						ret: word-value? top cast
					][
						return ret
					]
					return reduce [npc cast]
				]
			]
			none
		]
		find-func-spec: function [par [block! paren! none!]][
			unless par [return none]
			if all [
				par/1/syntax/name = "block"
				spec: spec-of-func-body top par
				ret: func-arg? spec word
			][
				return reduce [ret none]
			]
			none
		]
		npc: pc
		until [
			par: get-parent top npc/1
			if any [
				ret: find-func-spec par
				ret: find-set-word head npc
			][
				return ret
			]
			not npc: par
		]
		none
	]

	exp-all: function [top [block! paren!]][

		resolve-set: function [pc [block!]][
			resolve-set*: function [npc [block!]][
				unless cast: next npc [
					syntax-error pc 'miss-expr "any-type!"
					exit
				]
				if find literal-type type?/word cast/1/expr [
					repend pc/1/syntax ['value cast]
					repeat pc/1/syntax ['step 1 + (index? cast) - (index pc)]
					exit
				]
				if word? cast/1/expr [
					repend pc/1/syntax ['cast cast]
					repeat pc/1/syntax ['step 1 + (index? cast) - (index pc)]
					exit
				]
				if set-word? cast/1/expr [
					resolve-set* cast
				]
			]
			unless pc/1/syntax [
				repend pc/1 ['syntax []]
			]
			if all [
				none? pc/1/syntax/declare
				declare: func-spec-declare? top pc
			][
				repend pc/1/syntax ['declare declare]
			]
			resolve-set* pc
		]

		resolve-word: function [pc [block!]][
			unless pc/1/syntax [
				repend pc/1 ['syntax []]
			]
			if all [
				none? pc/1/syntax/declare
				declare: func-spec-declare? top pc
			][
				repend pc/1/syntax ['declare declare]
			]
			if recent: recent-set? pc [
				repend pc/1/syntax ['recent recent]
			]
		]

		word-value?: function [pc [block!]][
			if set-word? pc/1/expr [
				unless pc/1/syntax [resolve-set pc]
				if value: pc/1/syntax/value [
					return reduce [pc/1/syntax/step value]
				]
				if cast: pc/1/syntax/cast [
					return reduce [pc/1/syntax/step cast]
				]
				return none
			]
			if any [
				word? pc/1/expr
				get-word? pc/1/expr
			][
				unless pc/1/syntax [resolve-word pc]
				if recent: pc/1/syntax/recent [
					if ret: word-value? recent [
						return reduce [1 ret/2]
					]
				]
			]
			none
		]

		resolve-func: function [pc [block!]][
			unless npc: next pc [
				syntax-error pc 'miss-expr "block!"
			]
			step: 1
			either block? npc [
				spec: npc
			][
				
			]
		]

		resolve-refer: function [pc [block!]][
			forall pc [
				if pc/1/expr = 'set [
					if any [
						none? npc: next pc
						not find [word! path! lit-word! lit-path!] type?/word npc/1/expr
					][
						syntax-error pc 'miss-expr "word!/path!/lit-word!/lit-path!"
						exit
					]
					resolve-set npc
					exit
				]
				if any [
					set-word? pc/1/expr
					set-path? pc/1/expr
				][
					resolve-set pc
					exit
				]
				if any [
					word? pc/1/expr
					path? pc/1/expr
					get-word? pc/1/expr
					get-path? pc/1/expr
				][
					if any [
						word? pc/1/expr
						get-word? pc/1/expr
					][
						resolve-word pc
					]
					if all [
						none? pc/1/syntax/declare
						none? pc/1/syntax/recent
					][
						word: either any [
							word? pc/1/expr
							get-word? pc/1/expr
						][
							to word! pc/1/expr
						][
							to word! pc/1/expr/1
						]
						repend pc/1 ['syntax reduce ['word word]]
						if find [func function does has context all any] word [
							resolve-func pc
						]
					]
				]
			]
		]

		exp-func?: function [pc [block! paren!]][
			if all [
				pc/1/syntax/name = "unknown-keyword"
				find [func has does function context all any] pc/1/syntax/word
			][
				pc/1/syntax/name: append copy "keyword-" to string! pc/1/syntax/word
				npc: none
				step: none
				ret: next-type pc
				step: ret/2
				if tail? npc: ret/1 [
					syntax-error pc 'miss-expr "block!"
					return step
				]
				pc/1/syntax/casts: make map! 2
				either pc/1/syntax/word = 'does [
					pc/1/syntax/casts/body: npc
				][
					pc/1/syntax/casts/spec: npc
				]
				step: step + npc/1/syntax/step - 1
				either block? npc/1/expr [
					spec: npc
				][
					unless any [
						set-word? npc/1/expr
						word? npc/1/expr
					][
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					either spec: npc/1/syntax/cast [
						unless block? spec/1/expr [
							spec: spec/1/syntax/value
						]
					][
						spec: npc/1/syntax/value
					]
					unless spec [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					unless block? spec/1/expr [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
				]
				pc/1/syntax/resolved: make map! 2
				either pc/1/syntax/word = 'does [
					pc/1/syntax/resolved/body: spec
					spec/1/syntax/into: true
				][
					pc/1/syntax/resolved/spec: spec
					if find [context all any] pc/1/syntax/word [
						spec/1/syntax/into: true
					]
				]
				if find [does context all any] pc/1/syntax/word [return step + 1]
				check-func-spec spec pc/1/syntax/word
				ret: next-type skip pc step
				step: step + ret/2
				if tail? npc: ret/1 [
					syntax-error pc 'miss-expr "block!"
					return step + 1
				]
				pc/1/syntax/casts/body: npc
				step: step + npc/1/syntax/step - 1
				either block? npc/1/expr [
					body: npc
				][
					unless any [
						set-word? npc/1/expr
						word? npc/1/expr
					][
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					either body: npc/1/syntax/cast [
						unless block? body/1/expr [
							body: body/1/syntax/value
						]
					][
						body: npc/1/syntax/value
					]
					unless body [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
					unless block? body/1/expr [
						syntax-error pc 'miss-expr "block!"
						return step + 1
					]
				]
				pc/1/syntax/resolved/body: body
				body/1/syntax/into: true
				return 1 + step
			]
			none
		]

		resolve-func: function [pc [block! paren!]][
			while [not tail? pc][
				either step: exp-func? pc [
					pc/1/syntax/step: step
				][
					step: 1
				]
				pc: skip pc step
			]
		]

		exp-depth: function [pc [block!] depth [integer!]][
			if pc/1/depth > depth [exit]
			if pc/1/depth = depth [
				resolve-type pc
				resolve-refer pc
				resolve-func pc
				exit
			]
			forall pc [
				if all [
					pc/1/nested
					pc/1/syntax/into
				]
					exp-depth pc/1/nested depth
				]
			]
		]

		max-depth: top/1/max-depth
		repeat depth max-depth [
			exp-depth top/1/nested depth
		]
	]

	analysis: function [top [block!]][
		if empty? top [exit]
		unless all [
			top/1/nested
			block? top/1/nested
		][throw-error 'analysis "expr isn't a block!" top/1]
		repend top/1 ['syntax syntax: make block! 3]
		repend syntax [
			'name "top"
			'step 1
			'extra make block! 20
		]
		pc: top/1/nested
		unless pc/1/expr = 'Red [
			syntax-error pc 'miss-expr "'Red' for Red File header"
		]
		unless block? pc/2/expr [
			syntax-error next pc 'miss-expr "block! for Red File header"
		]
		exp-all top
		;resolve-keyword top
	]

	formatxx: function [top [block!]][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]
		format*: function [pc [block! paren!] depth [integer!]][
			pad: depth * 4
			newline pad
			either block? pc [
				blk?: true
				append buffer "["
			][
				append buffer "("
			]
			forall pc [
				newline pad + 2
				append buffer "#("
				newline pad + 4
				append buffer "range: "
				append buffer mold pc/1/range
				newline pad + 4
				append buffer "expr: "
				either any [
					block? pc/1/expr
					paren? pc/1/expr
				][
					either empty? pc/1/expr [
						either block? pc/1/expr [
							append buffer "[]"
						][
							append buffer "()"
						]
					][
						format* pc/1/expr depth + 1
					]
				][
					append buffer mold/flat pc/1/expr
				]
				newline pad + 4
				append buffer "depth: "
				append buffer mold pc/1/depth
				if pc/1/max-depth [
					newline pad + 4
					append buffer "max-depth: "
					append buffer mold pc/1/max-depth
				]
				newline pad + 4
				append buffer "syntax: #("
				newline pad + 6
				append buffer "name: "
				append buffer pc/1/syntax/name
				if pc/1/syntax/step [
					newline pad + 6
					append buffer "step: "
					append buffer pc/1/syntax/step
				]
				if pc/1/syntax/error [
					newline pad + 6
					append buffer "error: "
					append buffer mold/flat pc/1/syntax/error
				]
				if pc/1/syntax/meta [
					newline pad + 6
					append buffer "meta: "
					append buffer pc/1/syntax/meta
				]
				if pc/1/syntax/cast [
					newline pad + 6
					append buffer "cast: "
					append buffer mold/flat pc/1/syntax/cast/1/range
				]
				if pc/1/syntax/parent [
					newline pad + 6
					append buffer "parent: "
					append buffer mold/flat pc/1/syntax/parent/1/range
				]
				if pc/1/syntax/refer [
					newline pad + 6
					append buffer "refer: "
					append buffer mold/flat pc/1/syntax/refer/1/range
				]
				if pc/1/syntax/value [
					newline pad + 6
					append buffer "value: "
					append buffer mold/flat pc/1/syntax/value/1/range
				]
				if pc/1/syntax/word [
					newline pad + 6
					append buffer "word: "
					append buffer pc/1/syntax/word
				]

				if pc/1/syntax/desc [
					newline pad + 6
					append buffer "desc: "
					append buffer mold/flat pc/1/syntax/desc/1/range
				]

				if pc/1/syntax/args [
					newline pad + 6
					append buffer "args: #("
					if pc/1/syntax/args/refs [
						newline pad + 8
						append buffer "refs: "
						append buffer mold/flat pc/1/syntax/args/refs/1/range
					]
					if pc/1/syntax/args/desc [
						newline pad + 8
						append buffer "desc: "
						append buffer mold/flat pc/1/syntax/args/desc/1/range
					]
					if pc/1/syntax/args/type [
						newline pad + 8
						append buffer "type: "
						append buffer mold/flat pc/1/syntax/args/type/1/range
					]
					if pc/1/syntax/args/types [
						newline pad + 8
						append buffer "types: "
						append buffer mold/flat pc/1/syntax/args/types
					]
					if params: pc/1/syntax/args/params [
						newline pad + 8
						append buffer "params: ["
						forall params [
							newline pad + 10
							append buffer mold/flat params/1/range
						]
						newline pad + 8
						append buffer "]"
					]
					newline pad + 6
					append buffer ")"
				]

				if pc/1/syntax/casts [
					newline pad + 6
					append buffer "casts: #("
					casts: words-of pc/1/syntax/casts
					forall casts [
						newline pad + 8
						append buffer mold casts/1
						append buffer ": "
						pos: pc/1/syntax/casts/(casts/1)
						append buffer mold/flat pos/1/range
					]
					newline pad + 6
					append buffer ")"
				]

				if pc/1/syntax/resolved [
					newline pad + 6
					append buffer "resolved: #("
					resolved: words-of pc/1/syntax/resolved
					forall resolved [
						newline pad + 8
						append buffer mold resolved/1
						append buffer ": "
						pos: pc/1/syntax/resolved/(resolved/1)
						append buffer mold/flat pos/1/range
					]
					newline pad + 6
					append buffer ")"
				]

				if pc/1/syntax/into [
					newline pad + 6
					append buffer "into: "
					append buffer mold pc/1/syntax/into
				]

				if extra: pc/1/syntax/extra [
					newline pad + 6
					append buffer "extra: ["
					forall extra [
						newline pad + 8
						append buffer mold/flat extra/1/range
					]
					newline pad + 6
					append buffer "]"
				]

				if completions: pc/1/syntax/completions [
					newline pad + 6
					append buffer "completions: ["
					forall completions [
						newline pad + 8
						append buffer mold/flat completions/1/range
					]
					newline pad + 6
					append buffer "]"
				]

				newline pad + 4
				append buffer ")"
				newline pad + 2
				append buffer ")"
			]
			newline pad
			either blk? [
				append buffer "]"
			][
				append buffer ")"
			]
		]
		format* top 0
		buffer
	]

	format: function [top [block!] /semantic][
		buffer: make string! 1000
		newline: function [cnt [integer!]] [
			append buffer lf
			append/dup buffer " " cnt
		]
		format*: function [pc [block! paren!] depth [integer!]][
			pad: depth * 4
			newline pad
			append buffer "["
			forall pc [
				newline pad + 2
				append buffer "["
				newline pad + 4
				append buffer "expr: "
				append buffer mold/flat/part pc/1/expr 20
				newline pad + 4
				append buffer "s: "
				append buffer mold pc/1/s
				newline pad + 4
				append buffer "e: "
				append buffer mold pc/1/e
				newline pad + 4
				append buffer "depth: "
				append buffer mold pc/1/depth
				if pc/1/nested [
					newline pad + 4
					append buffer "nested: "
					format* pc/1/nested depth + 1
				]
				if pc/1/source [
					newline pad + 4
					append buffer "source: "
					append buffer mold/flat/part pc/1/source 20
				]
				if pc/1/max-depth [
					newline pad + 4
					append buffer "max-depth: "
					append buffer pc/1/max-depth
				]
				if all [
					semantic
					pc/1/syntax
				][
					newline pad + 4
					append buffer "syntax: ["
					
					if pc/1/syntax/word [
						newline pad + 6
						append buffer "word: "
						append buffer pc/1/syntax/word
					]

					if pc/1/syntax/step [
						newline pad + 6
						append buffer "step: "
						append buffer pc/1/syntax/step
					]

					if value: pc/1/syntax/value [
						newline pad + 6
						append buffer "value: "
						append buffer mold/flat reduce [value/1/s value/1/e]
					]

					if cast: pc/1/syntax/cast [
						newline pad + 6
						append buffer "cast: "
						append buffer mold/flat reduce [cast/1/s cast/1/e]
					]

					if declare: pc/1/syntax/declare [
						newline pad + 6
						append buffer "declare: "
						append buffer mold/flat reduce [declare/1/s declare/1/e]
					]

					if resolved: pc/1/syntax/resolved [
						newline pad + 6
						append buffer "resolved: ["
						i: 0
						len: (length? resolved) / 2
						loop len [
							newline pad + 8
							append buffer resolved/(i * 2 + 1)
							append buffer ": "
							value: resolved/(i * 2 + 2)
							append buffer mold/flat reduce [value/1/s value/1/e]
							i: i + 1
						]
					]

					newline pad + 4
					append buffer "]"
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

	to-range: function [pc [block!]][
		ast/to-range ast/form-pos pc/1/s ast/form-pos pc/1/e
	]

	collect-errors: function [top [block!]][
		ret: make block! 4
		collect-errors*: function [pc [block!]][
			blk: [
				if pc/1/error [
					error: pc/1/error
					either block? error [
						forall error [
							err: make map! error/1
							err/range: to-range pc
							append ret err
						]
					][
						err: make map! error
						err/range: to-range pc
						append ret err
					]
				]
			]
			forall pc [
				either pc/1/nested [
					do blk
					collect-errors* pc/1/nested
				][
					do blk
				]
			]
		]
		collect-errors* top
		ret
	]

	collect-completions: function [top [block!] pc [block! paren!] /extra][
		ret: clear []
		str: clear ""
		unique?: function [word [string!]][
			npc: ret
			forall npc [
				if word = to string! npc/1/expr [return false]
			]
			true
		]
		collect*: function [npc [block! paren!]][
			word: to string! npc/1/expr
			if any [
				empty? str
				all [
					str <> word
					find/match word str
				]
			][
				if all [
					unique? word
					npc <> pc
				][
					append ret npc/1
				]
			]
		]
		collect-set-word: function [npc [block! paren!]][
			forall npc [
				if set-word? npc/1/expr [
					collect* npc
				]
			]
		]

		collect-arg: function [spec [block! paren!]][
			if block? npc: spec/1/expr [
				forall npc [
					if find [word! lit-word! get-word! refinement!] type?/word npc/1/expr [
						collect* npc
					]
				]
			]
		]

		collect-func-spec: function [par [block! paren! none!]][
			unless par [exit]
			if all [
				par/1/syntax/name = "block"
				spec: spec-of-func-body top par
			][
				collect-arg spec
			]
		]

		unless extra [
			either all [
				any [
					block? pc/1/expr
					paren? pc/1/expr
				]
				not empty? pc/1/expr
				any [
					pc/1/range/3 > line
					all [
						pc/1/range/3 = line
						pc/1/range/4 > column
					]
				]
			][
				collect-func-spec pc
				collect-set-word pc/1/expr
			][
				unless word? pc/1/expr [
					return ret
				]
				str: to string! pc/1/expr
			]

			npc: pc
			until [
				par: get-parent top npc/1
				collect-func-spec par
				collect-set-word head npc
				not npc: par
			]
		]
		if npc: top/1/syntax/extra [
			forall npc [
				if set-word? npc/1/expr [
					collect* npc
				]
			]
		]
		ret
	]
]

source-syntax: context [
	sources: make block! 4
	last-comps: []

	find-source: function [uri [string!]][
		forall sources [
			if sources/1/1 = uri [
				return sources
			]
		]
		false
	]

	add-source-to-table: function [uri [string!] blk [block!]][
		either item: find-source uri [
			item/1/2: blk
		][
			append/only sources reduce [uri blk]
		]
	]

	add-source: function [uri [string!] code [string!]][
		if map? res: red-lexer/analysis code [
			add-source-to-table uri res/stack
			range: red-lexer/to-range res/pos res/pos
			line-cs: charset [#"^M" #"^/"]
			info: res/error/arg2
			if part: find info line-cs [info: copy/part info part]
			message: rejoin [res/error/id " ^"" res/error/arg1 "^" at: ^"" info "^""]
			return reduce [
				make map! reduce [
					'range range
					'severity 1
					'code 1
					'source "lexer"
					'message message
				]
			]
		]
		add-source-to-table uri res
		if error? err: try [red-syntax/analysis res][
			pc: err/arg3
			range: red-lexer/to-range pc/2 pc/2
			return reduce [
				make map! reduce [
					'range range
					'severity 1
					'code 1
					'source "syntax"
					'message err/arg2
				]
			]
		]
		red-syntax/collect-errors res
	]

	get-completions: function [uri [string!] line [integer!] column [integer!]][
		unless item: find-source uri [
			return none
		]
		top: item/1/2
		unless pc: red-syntax/position? top line column [
			return none
		]
		unless any [
			file? pc/1/expr
			path? pc/1/expr
			word? pc/1/expr
		][
			return none
		]
		str: mold pc/1/expr
		comps: clear last-comps

		if word? pc/1/expr [
			forall sources [
				top2: sources/1/2
				collects: either sources/1/1 = uri [
					red-syntax/collect-completions top2 pc
				][
					red-syntax/collect-completions/extra top2 pc
				]
				forall collects [
					comp: make map! reduce [
						'label to string! collects/1/expr
						'kind CompletionItemKind/Variable
						'data make map! reduce [
							'uri uri
							'range mold collects/1/range
						]
					]
					if sources/1/1 = uri [
						put comp 'preselect true
					]
					append comps comp
				]
			]
			words: system-words/system-words
			forall words [
				sys-word: mold words/1
				if find/match sys-word str [
					append comps make map! reduce [
						'label sys-word
						'kind CompletionItemKind/Keyword
					]
				]
			]
			return comps
		]
		if path? pc/1/expr [
			completions: red-complete-ctx/red-complete-path str no
			forall completions [
				append comps make map! reduce [
					'label completions/1
					'kind CompletionItemKind/Property
				]
			]
			return comps
		]

		if file? pc/1/expr [
			completions: red-complete-ctx/red-complete-file str no
			forall completions [
				append comps make map! reduce [
					'label completions/1
					'kind CompletionItemKind/File
				]
			]
			return comps
		]
	]

	resolve-completion: function [params [map!]][
		if params/kind = CompletionItemKind/Keyword [
			word: to word! params/label
			if datatype? get word [
				return rejoin [params/label " is a base datatype!"]
			]
			return system-words/get-word-info word
		]
		if all [
			params/kind = CompletionItemKind/Variable
			params/data
		][
			uri: params/data/uri
			range: load params/data/range
			unless item: find-source uri [
				return none
			]
			top: item/1/2
			unless pc: red-syntax/find-expr top range [
				return none
			]
			unless cast: pc/1/syntax/cast [
				return none
			]
			either any [
				word? cast/1/expr
				path? cast/1/expr
			][
				if val: cast/1/syntax/value [
					return rejoin [params/label " is a " mold type? val/1/expr " datatype!"]
				]
				if refer: cast/1/syntax/refer [
					if refer/1/syntax/name = "func-param" [
						return rejoin [params/label " is function parameter!"]
					]
					if refer/1/syntax/name = "func-refinement" [
						return rejoin [params/label " is function refinement!"]
					]
				]
				if find [func function does has] cast/1/syntax/word [
					return rejoin [params/label " is a function!"]
				]
				if cast/1/syntax/word = 'context [
					return rejoin [params/label " is a context!"]
				]
			][
				return rejoin [params/label " is a " mold type? cast/1/expr " datatype!"]
			]
		]
		none
	]

	system-completion-kind: function [word [word!]][
		type: type? get word
		kind: case [
			datatype? get word [
				CompletionItemKind/Keyword
			]
			typeset? get word [
				CompletionItemKind/Keyword
			]
			op! = type [
				CompletionItemKind/Operator
			]
			find reduce [action! native! function! routine!] type [
				CompletionItemKind/Function
			]
			object! = type [
				CompletionItemKind/Class
			]
			true [
				CompletionItemKind/Variable
			]
		]
	]

	hover: function [uri [string!] line [integer!] column [integer!]][
		unless item: find-source uri [
			return none
		]
		top: item/1/2
		unless pc: red-syntax/position? top line column [
			return none
		]
		none
	]
]

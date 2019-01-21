Red []

#include %error.red
#include %lsp-const.red
;#include %json.red
#include %system-words.red
#include %lexer.red
#include %syntax.red


file: %testx.red
code: read file
code-analysis: clear []
code-analysis: red-lexer/analysis code tail code
red-syntax/analysis code-analysis
forall code-analysis [
    probe code-analysis/1
]

print "Error/Warning: ---------------------------------------"
probe red-syntax/collect-errors code-analysis

;probe red-syntax/position? code-analysis 12 1
probe red-syntax/collect-completions code-analysis "f" 12 1
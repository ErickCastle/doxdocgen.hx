;; Development config. Helix loads <workspace>/.helix/{helix.scm,init.scm} when
;; both exist, so the plugin runs straight from the working tree - no install.
;; Functions provided here become `:` commands; this is the pattern to copy into
;; your own ~/.config/helix/helix.scm.
(require (prefix-in dox. "../doxdocgen.scm"))
(require (prefix-in test. "../tests/parser-test.scm"))

(provide doxygen-comment
         doxygen-file-comment
         doxygen-newline
         doxygen-selftest)

;;@doc
;; Generate a Doxygen block for the declaration at or below the cursor.
(define (doxygen-comment)
  (dox.doxygen-comment))

;;@doc
;; Generate a Doxygen file header block at the top of the buffer.
(define (doxygen-file-comment)
  (dox.doxygen-file-comment))

;;@doc
;; Enter in insert mode: expand `/**` into a Doxygen block.
(define (doxygen-newline)
  (dox.doxygen-newline))

;;@doc
;; Run the parser checks against the focused buffer (open sample.cpp first).
(define (doxygen-selftest)
  (test.run-parser-selftest))

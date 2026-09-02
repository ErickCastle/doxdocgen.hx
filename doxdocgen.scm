;; Public entry point. Everything provided here becomes a Helix typed command
;; once re-exported from your helix.scm.
(require "helix/static.scm")
(require "cogs/config.scm")
(require "cogs/generate.scm")
(require "cogs/trigger.scm")

(provide doxdocgen-configure
         doxdocgen-version
         doxygen-comment
         doxygen-file-comment
         doxygen-newline
         keymap-for-doxdocgen
         install-doxdocgen-keymap!)

(define (doxdocgen-version)
  "0.1.0")

;;@doc
;; Generate a Doxygen block for the declaration at or below the cursor.
(define (doxygen-comment)
  (generate-at-line (get-current-line-number)))

;;@doc
;; Generate a Doxygen file header block at the top of the buffer.
(define (doxygen-file-comment)
  (generate-file-header))

;;@doc
;; Bound to Enter in insert mode for C/C++ buffers by install-doxdocgen-keymap!.
(define (doxygen-newline)
  (trigger-newline))

;;@doc
;; Install the `/**` + Enter trigger for C/C++ buffers.
(define (install-doxdocgen-keymap! . args)
  (apply install-keymap! args))

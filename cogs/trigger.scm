;; Insert-mode Enter handling and the per-extension keymap.
(require-builtin helix/core/text as text.)
(require "helix/static.scm")
(require "helix/misc.scm")
(require "helix/keymaps.scm")
(require "strings.scm")
(require "config.scm")
(require "rope-util.scm")
(require "generate.scm")

(provide trigger-newline
         doxdocgen-extensions
         keymap-for-doxdocgen
         install-keymap!)

(define doxdocgen-extensions
  (list "c" "h" "cpp" "hpp" "cc" "cxx" "hxx" "ipp" "inl"))

(define (text-before-cursor rope line line-text)
  (let* ([line-start (text.rope-line->char rope line)]
         [offset (min (max (- (cursor-position) line-start) 0) (string-length line-text))])
    (substring line-text 0 offset)))

;;@doc
;; Enter in insert mode: expand the trigger sequence, otherwise insert a normal
;; indent-aware newline.
(define (trigger-newline)
  (let* ([rope (current-rope)]
         [line (get-current-line-number)]
         [line-text (rope-line-text rope line)]
         [before (text-before-cursor rope line line-text)])
    (if (equal? (string-trim before) (dox-ref 'trigger-sequence))
        (generate-from-trigger line)
        (insert-newline-hook (line-indent line-text)))))

;;@doc
;; A copy of the global keymap with Enter rebound in insert mode.
(define (keymap-for-doxdocgen)
  (let ([km (deep-copy-global-keybindings)])
    (merge-keybindings km (hash "insert" (hash "ret" ':doxygen-newline)))
    km))

(define (extensions->map extensions km acc)
  (if (null? extensions)
      acc
      (extensions->map (cdr extensions) km (hash-insert acc (car extensions) km))))

;;@doc
;; Install the Enter override for C/C++ buffers. Optionally pass a list of
;; extensions. This replaces the extension keymap table wholesale, so if you set
;; your own, use `keymap-for-doxdocgen` and merge instead.
(define (install-keymap! . args)
  (let ([extensions (if (null? args) doxdocgen-extensions (car args))])
    (set-global-buffer-or-extension-keymap
     (extensions->map extensions (keymap-for-doxdocgen) (hash)))))

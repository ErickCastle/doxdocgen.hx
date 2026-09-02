;; Turns a parsed declaration into buffer edits. Requires the embedded engine.
(require-builtin helix/core/text as text.)
(require-builtin steel/time)
(require "helix/static.scm")
(require "helix/misc.scm")
(require "helix/editor.scm")
(require "strings.scm")
(require "config.scm")
(require "render.scm")
(require "parser.scm")
(require "rope-util.scm")

(provide current-env
         current-file-name
         generate-at-line
         generate-file-header
         generate-from-trigger)

(define (basename path)
  (let ([parts (string-split-char path #\/)])
    (if (null? parts) path (list-ref parts (- (length parts) 1)))))

(define (current-file-name)
  (let ([path (editor-document->path (current-doc-id))])
    (if path (basename path) "")))

(define (current-env)
  (hash 'date (local-time/now! (dox-ref 'date-format))
        'year (local-time/now! "%Y")
        'file (current-file-name)
        'author (dox-ref 'author-name)
        'email (dox-ref 'author-email)))

(define (goto-char index)
  (set-current-selection-object! (range->selection (range index index))))

(define (block-with-newline block)
  (hash 'text (string-append (hash-ref block 'text) (dox-ref 'line-ending))
        'cursor-offset (hash-ref block 'cursor-offset)))

(define (insert-block-at index block)
  (goto-char index)
  (insert_string (hash-ref block 'text))
  (goto-char (+ index (hash-ref block 'cursor-offset))))

(define (replace-span-with start end block)
  (set-current-selection-object! (range->selection (range start end)))
  (replace-selection-with (hash-ref block 'text))
  (goto-char (+ start (hash-ref block 'cursor-offset))))

;;@doc
;; Insert a block above the declaration found at or below `line`.
(define (generate-at-line line)
  (let ([decl (declaration-at-line line)])
    (if (not decl)
        (begin (set-error! "doxdocgen: no declaration found below the cursor") #f)
        (let* ([rope (current-rope)]
               [index (text.rope-line->char rope (hash-ref decl 'line))]
               [block (block-with-newline (render-block decl (current-env)))])
          (insert-block-at index block)
          #t))))

;;@doc
;; Insert a file header block at the top of the buffer.
(define (generate-file-header)
  (let ([block (block-with-newline
                (render-block (file-declaration (current-file-name)) (current-env)))])
    (insert-block-at 0 block)
    #t))

(define (fallback-declaration line indent)
  (if (= line 0)
      (file-declaration (current-file-name))
      (declaration 'other "" "" '() '() #f #f indent)))

;; Replaces the whole trigger line, which also absorbs any `*/` that auto-pairs
;; inserted when `/**` was typed.
(define (generate-from-trigger line)
  (let* ([rope (current-rope)]
         [line-text (rope-line-text rope line)]
         [start (text.rope-line->char rope line)]
         [end (+ start (string-length (string-trim-right line-text)))]
         [indent (line-indent line-text)]
         [found (declaration-at-line (+ line 1))]
         [decl (if found found (fallback-declaration line indent))]
         [block (render-block decl (current-env))])
    (replace-span-with start end block)
    #t))

;; Buffer/rope access helpers. Requires the embedded engine - not headless-safe.
(require-builtin helix/core/text as text.)
(require "helix/editor.scm")

(provide current-doc-id
         current-rope
         rope-byte->char
         rope-line-text
         rope-line-count
         line-indent
         first-non-blank-line)

(define (current-doc-id)
  (editor->doc-id (editor-focus)))

(define (current-rope)
  (editor->text (current-doc-id)))

;; helix/core/text exposes rope-char->byte but no inverse, so walk from the
;; start of the containing line and count characters.
(define (rope-byte->char rope byte-index)
  (let* ([line (text.rope-byte->line rope byte-index)]
         [line-char (text.rope-line->char rope line)]
         [line-byte (text.rope-line->byte rope line)])
    (+ line-char
       (string-length (text.rope->string (text.rope->byte-slice rope line-byte byte-index))))))

(define (rope-line-count rope)
  (text.rope-len-lines rope))

(define (rope-line-text rope line)
  (text.rope->string (text.rope->line rope line)))

(define (indent-loop chars acc)
  (cond
    [(null? chars) (reverse acc)]
    [(char-whitespace? (car chars))
     (if (char=? (car chars) #\newline)
         (reverse acc)
         (indent-loop (cdr chars) (cons (car chars) acc)))]
    [else (reverse acc)]))

(define (line-indent text)
  (list->string (indent-loop (string->list text) '())))

(define (blank-line? text)
  (let ([chars (string->list text)])
    (blank-loop chars)))

(define (blank-loop chars)
  (cond
    [(null? chars) #t]
    [(char-whitespace? (car chars)) (blank-loop (cdr chars))]
    [else #f]))

;; Returns the first non-blank line at or after `line`, within `limit` lines, or #f.
(define (first-non-blank-line rope line limit)
  (cond
    [(<= limit 0) #f]
    [(>= line (rope-line-count rope)) #f]
    [(blank-line? (rope-line-text rope line)) (first-non-blank-line rope (+ line 1) (- limit 1))]
    [else line]))

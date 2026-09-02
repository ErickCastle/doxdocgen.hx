;; Pure string helpers. Deliberately free of any `helix/*` import so that this
;; module (and its dependents) load under the plain `steel` interpreter.
(provide string-index-of
         string-replace-all
         string-split-char
         string-blank?
         string-trim-right
         string-trim
         string-normalize-spaces
         string-words
         string-join-with
         string-starts-with-at?
         template-fill)

(define (drop-n lst n)
  (if (or (= n 0) (null? lst))
      lst
      (drop-n (cdr lst) (- n 1))))

(define (list-prefix? lst prefix)
  (cond
    [(null? prefix) #t]
    [(null? lst) #f]
    [(equal? (car lst) (car prefix)) (list-prefix? (cdr lst) (cdr prefix))]
    [else #f]))

(define (index-of-loop chars sub idx)
  (cond
    [(list-prefix? chars sub) idx]
    [(null? chars) #f]
    [else (index-of-loop (cdr chars) sub (+ idx 1))]))

(define (string-index-of s sub)
  (if (equal? sub "")
      0
      (index-of-loop (string->list s) (string->list sub) 0)))

(define (string-starts-with-at? s sub)
  (equal? (string-index-of s sub) 0))

(define (replace-loop chars from to acc)
  (cond
    [(null? chars) (reverse acc)]
    [(list-prefix? chars from)
     (replace-loop (drop-n chars (length from)) from to (append (reverse to) acc))]
    [else (replace-loop (cdr chars) from to (cons (car chars) acc))]))

(define (string-replace-all s from to)
  (if (equal? from "")
      s
      (list->string (replace-loop (string->list s) (string->list from) (string->list to) '()))))

(define (split-loop chars ch cur acc)
  (cond
    [(null? chars) (reverse (cons (list->string (reverse cur)) acc))]
    [(char=? (car chars) ch)
     (split-loop (cdr chars) ch '() (cons (list->string (reverse cur)) acc))]
    [else (split-loop (cdr chars) ch (cons (car chars) cur) acc)]))

(define (string-split-char s ch)
  (split-loop (string->list s) ch '() '()))

(define (all-whitespace? chars)
  (cond
    [(null? chars) #t]
    [(char-whitespace? (car chars)) (all-whitespace? (cdr chars))]
    [else #f]))

(define (string-blank? s)
  (all-whitespace? (string->list s)))

(define (trim-right-loop chars)
  (cond
    [(null? chars) '()]
    [(char-whitespace? (car chars))
     (let ([rest (trim-right-loop (cdr chars))])
       (if (null? rest) '() (cons (car chars) rest)))]
    [else (cons (car chars) (trim-right-loop (cdr chars)))]))

(define (string-trim-right s)
  (list->string (trim-right-loop (string->list s))))

(define (trim-left-loop chars)
  (cond
    [(null? chars) '()]
    [(char-whitespace? (car chars)) (trim-left-loop (cdr chars))]
    [else chars]))

(define (string-trim s)
  (list->string (trim-right-loop (trim-left-loop (string->list s)))))

(define (non-empty-strings lst)
  (cond
    [(null? lst) '()]
    [(equal? (car lst) "") (non-empty-strings (cdr lst))]
    [else (cons (car lst) (non-empty-strings (cdr lst)))]))

(define (space-out chars)
  (cond
    [(null? chars) '()]
    [(char-whitespace? (car chars)) (cons #\space (space-out (cdr chars)))]
    [else (cons (car chars) (space-out (cdr chars)))]))

;; Split on any run of whitespace.
(define (string-words s)
  (non-empty-strings (string-split-char (list->string (space-out (string->list s))) #\space)))

(define (string-join-with lst separator)
  (cond
    [(null? lst) ""]
    [(null? (cdr lst)) (car lst)]
    [else (string-append (car lst) separator (string-join-with (cdr lst) separator))]))

(define (string-normalize-spaces s)
  (string-join-with (string-words s) " "))

;; bindings : list of (placeholder . replacement), placeholder written as "{name}"
(define (template-fill template bindings)
  (if (null? bindings)
      template
      (template-fill (string-replace-all template (car (car bindings)) (cdr (car bindings)))
                     (cdr bindings))))

;; Renders a Doxygen block from a declaration record. Pure: no `helix/*` imports,
;; so `make test` can exercise it under the plain `steel` interpreter.
(require "strings.scm")
(require "config.scm")

(provide render-block
         render-lines
         declaration
         file-declaration)

;; Entries carry a tag so the wrapper knows which line holds the cursor and
;; which lines are blank (blank ones must not keep the prefix's trailing space).
(define (entry text tag)
  (list text tag))

(define (entry-text e) (list-ref e 0))
(define (entry-tag e) (list-ref e 1))

(define (decl-ref decl key fallback)
  (if (hash-contains? decl key)
      (hash-ref decl key)
      fallback))

;;@doc
;; Build a declaration record for a function, method, class or struct.
(define (declaration kind name return-type params tparams ctor? dtor? indent)
  (hash 'kind kind
        'name name
        'return-type return-type
        'params params
        'tparams tparams
        'ctor? ctor?
        'dtor? dtor?
        'indent indent))

;;@doc
;; Build a declaration record for a file header block.
(define (file-declaration file-name)
  (hash 'kind 'file
        'name file-name
        'return-type #f
        'params '()
        'tparams '()
        'ctor? #f
        'dtor? #f
        'indent ""))

(define (env-ref env key fallback)
  (if (hash-contains? env key)
      (hash-ref env key)
      fallback))

(define (non-empty-template template)
  (if (equal? template "") #f template))

(define (brief-entries)
  (let ([template (non-empty-template (dox-ref 'brief-template))])
    (if template
        (list (entry (template-fill template (list (cons "{text}" ""))) 'brief))
        '())))

(define (named-entries template names)
  (let ([tmpl (non-empty-template template)])
    (if tmpl
        (map (lambda (name) (entry (template-fill tmpl (list (cons "{param}" name))) 'normal)) names)
        '())))

(define (return-type-string decl)
  (let ([rt (decl-ref decl 'return-type #f)])
    (cond
      [(not rt) #f]
      [(equal? rt "") #f]
      [(equal? rt "void") #f]
      [else rt])))

(define (fill-return template type-text)
  (let ([filled (template-fill template (list (cons "{type}" type-text)))])
    (if (equal? type-text "")
        (string-replace-all filled "  " " ")
        filled)))

(define (return-entries decl)
  (let ([template (non-empty-template (dox-ref 'return-template))]
        [rt (return-type-string decl)])
    (cond
      [(not template) '()]
      [(not (equal? (decl-ref decl 'kind 'function) 'function)) '()]
      [(decl-ref decl 'ctor? #f) '()]
      [(decl-ref decl 'dtor? #f) '()]
      [(not rt) '()]
      [(and (dox-ref 'bool-returns-true-false) (equal? rt "bool"))
       (list (entry (fill-return template "true") 'normal)
             (entry (fill-return template "false") 'normal))]
      [(dox-ref 'include-type-at-return)
       (list (entry (fill-return template rt) 'normal))]
      [else (list (entry (fill-return template "") 'normal))])))

(define (tag-entries template bindings)
  (let ([tmpl (non-empty-template template)])
    (if tmpl
        (list (entry (template-fill tmpl bindings) 'normal))
        '())))

(define (list-tag-entries templates bindings)
  (map (lambda (tmpl) (entry (template-fill tmpl bindings) 'normal)) templates))

(define (section-entries token decl env)
  (cond
    [(equal? token 'brief) (brief-entries)]
    [(equal? token 'empty) (list (entry "" 'blank))]
    [(equal? token 'tparam)
     (named-entries (dox-ref 'tparam-template) (decl-ref decl 'tparams '()))]
    [(equal? token 'param)
     (named-entries (dox-ref 'param-template) (decl-ref decl 'params '()))]
    [(equal? token 'return) (return-entries decl)]
    [(equal? token 'custom)
     (list-tag-entries (if (equal? (decl-ref decl 'kind 'function) 'file)
                           (dox-ref 'file-custom-tags)
                           (dox-ref 'custom-tags))
                       (env-bindings env))]
    [(equal? token 'version) (tag-entries (dox-ref 'version-tag) (env-bindings env))]
    [(equal? token 'author) (tag-entries (dox-ref 'author-tag) (env-bindings env))]
    [(equal? token 'date) (tag-entries (dox-ref 'date-template) (env-bindings env))]
    [(equal? token 'copyright) (list-tag-entries (dox-ref 'copyright-tag) (env-bindings env))]
    [(equal? token 'file)
     (tag-entries (dox-ref 'file-template)
                  (cons (cons "{name}" (decl-ref decl 'name "")) (env-bindings env)))]
    [else '()]))

(define (env-bindings env)
  (list (cons "{author}" (env-ref env 'author (dox-ref 'author-name)))
        (cons "{email}" (env-ref env 'email (dox-ref 'author-email)))
        (cons "{date}" (env-ref env 'date ""))
        (cons "{year}" (env-ref env 'year ""))
        (cons "{file}" (env-ref env 'file ""))))

(define (append-all lists)
  (if (null? lists)
      '()
      (append (car lists) (append-all (cdr lists)))))

(define (body-entries decl env)
  (let ([order (if (equal? (decl-ref decl 'kind 'function) 'file)
                   (dox-ref 'file-order)
                   (dox-ref 'order))])
    (append-all (map (lambda (token) (section-entries token decl env)) order))))

(define (prefix-entry e indent prefix)
  (if (equal? (entry-tag e) 'blank)
      (entry (string-trim-right (string-append indent prefix)) 'blank)
      (entry (string-append indent prefix (entry-text e)) (entry-tag e))))

(define (wrap-entries body indent)
  (let ([first-line (dox-ref 'first-line)]
        [last-line (dox-ref 'last-line)]
        [prefix (dox-ref 'comment-prefix)])
    (append (if (equal? first-line "") '() (list (entry (string-append indent first-line) 'normal)))
            (map (lambda (e) (prefix-entry e indent prefix)) body)
            (if (equal? last-line "") '() (list (entry (string-append indent last-line) 'normal))))))

(define (join-lines lines separator)
  (cond
    [(null? lines) ""]
    [(null? (cdr lines)) (car lines)]
    [else (string-append (car lines) separator (join-lines (cdr lines) separator))]))

(define (offset-loop entries separator acc)
  (cond
    [(null? entries) acc]
    [(equal? (entry-tag (car entries)) 'brief)
     (+ acc (string-length (entry-text (car entries))))]
    [else
     (offset-loop (cdr entries)
                  separator
                  (+ acc (string-length (entry-text (car entries))) (string-length separator)))]))

;;@doc
;; Render the block as a list of fully indented lines.
(define (render-lines decl env)
  (map entry-text (wrap-entries (body-entries decl env) (decl-ref decl 'indent ""))))

;;@doc
;; Render the block. Returns a hash with 'text (the whole block), 'lines, and
;; 'cursor-offset (a character offset into 'text, just past "@brief ").
(define (render-block decl env)
  (let* ([separator (dox-ref 'line-ending)]
         [entries (wrap-entries (body-entries decl env) (decl-ref decl 'indent ""))]
         [lines (map entry-text entries)]
         [text (join-lines lines separator)])
    (hash 'text text
          'lines lines
          'cursor-offset (offset-loop entries separator 0))))

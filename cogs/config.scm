;; Configuration mirroring cschlosser.doxdocgen's settings. Pure: no `helix/*`
;; imports, so it loads under the plain `steel` interpreter too.
(provide default-config
         current-config
         dox-ref
         dox-set!
         doxdocgen-configure
         reset-config!)

(define (default-config)
  (hash 'trigger-sequence "/**"
        'first-line "/**"
        'comment-prefix " * "
        'last-line " */"
        'brief-template "@brief {text}"
        'param-template "@param {param} "
        'tparam-template "@tparam {param} "
        'return-template "@return {type} "
        'file-template "@file {name}"
        'author-tag "@author {author} ({email})"
        'date-template "@date {date}"
        'version-tag "@version 0.1"
        'copyright-tag (list "@copyright Copyright (c) {year}")
        'custom-tags '()
        'file-custom-tags '()
        ;; doxdocgen's README lists version/author/date/copyright as valid order
        ;; tokens, but its generated function comments only carry these.
        'order (list 'brief 'empty 'tparam 'param 'return 'custom)
        'file-order (list 'file 'author 'brief 'version 'date 'empty 'copyright 'empty 'custom)
        'lines-to-get 20
        'date-format "%Y-%m-%d"
        'include-type-at-return #t
        'bool-returns-true-false #t
        'filtered-keywords '()
        'author-name "your name"
        'author-email "you@domain.com"
        ;; No per-document line-ending accessor is exposed to Steel, so this is
        ;; a setting rather than something detected from the buffer.
        'line-ending "\n"))

(define *config* (box (default-config)))

(define (current-config)
  (unbox *config*))

(define (reset-config!)
  (set-box! *config* (default-config)))

(define (dox-ref key)
  (let ([cfg (unbox *config*)])
    (if (hash-contains? cfg key)
        (hash-ref cfg key)
        (error "doxdocgen: unknown configuration key" key))))

(define (dox-set! key value)
  (set-box! *config* (hash-insert (unbox *config*) key value)))

(define (configure-loop kvs)
  (cond
    [(null? kvs) void]
    [(null? (cdr kvs)) (error "doxdocgen-configure: odd number of arguments")]
    [else
     (dox-set! (car kvs) (car (cdr kvs)))
     (configure-loop (cdr (cdr kvs)))]))

;;@doc
;; Override configuration values, e.g.
;; (doxdocgen-configure 'author-name "Ada" 'brief-template "@brief {text}")
(define (doxdocgen-configure . kvs)
  (configure-loop kvs))

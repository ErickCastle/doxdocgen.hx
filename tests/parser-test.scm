;; In-editor test suite: open tests/fixtures/sample.cpp and run `:doxygen-selftest`.
;; It cannot run headlessly because it needs a parsed C++ document.
(require "../cogs/parser.scm")
(require "helix/misc.scm")

(provide run-parser-selftest)

(define failures (box '()))

(define (fail! label expected actual)
  (set-box! failures
            (cons (string-append label
                                 " | expected " (to-string expected)
                                 " | actual " (to-string actual))
                  (unbox failures))))

(define (check! label expected actual)
  (if (equal? expected actual)
      void
      (fail! label expected actual)))

(define (field decl key)
  (if decl (hash-ref decl key) 'no-declaration))

(define (check-decl! label line key expected)
  (check! label expected (field (declaration-at-line line) key)))

;; Line numbers are 0-based and refer to tests/fixtures/sample.cpp.
(define (run-checks)
  (check-decl! "add: name" 3 'name "add")
  (check-decl! "add: params" 3 'params (list "lhs" "rhs"))
  (check-decl! "add: return" 3 'return-type "int")
  (check-decl! "add: not a ctor" 3 'ctor? #f)

  (check-decl! "reset: name" 5 'name "reset")
  (check-decl! "reset: params" 5 'params '())
  (check-decl! "reset: return" 5 'return-type "void")

  (check-decl! "is_valid: name" 7 'name "is_valid")
  (check-decl! "is_valid: params" 7 'params (list "name" "flags"))
  (check-decl! "is_valid: return" 7 'return-type "bool")

  (check-decl! "combine: tparams from the template line" 9 'tparams (list "T" "U"))
  (check-decl! "combine: name from the template line" 9 'name "combine")
  (check-decl! "combine: params" 9 'params (list "lhs" "rhs"))
  (check-decl! "combine: tparams from the declarator line" 10 'tparams (list "T" "U"))

  (check-decl! "ctor: name" 14 'name "Widget")
  (check-decl! "ctor: flagged" 14 'ctor? #t)
  (check-decl! "ctor: params" 14 'params (list "value" "name"))
  (check-decl! "ctor: no return type" 14 'return-type "")

  (check-decl! "dtor: flagged" 15 'dtor? #t)
  (check-decl! "dtor: not a ctor" 15 'ctor? #f)
  (check-decl! "dtor: params" 15 'params '())

  (check-decl! "values: name" 17 'name "values")
  (check-decl! "trailing return: name" 18 'name "scaled")
  (check-decl! "trailing return: params" 18 'params (list "factor"))
  (check-decl! "trailing return: type" 18 'return-type "std::vector<double>")

  (check-decl! "operator: params" 19 'params (list "other"))
  (check-decl! "operator: return" 19 'return-type "bool")

  (check-decl! "class: kind" 12 'kind 'class)
  (check-decl! "class: name" 12 'name "Widget"))

;;@doc
;; Run the parser checks against the focused buffer (expects sample.cpp).
(define (run-parser-selftest)
  (set-box! failures '())
  (run-checks)
  (let ([errors (unbox failures)])
    (if (null? errors)
        (set-status! "doxdocgen: all parser checks passed")
        (begin
          (map displayln errors)
          (set-error! (string-append "doxdocgen: "
                                     (to-string (length errors))
                                     " parser check(s) failed - see :log-open"))))))

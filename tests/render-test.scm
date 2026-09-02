;; Headless test suite: `steel tests/render-test.scm` (or `make test`).
(require "../cogs/config.scm")
(require "../cogs/render.scm")

(define failures (box 0))

(define (fail! label expected actual)
  (set-box! failures (+ (unbox failures) 1))
  (displayln (string-append "FAIL " label))
  (displayln (string-append "  expected: " (to-string expected)))
  (displayln (string-append "  actual:   " (to-string actual))))

(define (check! label expected actual)
  (if (equal? expected actual)
      (displayln (string-append "ok   " label))
      (fail! label expected actual)))

(define test-env (hash 'date "2026-08-29" 'year "2026" 'file "main.cpp"))

(define (block-text decl)
  (hash-ref (render-block decl test-env) 'text))

;; --- function with params and a return type ---------------------------------
(reset-config!)
(check! "function: params and return"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " * @param a \n"
                       " * @param b \n"
                       " * @return int \n"
                       " */")
        (block-text (declaration 'function "foo" "int" (list "a" "b") '() #f #f "")))

(check! "function: cursor lands after @brief"
        14
        (hash-ref (render-block (declaration 'function "foo" "int" (list "a") '() #f #f "") test-env)
                  'cursor-offset))

;; --- void suppresses @return ------------------------------------------------
(reset-config!)
(check! "function: void has no @return"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " * @param a \n"
                       " */")
        (block-text (declaration 'function "foo" "void" (list "a") '() #f #f "")))

;; --- bool splits into true/false --------------------------------------------
(reset-config!)
(check! "function: bool splits into true/false"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " * @return true \n"
                       " * @return false \n"
                       " */")
        (block-text (declaration 'function "ok" "bool" '() '() #f #f "")))

(reset-config!)
(dox-set! 'bool-returns-true-false #f)
(check! "function: bool split can be disabled"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " * @return bool \n"
                       " */")
        (block-text (declaration 'function "ok" "bool" '() '() #f #f "")))

;; --- include-type-at-return -------------------------------------------------
(reset-config!)
(dox-set! 'include-type-at-return #f)
(check! "function: return type can be omitted"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " * @return \n"
                       " */")
        (block-text (declaration 'function "foo" "int" '() '() #f #f "")))

;; --- constructors and destructors -------------------------------------------
(reset-config!)
(check! "ctor: no @return"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " * @param value \n"
                       " */")
        (block-text (declaration 'function "Widget" "" (list "value") '() #t #f "")))

(reset-config!)
(check! "dtor: no @return"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " */")
        (block-text (declaration 'function "~Widget" "" '() '() #f #t "")))

;; --- templates --------------------------------------------------------------
(reset-config!)
(check! "template: @tparam precedes @param"
        (string-append "/**\n"
                       " * @brief \n"
                       " *\n"
                       " * @tparam T \n"
                       " * @tparam U \n"
                       " * @param lhs \n"
                       " * @return T \n"
                       " */")
        (block-text (declaration 'function "add" "T" (list "lhs") (list "T" "U") #f #f "")))

;; --- indentation ------------------------------------------------------------
(reset-config!)
(check! "indent: every line is indented, blanks are right-trimmed"
        (string-append "    /**\n"
                       "     * @brief \n"
                       "     *\n"
                       "     * @return int \n"
                       "     */")
        (block-text (declaration 'function "foo" "int" '() '() #f #f "    ")))

;; --- file header ------------------------------------------------------------
(reset-config!)
(check! "file: header block"
        (string-append "/**\n"
                       " * @file main.cpp\n"
                       " * @author your name (you@domain.com)\n"
                       " * @brief \n"
                       " * @version 0.1\n"
                       " * @date 2026-08-29\n"
                       " *\n"
                       " * @copyright Copyright (c) 2026\n"
                       " *\n"
                       " */")
        (block-text (file-declaration "main.cpp")))

;; --- configurability --------------------------------------------------------
(reset-config!)
(doxdocgen-configure 'author-name "Ada" 'author-email "ada@example.com")
(check! "config: author substitution"
        (string-append "/**\n"
                       " * @file a.h\n"
                       " * @author Ada (ada@example.com)\n"
                       " * @brief \n"
                       " * @version 0.1\n"
                       " * @date 2026-08-29\n"
                       " *\n"
                       " * @copyright Copyright (c) 2026\n"
                       " *\n"
                       " */")
        (block-text (file-declaration "a.h")))

(reset-config!)
(doxdocgen-configure 'order (list 'brief 'param)
                     'first-line "/*!"
                     'comment-prefix " ** "
                     'last-line " */")
(check! "config: custom order and delimiters"
        (string-append "/*!\n"
                       " ** @brief \n"
                       " ** @param a \n"
                       " */")
        (block-text (declaration 'function "foo" "int" (list "a") '() #f #f "")))

(reset-config!)
(doxdocgen-configure 'brief-template "")
(check! "config: empty template emits nothing"
        (string-append "/**\n"
                       " *\n"
                       " * @param a \n"
                       " */")
        (block-text (declaration 'function "foo" "void" (list "a") '() #f #f "")))

(reset-config!)

(if (= (unbox failures) 0)
    (displayln "\nall render tests passed")
    (error "render tests failed" (unbox failures)))

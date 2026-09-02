;; Headless test suite: `steel tests/strings-test.scm` (or `make test`).
(require "../cogs/strings.scm")

(define failures (box 0))

(define (check! label expected actual)
  (if (equal? expected actual)
      (displayln (string-append "ok   " label))
      (begin
        (set-box! failures (+ (unbox failures) 1))
        (displayln (string-append "FAIL " label))
        (displayln (string-append "  expected: " (to-string expected)))
        (displayln (string-append "  actual:   " (to-string actual))))))

(check! "index-of: found" 6 (string-index-of "hello world" "world"))
(check! "index-of: missing" #f (string-index-of "hello" "zz"))
(check! "index-of: empty needle" 0 (string-index-of "hello" ""))

(check! "replace-all: repeated" "a-b-c" (string-replace-all "a b c" " " "-"))
(check! "replace-all: multichar" "xyC" (string-replace-all "abC" "ab" "xy"))
(check! "replace-all: absent" "abc" (string-replace-all "abc" "z" "y"))

(check! "split-char: basic" (list "a" "b" "c") (string-split-char "a,b,c" #\,))
(check! "split-char: trailing" (list "a" "") (string-split-char "a," #\,))

(check! "blank?: spaces" #t (string-blank? "   "))
(check! "blank?: text" #f (string-blank? "  x "))

(check! "trim-right" "  a" (string-trim-right "  a  "))
(check! "trim" "a" (string-trim "  a  "))

(check! "words: collapses runs" (list "int" "x") (string-words "  int \n\t x "))
(check! "normalize-spaces" "const int *" (string-normalize-spaces "const   int\n*"))
(check! "join-with" "a::b" (string-join-with (list "a" "b") "::"))

(check! "template-fill"
        "@param a "
        (template-fill "@param {param} " (list (cons "{param}" "a"))))
(check! "template-fill: multiple"
        "Ada <ada@x>"
        (template-fill "{author} <{email}>"
                       (list (cons "{author}" "Ada") (cons "{email}" "ada@x"))))

(if (= (unbox failures) 0)
    (displayln "\nall string tests passed")
    (error "string tests failed" (unbox failures)))

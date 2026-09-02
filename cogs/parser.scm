;; Extracts a declaration record from the buffer's tree-sitter parse tree.
;; Requires the embedded engine - not headless-safe.
(require-builtin helix/core/text as text.)
(require "helix/treesitter.scm")
(require "helix/editor.scm")
(require "strings.scm")
(require "config.scm")
(require "render.scm")
(require "rope-util.scm")

(provide declaration-at-line
         node-text)

(define declaration-kinds
  (list "function_definition"
        "declaration"
        "field_declaration"
        "template_declaration"
        "class_specifier"
        "struct_specifier"
        "enum_specifier"
        "type_definition"
        "alias_declaration"))

(define inner-declaration-kinds
  (list "function_definition" "declaration" "field_declaration"))

(define class-kinds (list "class_specifier" "struct_specifier"))

;; Bodies are skipped so a nested call never masquerades as the declarator.
(define body-kinds
  (list "compound_statement" "field_declaration_list" "declaration_list" "enumerator_list"))

(define parameter-kinds
  (list "parameter_declaration"
        "optional_parameter_declaration"
        "variadic_parameter_declaration"))

(define template-parameter-kinds
  (list "type_parameter_declaration"
        "optional_type_parameter_declaration"
        "variadic_type_parameter_declaration"
        "template_template_parameter_declaration"
        "parameter_declaration"
        "optional_parameter_declaration"))

(define identifier-kinds
  (list "identifier" "field_identifier" "type_identifier"))

(define name-kinds
  (list "identifier"
        "field_identifier"
        "qualified_identifier"
        "destructor_name"
        "operator_name"
        "template_function"))

;; Not part of the return type, so they are dropped from the type span.
(define specifier-words
  (list "static" "inline" "virtual" "explicit" "friend" "extern" "constexpr"
        "consteval" "constinit" "thread_local" "typedef" "template"))

(define (list-contains? lst value)
  (cond
    [(null? lst) #f]
    [(equal? (car lst) value) #t]
    [else (list-contains? (cdr lst) value)]))

(define (node-text rope node)
  (text.rope->string (text.rope->byte-slice rope (tsnode-start-byte node) (tsnode-end-byte node))))

(define (span-text rope start end)
  (if (< start end)
      (text.rope->string (text.rope->byte-slice rope start end))
      ""))

(define (find-in-list nodes kinds)
  (cond
    [(null? nodes) #f]
    [(list-contains? kinds (tsnode-kind (car nodes))) (car nodes)]
    [else (find-in-list (cdr nodes) kinds)]))

(define (find-child node kinds)
  (find-in-list (tsnode-named-children node) kinds))

(define (find-first-descendant nodes kinds)
  (if (null? nodes)
      #f
      (let ([found (find-descendant (car nodes) kinds)])
        (if found found (find-first-descendant (cdr nodes) kinds)))))

(define (find-descendant node kinds)
  (cond
    [(list-contains? kinds (tsnode-kind node)) node]
    [(list-contains? body-kinds (tsnode-kind node)) #f]
    [else (find-first-descendant (tsnode-named-children node) kinds)]))

(define (climb-to-declaration node)
  (cond
    [(not node) #f]
    [(list-contains? declaration-kinds (tsnode-kind node))
     (let ([parent (tsnode-parent node)])
       (if (and parent (equal? (tsnode-kind parent) "template_declaration"))
           parent
           node))]
    [else (climb-to-declaration (tsnode-parent node))]))

(define (filter-specifiers words)
  (cond
    [(null? words) '()]
    [(list-contains? specifier-words (car words)) (filter-specifiers (cdr words))]
    [else (cons (car words) (filter-specifiers (cdr words)))]))

(define (filter-configured words filtered)
  (cond
    [(null? words) '()]
    [(list-contains? filtered (car words)) (filter-configured (cdr words) filtered)]
    [else (cons (car words) (filter-configured (cdr words) filtered))]))

(define (clean-type-text raw)
  (string-join-with
   (filter-configured (filter-specifiers (string-words raw)) (dox-ref 'filtered-keywords))
   " "))

;; The innermost identifier of a (possibly pointer/reference/array) declarator.
(define (declarator-name rope node)
  (let ([found (find-descendant node name-kinds)])
    (if found (string-trim (node-text rope found)) #f)))

(define (parameter-name rope node)
  (if (equal? (tsnode-kind node) "variadic_parameter_declaration")
      "..."
      (let ([name (declarator-name rope node)])
        (if name name (string-normalize-spaces (node-text rope node))))))

(define (collect-parameters rope param-list)
  (if (not param-list)
      '()
      (map (lambda (n) (parameter-name rope n))
           (filter-kinds (tsnode-named-children param-list) parameter-kinds))))

(define (filter-kinds nodes kinds)
  (cond
    [(null? nodes) '()]
    [(list-contains? kinds (tsnode-kind (car nodes)))
     (cons (car nodes) (filter-kinds (cdr nodes) kinds))]
    [else (filter-kinds (cdr nodes) kinds)]))

(define (template-parameter-name rope node)
  (let ([found (find-descendant node identifier-kinds)])
    (if found (string-trim (node-text rope found)) (string-normalize-spaces (node-text rope node)))))

(define (collect-template-parameters rope decl-node)
  (let ([list-node (find-child decl-node (list "template_parameter_list"))])
    (if (not list-node)
        '()
        (map (lambda (n) (template-parameter-name rope n))
             (filter-kinds (tsnode-named-children list-node) template-parameter-kinds)))))

(define (inner-declaration decl-node)
  (if (equal? (tsnode-kind decl-node) "template_declaration")
      (let ([inner (find-child decl-node inner-declaration-kinds)])
        (if inner inner decl-node))
      decl-node))

(define (trailing-return-text rope fn-node)
  (let ([trailing (find-descendant fn-node (list "trailing_return_type"))])
    (if trailing
        (string-normalize-spaces (string-replace-all (node-text rope trailing) "->" ""))
        #f)))

;; Everything between the start of the declaration and the declarator is the
;; return type; taking the span keeps qualifiers like `const` and `*`.
(define (return-type-text rope inner fn-node)
  (let ([trailing (trailing-return-text rope fn-node)])
    (if trailing
        trailing
        (clean-type-text (span-text rope (tsnode-start-byte inner) (tsnode-start-byte fn-node))))))

(define (function-name-node fn-node)
  (find-in-list (tsnode-named-children fn-node) name-kinds))

(define (destructor? fn-node name)
  (or (and (function-name-node fn-node)
           (equal? (tsnode-kind (function-name-node fn-node)) "destructor_name"))
      (and name (string-starts-with-at? name "~"))))

(define (build-function rope decl-node fn-node indent)
  (let* ([inner (inner-declaration decl-node)]
         [name-node (function-name-node fn-node)]
         [name (if name-node (string-trim (node-text rope name-node)) "")]
         [return-type (return-type-text rope inner fn-node)]
         [dtor (destructor? fn-node name)]
         ;; Constructors are exactly the functions with no return type at all.
         [ctor (and (not dtor) (equal? return-type ""))])
    (declaration 'function
                 name
                 return-type
                 (collect-parameters rope (find-descendant fn-node (list "parameter_list")))
                 (collect-template-parameters rope decl-node)
                 ctor
                 dtor
                 indent)))

(define (build-class rope decl-node class-node indent)
  (let ([name-node (find-child class-node identifier-kinds)])
    (declaration 'class
                 (if name-node (string-trim (node-text rope name-node)) "")
                 ""
                 '()
                 (collect-template-parameters rope decl-node)
                 #f
                 #f
                 indent)))

(define (build-other indent)
  (declaration 'other "" "" '() '() #f #f indent))

(define (line-byte-span rope line)
  (let ([start (text.rope-line->byte rope line)])
    (if (< (+ line 1) (rope-line-count rope))
        (list start (text.rope-line->byte rope (+ line 1)))
        (list start (text.rope-len-bytes rope)))))

(define (build-declaration rope decl-node indent)
  (let ([class-node (find-child decl-node class-kinds)]
        [fn-node (find-descendant decl-node (list "function_declarator"))])
    (cond
      [fn-node (build-function rope decl-node fn-node indent)]
      [(list-contains? class-kinds (tsnode-kind decl-node))
       (build-class rope decl-node decl-node indent)]
      [class-node (build-class rope decl-node class-node indent)]
      [else (build-other indent)])))

;;@doc
;; Find the declaration documented by a comment placed at `line` (0-based) and
;; return a render-ready declaration record, or #f when nothing was found.
(define (declaration-at-line line)
  (let* ([rope (current-rope)]
         [target (first-non-blank-line rope line (dox-ref 'lines-to-get))])
    (if (not target)
        #f
        (let* ([span (line-byte-span rope target)]
               [indent (line-indent (rope-line-text rope target))]
               [tree (document->tree (current-doc-id))])
          (if (not tree)
              #f
              (let* ([root (tstree->root tree)]
                     [node (tsnode-named-descendant-byte-range root
                                                               (list-ref span 0)
                                                               (list-ref span 1))]
                     [decl-node (if node (climb-to-declaration node) #f)])
                (if decl-node
                    (hash-insert (build-declaration rope decl-node indent) 'line target)
                    #f)))))))

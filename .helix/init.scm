(require "helix/configuration.scm")
(require "../doxdocgen.scm")

(define-lsp "steel-language-server" (command "steel-language-server") (args '()))
(define-language "scheme" (language-servers '("steel-language-server")))

(doxdocgen-configure 'author-name "your name"
                     'author-email "you@domain.com")

(install-doxdocgen-keymap!)

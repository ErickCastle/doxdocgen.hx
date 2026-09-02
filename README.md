# doxdocgen.hx

Doxygen comment generation for [Helix](https://helix-editor.com), built on the
[Steel](https://github.com/mattwparas/helix/tree/steel-event-system) plugin fork.

A port of the [doxdocgen](https://github.com/cschlosser/doxdocgen) VS Code
extension. Type `/**` above a C or C++ declaration and press Enter; the block is
filled in from the buffer's tree-sitter parse tree, with the cursor left after
`@brief`.

```cpp
/**
 * @brief
 *
 * @tparam T
 * @param lhs
 * @return T
 */
template <typename T>
T combine(const T &lhs);
```

## Requirements

| | |
|---|---|
| Helix | the [`steel-event-system`](https://github.com/mattwparas/helix/tree/steel-event-system) fork, built with `cargo xtask steel` |
| Grammars | the `c` and `cpp` tree-sitter grammars (`hx --grammar fetch && hx --grammar build`) |

No other tooling is needed at runtime; the plugin uses only the Steel standard
library and the modules Helix already provides.

## Installation

```sh
forge pkg install --git https://github.com/ErickCastle/doxdocgen.hx.git
```

Then require it from `~/.config/helix/helix.scm` and re-export the commands you
want. **Only names you `provide` from `helix.scm` become typed commands.**

```scheme
(require (prefix-in dox. "doxdocgen.hx/doxdocgen.scm"))

(provide doxygen-comment
         doxygen-file-comment
         doxygen-newline)

(define (doxygen-comment) (dox.doxygen-comment))
(define (doxygen-file-comment) (dox.doxygen-file-comment))
(define (doxygen-newline) (dox.doxygen-newline))
```

Then configure it and install the `/**` trigger from `~/.config/helix/init.scm`:

```scheme
(require "doxdocgen.hx/doxdocgen.scm")

(doxdocgen-configure 'author-name "Ada Lovelace"
                     'author-email "ada@example.com")

(install-doxdocgen-keymap!)
```

To work from a checkout instead, `require` the absolute path to `doxdocgen.scm`.

### Optional keybindings

The `/**` trigger is a keymap, not a hook, so it is installed separately from the
typed commands. If you would rather not rebind Enter, skip
`install-doxdocgen-keymap!` and bind the command directly:

```scheme
;; init.scm
(require "helix/configuration.scm")

(add-global-keybinding
 (hash "normal" (hash "space" (hash "d" ":doxygen-comment"))))
```

## Commands

| Command | Description |
|---|---|
| `:doxygen-comment` | Document the declaration at or below the cursor |
| `:doxygen-file-comment` | Insert a file header block at the top of the buffer |
| `:doxygen-newline` | Enter handler: expands `/**`, otherwise inserts a normal indent-aware newline |

`:doxygen-newline` is what `install-doxdocgen-keymap!` binds; it is exported so it
can be bound manually or wrapped.

## Typical workflow

```
/** then Enter above a declaration   → the block, cursor after "@brief "
:doxygen-comment                     → same, for the declaration at the cursor
:doxygen-file-comment                → @file/@author/@version/@date/@copyright header
```

The trigger replaces the whole line it is typed on, so an auto-paired `*/` is
absorbed rather than left behind. When nothing parses, the statusline says so and
the buffer is left untouched.

## Configuration

`doxdocgen-configure` takes alternating keys and values. The keys mirror
doxdocgen's settings:

| Key | Default | Description |
|---|---|---|
| `trigger-sequence` | `"/**"` | What must precede the cursor for Enter to expand |
| `first-line` | `"/**"` | Opening line; `""` omits it |
| `comment-prefix` | `" * "` | Prefix for every line in between |
| `last-line` | `" */"` | Closing line; `""` omits it |
| `brief-template` | `"@brief {text}"` | |
| `param-template` | `"@param {param} "` | |
| `tparam-template` | `"@tparam {param} "` | |
| `return-template` | `"@return {type} "` | |
| `file-template` | `"@file {name}"` | |
| `author-tag` | `"@author {author} ({email})"` | |
| `date-template` | `"@date {date}"` | |
| `version-tag` | `"@version 0.1"` | |
| `copyright-tag` | `'("@copyright Copyright (c) {year}")` | One line per element |
| `custom-tags` | `'()` | Extra lines for the `custom` slot |
| `file-custom-tags` | `'()` | Extra lines for the file header's `custom` slot |
| `order` | `'(brief empty tparam param return custom)` | Section order |
| `file-order` | `'(file author brief version date empty copyright empty custom)` | Section order for file headers |
| `lines-to-get` | `20` | How far below the comment to look for a declaration |
| `date-format` | `"%Y-%m-%d"` | `strftime` format, not moment.js |
| `include-type-at-return` | `#t` | |
| `bool-returns-true-false` | `#t` | Split a `bool` return into true/false lines |
| `filtered-keywords` | `'()` | Extra words stripped from the return type |
| `author-name` | `"your name"` | Replaces `{author}` |
| `author-email` | `"you@domain.com"` | Replaces `{email}` |
| `line-ending` | `"\n"` | |

Any template set to `""` is skipped. Templates may use `{text}`, `{param}`,
`{type}`, `{name}`, `{author}`, `{email}`, `{date}`, `{year}` and `{file}`.

```scheme
(doxdocgen-configure 'order (list 'brief 'empty 'param 'return)
                     'return-template "@returns {type} ")
```

`install-doxdocgen-keymap!` optionally takes a list of extensions, defaulting to
`c h cpp hpp cc cxx hxx ipp inl`.

## What is and is not supported

Declarations are read from Helix's tree-sitter tree rather than by matching text,
so qualifiers, templates and trailing return types survive:

| | |
|---|---|
| Functions and prototypes | `@brief`, `@param`, `@return` |
| Templates | `@tparam`, from either the `template<...>` line or the declarator |
| Constructors and destructors | detected, and `@return` suppressed |
| Operators | `operator==` and friends |
| Trailing return types | `auto f() -> T` reports `T` |
| Pointers, references, `const` | preserved in the return type |
| Classes and structs | `@brief` plus `@tparam` |
| File headers | `@file`, `@author`, `@version`, `@date`, `@copyright` |

Not supported, and why:

| doxdocgen capability | Status |
|---|---|
| Doxygen command autocompletion | Not possible; the fork exposes no completion-provider API to Steel |
| Smart text (`Get the {name} object`, ctor/dtor phrasing, case splitting) | Not implemented; config keys reserved |
| `@param` description alignment | Not implemented |
| `{author}`/`{email}` from `git config` | Not implemented; set them explicitly |
| Attribute and function-pointer edge cases | Untested |

## Known limitations

- **Line endings are a setting, not something read from the buffer.** The fork
  exposes no per-document line-ending accessor to Steel, so CRLF files need
  `(doxdocgen-configure 'line-ending "\r\n")`.
- **`install-doxdocgen-keymap!` replaces the extension keymap table.** Helix keeps
  one global table keyed by file extension. If you already call
  `set-global-buffer-or-extension-keymap`, build your entry from
  `keymap-for-doxdocgen` and merge it yourself instead.
- **The default `order` omits `version`/`author`/`date`/`copyright`.**
  doxdocgen's README lists them as valid `generic.order` tokens, but its generated
  function comments never contain them, so they appear only in `file-order`. Add
  them back with `doxdocgen-configure` if you want them.
- **Constructors are identified by having no return type at all.** That is exactly
  right for C++, but anything else the grammar reports without a type is treated
  the same way.
- **No fallback parser.** If the `c`/`cpp` grammar is missing there is no tree, and
  the command reports that nothing was found.

## Development

The toolchain lives in a Dev Container pinned to a commit of the Helix fork, so
nothing is installed on the host. **Dev Containers: Reopen in Container**, then:

```sh
./tests/run.sh                  # pure Steel suites - needs only `steel`
hx tests/fixtures/sample.cpp    # then :doxygen-selftest for the parser suite
```

`.helix/helix.scm` and `.helix/init.scm` are committed, and Helix loads
`<workspace>/.helix/` when both exist, so the plugin runs from the working tree
with no install step. Reload an edited module with `:eval-buffer`.

To move to a newer fork commit, bump `HELIX_REF` in both
`.devcontainer/Dockerfile` and `.devcontainer/devcontainer.json`, then rebuild.

```
doxdocgen.scm          public commands, the only module a user requires
cogs/config.scm        settings
cogs/strings.scm       string and template helpers
cogs/render.scm        block rendering from a declaration record
cogs/rope-util.scm     buffer and rope access
cogs/parser.scm        tree-sitter declaration extraction
cogs/generate.scm      applying a rendered block to the buffer
cogs/trigger.scm       insert-mode Enter handling and the keymap
```

`config.scm`, `strings.scm` and `render.scm` have no Helix dependency and are
tested directly with the Steel interpreter. The rest need a live editor, which is
what `:doxygen-selftest` in `tests/parser-test.scm` is for: it asserts against
known line numbers in `tests/fixtures/sample.cpp`.

### Notes on the fork's API

Two constraints shaped the implementation and are worth knowing before changing
it.

`helix/core/text` has `rope-char->byte` but no inverse, so `rope-util.scm`
converts a byte offset by finding its line and counting characters from the start
of that line.

The tree-sitter bindings expose node kinds and byte ranges but neither
`child-by-field-name` nor a node-text accessor. Every field is therefore found by
walking `tsnode-named-children` and matching `tsnode-kind`, and node text is
sliced out of the rope by byte range. The return type is taken as the source span
between the declaration and its declarator, which is what preserves `const`, `*`
and `&` without field access.

## Licence

MIT

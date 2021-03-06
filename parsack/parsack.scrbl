#lang scribble/manual
@(require scribble/eval
          (for-label "parsack.rkt"
                     racket/contract/base
                     (rename-in racket/base [string mk-string])))

@title{Parsec implementation in Racket}

@(define the-eval (make-base-eval))
@(the-eval '(require "parsack.rkt"))

@defmodule[parsack #:use-sources ("parsack.rkt")]

@author[@author+email["Stephen Chang" "stchang@racket-lang.org"]]

Parsec implementation in Racket. See @cite["parsec"].

@;; ---------------------------------------------------------------------------
@section{Basic parsing functions}

@defproc[(parse [p parser?] [input string?]) (or/c Consumed? Empty?)]{
  Parses input string @racket[input] with parser @racket[p] and returns a complete @racket[Consumed] or @racket[Emtpy] struct describing the parse result, state, and message.}

@defproc[(parse-result [p parser?] [input string?]) any/c]{
  Parses input string @racket[input] with parser @racket[p] and returns only the the parse result.}

@;; ---------------------------------------------------------------------------
@section{Basic parsing combinators/forms}

@defform/subs[(parser-compose bind-or-skip ...)
              ([bind-or-skip (x <- parser) parser]
               [parser parser?]
               [x identifier?])]{
  Composes parsers. Syntactic wrapper for @racket[>>=] operator.}

@defform/subs[(parser-seq skippable ... maybe-combine)
              ([skippable (~ parser) parser]
               [parser parser?]
               [maybe-combine (code:line) (code:line #:combine-with combine)]
               [combine (-> any/c any/c)]
               )]{
  Combine parsers in "arrow" style instead of monadically. Applies all the given parsers, combines the results with the given @racket[combine] function, and then @racket[return]s it. The result of any parsers wrapped with @racket[~] is not given to @racket[combine].

  The default @racket[combine] function is @racket[list] so @racket[(parser-seq p q)] is syntactically equivalent to @racket[(parser-compose (x <- p) (y <- q) (return (list x y)))].
  
  Use @racket[parser-seq] instead of @racket[parser-compose] when you don't need the result of any parser other than to return it. Use @racket[parser-compose] when you need the result of one parse to build subsequent parsers, for example when parsing matching html open-close tags, or if you need to do additional processing on the parse result before returning.}

@defform/subs[(parser-cons p q)
              ([p parser?] [q parser?])]{
  Syntactically equivalent to @racket[(parser-seq p q #:combine-with cons)]}

@defform/subs[(parser-one p ...)
              ([p (~> parser) parser]
               [parser parser?])]{
  Combines parsers but only return the result of the parser wrapped with @racket[~>]. Only one parser may be wrapped with @racket[~>].

  For example, @racket[(parser-one p1 (~> p2) p3)] is syntactically equivalent to @racket[(parser-seq (~ p1) p2 (~ p3) #:combine-with (λ (x) x))], which is equivalent to @racket[(parser-compose p1 (x <- p2) p3 (return x))].}

@defproc[(>>= [p parser?] [f (-> any/c parser?)]) parser?]{
  Monadic bind operator. Creates a parser that first parses with @racket[p], passes the result to @racket[f], then parses with the result of applying @racket[f]. If @racket[p] succeeds and consumes input, the application of @racket[f] is delayed. This avoids space leaks (see @cite["parsec"]).}

@defproc[(>> [p parser?] [q parser?]) parser?]{
  Creates a parser that first parses with @racket[p], ignores the result, then parses with @racket[q]. If @racket[p] consumes input, then parsing with @racket[q] is delayed. Equivalent to @racket[(>>= p (λ (x) q))] where @racket[x] is not bound in @racket[q].}

@defproc[(return [x any/c]) parser?]{
  Creates a parser that consumes no input and returns @racket[x].}

@defproc[(<or> [p parser?] ...) parser?]{
  Creates a parser that tries the given parses in order, returning with the first successful result.}
@defproc[(choice [ps (listof parser?)]) parser?]{
  Same as @racket[(apply <or> ps)].}

@;; ---------------------------------------------------------------------------
@section{Other combinators}

@defproc[(many [p parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] zero or more times.}
@defproc[(many1 [p parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] one or more times.}
@defproc[(skipMany [p parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] zero or more times, but does not return the result.}
@defproc[(skipMany1 [p parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] one or more times, but does not return the result.}
@defproc[(sepBy [p parser?][sep parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] zero or more times, where each parse of @racket[p] is separated with a parse of @racket[sep]. Only the results of @racket[p] are returned.}
@defproc[(sepBy1 [p parser?][sep parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] one or more times, where each parse of @racket[p] is separated with a parse of @racket[sep]. Only the results of @racket[p] are returned.}
@defproc[(endBy [p parser?][end parser?]) parser?]{
  Like @racket[sepBy] except for an extra @racket[end] at the end.}
@defproc[(manyTill [p parser?][end parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] zero or more times, where parser @racket[end] is tried after each @racket[p] and the parsing ends when @racket[end] succeeds.}
@defproc[(many1Till [p parser?][end parser?]) parser?]{
  Creates a parser that repeatedly parses with @racket[p] one or more times, where parser @racket[end] is tried after each @racket[p] and the parsing ends when @racket[end] succeeds.}
@defproc[(between [open parser?][close parser?][p parser?]) parser?]{
  Creates a parser that parses with @racket[p] only if it's surround by @racket[open] and @racket[close]. Only the result of @racket[p] is returned.}
@defproc[(lookAhead [p parser?]) parser?]{
  Creates a parser that parses with @racket[p] and returns its result, but consumes no input.}
@defproc[(<!> [p parser?] [q parser? $anyChar]) parser?]{
  Similar to @racket[noneOf] but more general. Creates a parser that errors if @racket[p] successfully parses input, otherwise parses with @racket[q].
  @racket[q] defaults to @racket[$anyChar] if unspecified.}
@defproc[(notFollowedBy [p parser?]) parser?]{
  Creates a parser that succeeds and return nothing if @racket[p] fails, and fails if @racket[p] succeeds. Does not consume input.}

@;; ---------------------------------------------------------------------------
@section{Character parsing}

@defproc[(satisfy [p? (-> any/c boolean?)]) parser?]{
  Creates a parser that consumes and returns one character if it satisfies predicate @racket[p?].}
@defproc[(char [c char?]) parser?]{
  Creates a parser that parses char @racket[c], case-sensitive.}
@defproc[(charAnyCase [c char?]) parser?]{
  Creates a parser that parses char @racket[c], case-insensitive.}
@defproc[(noneOf [str string?]) parser?]{
  Creates a parser that consumes and returns one character if the character does not appear in @racket[str].}
@defproc[(oneOf [str string?]) parser?]{
  Creates a parser that consumes and returns one character if the character appears in @racket[str].}
@defproc[(oneOfStrings [str string?] ...) parser?]{
  Creates a parser that consumes and returns any of the @racket[str]s, case-sensitive. Note that the parse result is @racket[(listof char?)] not @racket[string?].}
@defproc[(oneOfStringsAnyCase [str string?] ...) parser?]{
  Creates a parser that consumes and returns any of the @racket[str]s, case-insensitive. Note that the parse result is @racket[(listof char?)] not @racket[string?].}
@defproc[(string [str string?]) parser?]{
  Creates a parser that parses but does not return @racket[str].}

@section{Constant parsers}
This library uses the $ prefix for identifiers that represent parsers (as opposed to combinators).
@defthing[$letter parser?]{Parses an alphabetic char.}
@defthing[$digit parser?]{Parses an numeric char.}
@defthing[$alphaNum parser?]{Parses a letter or digit.}
@defthing[$hexDigit parser?]{Parses a hex char.}
@defthing[$space parser?]{Parses a space.}
@defthing[$spaces parser?]{Parses zero or more spaces.}
@defthing[$anyChar parser?]{Parses any char.}
@defthing[$newline parser?]{Parses newline char. This is the singular @racket[#\n] character. See also @racket[$eol].}
@defthing[$tab parser?]{Parses tab char.}
@defthing[$eol parser?]{Parses end of line. @racket[$eol] succeeds on @racket["\n"], @racket["\r"], @racket["\r\n"], or @racket["\n\r"]. 
                        See also @racket[$newline].}
@defthing[$eof parser?]{Parses end of file.}
@defthing[$identifier parser?]{Parsers string containing only numbers, letters, or underscore.}

@;; ---------------------------------------------------------------------------
@section{Error handling combinators}

@defproc[(try [p parser?]) parser?]{
  Lookahead function. Creates a parser that tries to parse with @racket[p] but does not consume input if @racket[p] fails.}

@defproc[(<?> [p parser?] [expected string?]) parser?]{
  Creates a parser that tries to parser with @racket[p] and returns error msg @racket[expected] if it fails.}

@defthing[$err parser?]{Parser that always returns error.}

@defproc[(unexpected [expected any/c]) parser?]{ 
  Like @racket[$err] but allows custom expected msg.}
          
@;; ---------------------------------------------------------------------------
@section{Structs for Parsing}

A @deftech{parser} is a function that consumes a @racket[State] and returns either an error, or a @racket[Consumed], or an @racket[Empty].

@defstruct*[State ([str string?] [pos Pos?])]{
  Input to a parser. Consists of an input string and a position.}

@defstruct*[Consumed ([reply (or/c Ok? Error?)])]{
  This is the result of parsing if some input is consumed.}

@defstruct*[Empty ([reply (or/c Ok? Error?)])]{
  This is the result of parsing if no input is consumed.}

@defstruct*[Ok ([parsed any/c][rest State?][msg Msg?])]{
  Contains the result of parsing, remaining input, and any error messages.}

@defstruct*[Error ([msg Msg?])]{
  Indicates parse error.}
                                
@defstruct*[Msg ([pos Pos?][unexpected (-> string?)][expected (listof (-> string?))])]{
  Indicates parse error. Error message generation is delayed until an exception it thrown.}

@defstruct*[Pos ([line exact-nonnegative-integer?]
                 [col exact-nonnegative-integer?]
                 [ofs exact-nonnegative-integer?])]{
  Position of parser, with line and column information if it's available. 
  The reported numbers are 1-based.}

@(bibliography
  (bib-entry #:key "parsec"
             #:author "Daan Leijen and Erik Meijer"
             #:title "Parsec: A practical parser library"
             #:location "Electronic Notes in Theoretical Computer Science"
             #:date "2001"))

// Pure. The arithmetic `:calc` evaluates.
//
// Deliberately tiny: `+ - * /`, parentheses, numbers and `#key` references, with the
// precedence everyone expects. It is not a scripting language and must not become
// one — an expression in a document is evaluated on every keystroke of every control
// it mentions, and the whole point of writing the parser here rather than reaching
// for `eval` is that a document cannot execute anything.
//
// A key that holds nothing, or holds something that is not a number, counts as zero.
// That is the behaviour a half-filled form needs: a total that reads "NaN" until the
// last field is typed is worse than one that grows as you go.

type token =
  | Number(float)
  | Reference(string)
  | Plus
  | Minus
  | Times
  | Divide
  | Open
  | Close

let isDigit = character => character >= "0" && character <= "9"

let isNameStart = character =>
  (character >= "a" && character <= "z") || (character >= "A" && character <= "Z") || character == "_"

let isNameChar = character => isNameStart(character) || isDigit(character) || character == "-"

let tokenize = source => {
  let characters = source->String.split("")
  let rec walk = (index, tokens) =>
    switch characters->Array.at(index) {
    | None => Some(tokens)
    | Some(character) =>
      if character == " " || character == "\t" || character == "\n" {
        walk(index + 1, tokens)
      } else if character == "+" {
        walk(index + 1, tokens->Array.concat([Plus]))
      } else if character == "-" {
        walk(index + 1, tokens->Array.concat([Minus]))
      } else if character == "*" {
        walk(index + 1, tokens->Array.concat([Times]))
      } else if character == "/" {
        walk(index + 1, tokens->Array.concat([Divide]))
      } else if character == "(" {
        walk(index + 1, tokens->Array.concat([Open]))
      } else if character == ")" {
        walk(index + 1, tokens->Array.concat([Close]))
      } else if character == "#" {
        let rec name = (at, built) =>
          switch characters->Array.at(at) {
          | Some(next) if isNameChar(next) => name(at + 1, built ++ next)
          | _ => (at, built)
          }
        let (next, key) = name(index + 1, "")
        key == "" ? None : walk(next, tokens->Array.concat([Reference(key)]))
      } else if isDigit(character) || character == "." {
        let rec digits = (at, built) =>
          switch characters->Array.at(at) {
          | Some(next) if isDigit(next) || next == "." => digits(at + 1, built ++ next)
          | _ => (at, built)
          }
        let (next, literal) = digits(index, "")
        // Numeric.parse, not Float.fromString: parseFloat reads a prefix, so a
        // typo like 1.2.3 would quietly evaluate as 1.2 instead of failing.
        switch Numeric.parse(literal) {
        | Some(value) => walk(next, tokens->Array.concat([Number(value)]))
        | None => None
        }
      } else {
        None
      }
    }
  walk(0, [])
}

// Recursive descent, two levels: sums of products. Each step returns the value and
// the position after it, or None when the expression does not parse — an expression
// with a typo shows as an error rather than quietly evaluating half of itself.
let evaluate = (source, lookup) => {
  let number = key =>
    lookup(key)
    ->Option.flatMap(Numeric.parse)
    ->Option.getOr(0.0)

  switch tokenize(source) {
  | None => None
  | Some(tokens) =>
    let rec sum = index =>
      switch product(index) {
      | None => None
      | Some((left, next)) => continueSum(left, next)
      }
    and continueSum = (left, index) =>
      switch tokens->Array.at(index) {
      | Some(Plus) =>
        switch product(index + 1) {
        | Some((right, next)) => continueSum(left +. right, next)
        | None => None
        }
      | Some(Minus) =>
        switch product(index + 1) {
        | Some((right, next)) => continueSum(left -. right, next)
        | None => None
        }
      | _ => Some((left, index))
      }
    and product = index =>
      switch unary(index) {
      | None => None
      | Some((left, next)) => continueProduct(left, next)
      }
    and continueProduct = (left, index) =>
      switch tokens->Array.at(index) {
      | Some(Times) =>
        switch unary(index + 1) {
        | Some((right, next)) => continueProduct(left *. right, next)
        | None => None
        }
      | Some(Divide) =>
        switch unary(index + 1) {
        // Division by zero is not an error here: a rate over an empty count is a
        // question with no answer, and Infinity would be printed as one.
        | Some((right, next)) => right == 0.0 ? None : continueProduct(left /. right, next)
        | None => None
        }
      | _ => Some((left, index))
      }
    and unary = index =>
      switch tokens->Array.at(index) {
      | Some(Minus) => unary(index + 1)->Option.map(((value, next)) => (-.value, next))
      | _ => primary(index)
      }
    and primary = index =>
      switch tokens->Array.at(index) {
      | Some(Number(value)) => Some((value, index + 1))
      | Some(Reference(key)) => Some((number(key), index + 1))
      | Some(Open) =>
        switch sum(index + 1) {
        | Some((value, next)) =>
          switch tokens->Array.at(next) {
          | Some(Close) => Some((value, next + 1))
          | _ => None
          }
        | None => None
        }
      | _ => None
      }

    switch sum(0) {
    // Trailing tokens mean the expression did not parse as a whole.
    | Some((value, next)) if next == Array.length(tokens) => Some(value)
    | _ => None
    }
  }
}

/** Every `#key` an expression mentions, so a view can subscribe to exactly those. */
let references = source =>
  switch tokenize(source) {
  | None => []
  | Some(tokens) =>
    tokens->Array.filterMap(token =>
      switch token {
      | Reference(key) => Some(key)
      | _ => None
      }
    )
  }

open BunTest

describe("RecoveryCode", () => {
  let bytes = Array.fromInitializer(~length=20, i => mod(i * 37 + 5, 256))

  test("formats twenty bytes as eight groups of four", () => {
    switch RecoveryCode.format(bytes) {
    | None => expect(true)->toBe(false)
    | Some(code) => {
        expect(code->String.length)->toBe(39)
        expect(code->String.split("-")->Array.length)->toBe(8)
        expect(code->String.split("-")->Array.every(g => g->String.length == 4))->toBe(true)
      }
    }
  })

  test("round-trips through parse", () => {
    let code = RecoveryCode.format(bytes)->Option.getOr("")
    expect(RecoveryCode.parse(code))->toEqual(Some(bytes))
  })

  // A code is read from paper: case, separators and the characters the alphabet
  // deliberately excludes are corrected, not punished.
  test("forgives case, spacing and lookalikes", () => {
    let code = RecoveryCode.format(bytes)->Option.getOr("")
    let sloppy =
      code
      ->String.toLowerCase
      ->String.replaceAll("-", " ")
      ->String.replaceAll("0", "O")
      ->String.replaceAll("1", "l")
    expect(RecoveryCode.parse(sloppy))->toEqual(Some(bytes))
  })

  test("refuses what is not a code", () => {
    expect(RecoveryCode.parse(""))->toEqual(None)
    expect(RecoveryCode.parse("ABCD-EFGH"))->toEqual(None)
    expect(RecoveryCode.format([1, 2, 3]))->toEqual(None)
    expect(RecoveryCode.format(Array.fromInitializer(~length=20, _ => 999)))->toEqual(None)
  })

  test("all-zero and all-max bytes both survive", () => {
    let zeros = Array.fromInitializer(~length=20, _ => 0)
    let maxed = Array.fromInitializer(~length=20, _ => 255)
    expect(RecoveryCode.format(zeros)->Option.flatMap(RecoveryCode.parse))->toEqual(Some(zeros))
    expect(RecoveryCode.format(maxed)->Option.flatMap(RecoveryCode.parse))->toEqual(Some(maxed))
  })
})

/** Whether this browser has a share sheet of its own. */
let available: unit => bool

/** Opens the platform's share sheet. False means dismissed or unavailable, which is
    an ordinary answer rather than an error. */
let share: (~title: string, ~text: string, ~url: string) => promise<bool>

/** A mail draft with the subject and body already in it. */
let mailto: (~subject: string, ~body: string) => string

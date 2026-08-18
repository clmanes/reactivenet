/** The current time as an ISO 8601 string. This is what gets stored: it sorts as
    text and means the same thing in every time zone. */
let timestamp: unit => string

/** The same value as a reader of `locale` expects to see it — a whole day without a
    time, a moment with one. A value that is not a date is returned unchanged, so
    this is safe to run over every field of a row. */
let localize: (string, ~locale: string) => string

/** The month, named in the reader's language: "August 2026". */
let monthLabel: (int, int, string) => string

/** The seven weekday headings, short, in the reader's language and in the order the
    grid draws them. */
let weekdayNames: (string, bool) => array<string>

// The one place a timestamp is read, and the one place one is written for a reader.
// Kept out of core so everything there stays deterministic, and out of components so
// a backup's time is not a render concern.
//
// What is *stored* stays ISO 8601 and never changes: it sorts as text, it survives a
// backup taken in one time zone and restored in another, and it is what
// `DateValue.classify` recognises. The locale only ever reaches the reader's eyes.

let timestamp: unit => string = %raw(`function () { return new Date().toISOString(); }`)

// A day is formatted from its written fields rather than from a parsed instant:
// `new Date("2026-08-10")` is midnight UTC, which in a western time zone is still
// the ninth, so a date the author typed would be shown as the day before.
let format: (string, string) => string = %raw(`
function (value, locale) {
  try {
    const day = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value.trim());
    if (day) {
      return new Intl.DateTimeFormat(locale, { dateStyle: "medium" })
        .format(new Date(Number(day[1]), Number(day[2]) - 1, Number(day[3])));
    }
    const moment = new Date(value);
    if (Number.isNaN(moment.getTime())) return value;
    return new Intl.DateTimeFormat(locale, { dateStyle: "medium", timeStyle: "short" })
      .format(moment);
  } catch (error) {
    // A locale the runtime has no data for is not a reason to lose the value.
    return value;
  }
}
`)

let localize = (value, ~locale) =>
  DateValue.isDate(value) ? format(value, locale) : value

// The month a calendar is showing, and the seven headings above its columns. Built
// from constructed dates rather than from anything stored: the numbers come from
// `MonthGrid`, which does the arithmetic, and this only puts them into the reader's
// language. The dates handed to Intl are local noon, which no time zone can push
// into the day before or after.
let monthLabel: (int, int, string) => string = %raw(`
function (year, month, locale) {
  try {
    return new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" })
      .format(new Date(year, month - 1, 1, 12));
  } catch (error) {
    return year + "-" + String(month).padStart(2, "0");
  }
}
`)

let weekdayNames: (string, bool) => array<string> = %raw(`
function (locale, startsMonday) {
  try {
    const format = new Intl.DateTimeFormat(locale, { weekday: "short" });
    // 2026-02-01 was a Sunday, so the seven days from it are one of each.
    const days = [];
    for (let index = 0; index < 7; index += 1) {
      days.push(format.format(new Date(2026, 1, 1 + index, 12)));
    }
    return startsMonday ? days.slice(1).concat(days.slice(0, 1)) : days;
  } catch (error) {
    return ["", "", "", "", "", "", ""];
  }
}
`)

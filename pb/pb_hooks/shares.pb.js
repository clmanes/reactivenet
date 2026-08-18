/// <reference path="../pb_data/types.d.ts" />
//
// The lifetime rule, in the one place a client cannot reach around: a share lives
// 120 days from its last opening. Every successful fetch renews it, so a link people
// keep using never dies and one nobody opens expires on its own.

// A fresh deposit starts its clock at creation, so the purge filter below is one
// comparison for every record — no "never opened" special case.
onRecordCreateRequest((e) => {
  e.record.set("lastUsed", new DateTime());
  return e.next();
}, "shares");

// The touch. Server-side on the view request, so opening a link is what counts as
// use — a client can neither skip it nor forge the clock.
onRecordViewRequest((e) => {
  e.record.set("lastUsed", new DateTime());
  e.app.save(e.record);
  return e.next();
}, "shares");

// Nightly, delete what nobody has opened in 120 days. Batched, because a cron that
// loads every stale record at once is a cron that dies on the day it matters.
cronAdd("purgeStaleShares", "0 3 * * *", () => {
  const cutoff = new Date(Date.now() - 120 * 24 * 60 * 60 * 1000)
    .toISOString()
    .replace("T", " ");
  const stale = $app.findRecordsByFilter(
    "shares",
    `lastUsed < "${cutoff}"`,
    "lastUsed",
    500,
    0,
  );
  for (const record of stale) {
    $app.delete(record);
  }
  if (stale.length > 0) {
    console.log(`purged ${stale.length} stale shares`);
  }
});

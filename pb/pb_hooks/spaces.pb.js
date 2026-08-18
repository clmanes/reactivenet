/// <reference path="../pb_data/types.d.ts" />
//
// The parts of the space rules a PocketBase filter cannot express soundly.
//
// The pitfall these hooks exist for: a rule like
//   members_via_space.user ?= @request.auth.id && members_via_space.role != "reader"
// is satisfied when *any* member row matches each condition — a reader passes it as
// long as somebody else is an editor. Binding "this user's row has this role" needs
// a real query, so the two decisions that depend on it live here:
//
//   - who may append a change (a member whose own role is editor or owner)
//   - who may join (the space's owner bootstrapping themselves, or the bearer of a
//     live invite — which is deleted in the same request, so it works once)

// Joining: the owner's own bootstrap row, or a valid invite presented in the body.
onRecordCreateRequest((e) => {
  const spaceId = e.record.get("space");
  const userId = e.record.get("user");
  const role = e.record.get("role");
  const space = e.app.findRecordById("spaces", spaceId);

  const already = e.app.findRecordsByFilter(
    "members",
    "space = {:space} && user = {:user}",
    "",
    1,
    0,
    { space: spaceId, user: userId },
  );
  if (already.length > 0) {
    throw new BadRequestError("Already a member.");
  }

  if (space.get("owner") === userId) {
    if (role !== "owner") {
      throw new BadRequestError("The owner joins as owner.");
    }
    e.next();
    return;
  }

  const info = e.requestInfo();
  const inviteId = info.body && typeof info.body.invite === "string" ? info.body.invite : "";
  if (inviteId === "") {
    throw new BadRequestError("Joining needs an invitation.");
  }

  let invite;
  try {
    invite = e.app.findRecordById("invites", inviteId);
  } catch {
    throw new BadRequestError("The invitation is no longer valid.");
  }
  if (invite.get("space") !== spaceId || invite.get("role") !== role) {
    throw new BadRequestError("The invitation does not say that.");
  }

  e.next();

  // Burned only after the membership actually exists — a failed join must not
  // consume the invitation.
  e.app.delete(invite);
}, "members");

// Appending a change: the author's own membership must carry a writing role. This
// is the server half of "reader" — the crypto half (they hold the key, they can
// read) needs no enforcement, and the fine-grained half beyond this is the
// client's, and documented as such.
onRecordCreateRequest((e) => {
  const spaceId = e.record.get("space");
  const userId = e.record.get("author");

  const rows = e.app.findRecordsByFilter(
    "members",
    "space = {:space} && user = {:user}",
    "",
    1,
    0,
    { space: spaceId, user: userId },
  );
  if (rows.length === 0) {
    throw new ForbiddenError("Not a member of this space.");
  }
  const role = rows[0].get("role");
  if (role !== "owner" && role !== "editor") {
    throw new ForbiddenError("Reading role: this space is read-only for you.");
  }

  const space = e.app.findRecordById("spaces", spaceId);
  const epoch = e.record.get("epoch");
  if (epoch < 1 || epoch > space.get("epoch")) {
    throw new BadRequestError("Unknown epoch.");
  }

  e.next();
}, "changes");

// Compaction: when the owner writes a snapshot with its cursor, the changes it
// folded in are deleted — server-side, because changes have no delete rule.
onRecordUpdateRequest((e) => {
  e.next();

  const until = e.record.get("snapshotUntil");
  const snapshot = e.record.get("snapshot");
  if (!until || !snapshot) return;

  while (true) {
    const batch = e.app.findRecordsByFilter(
      "changes",
      "space = {:space} && created <= {:until}",
      "",
      500,
      0,
      { space: e.record.id, until: until },
    );
    if (batch.length === 0) break;
    for (const record of batch) {
      e.app.delete(record);
    }
    if (batch.length < 500) break;
  }
}, "spaces");

// Invitations do not age well: one that nobody accepted within two weeks is not
// pending, it is forgotten — and a forgotten capability should stop existing.
cronAdd("purgeStaleInvites", "0 4 * * *", () => {
  const cutoff = new Date(Date.now() - 14 * 24 * 60 * 60 * 1000)
    .toISOString()
    .replace("T", " ");
  const stale = $app.findRecordsByFilter(
    "invites",
    "created < {:cutoff}",
    "",
    500,
    0,
    { cutoff: cutoff },
  );
  for (const record of stale) {
    $app.delete(record);
  }
});

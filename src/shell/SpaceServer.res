// Every call a shared space makes against PocketBase. Plain fetch on /pb, like the
// other two server modules: with auth and realtime in the picture an SDK would
// start earning its keep, but it would also be the first dependency whose network
// behaviour this app does not fully own — and the calls are still just fetches
// with an Authorization header.
//
// Failure conventions as everywhere: None (or false, or an empty list) rather than
// exceptions. The one distinction that matters to the sync engine — "the server
// said no" versus "there is no server here" — is carried by listChangesSince
// returning an option: None is unreachable, Some([]) is quiet.

type space = {
  id: string,
  owner: string,
  epoch: int,
  snapshot: string,
  snapshotUntil: string,
}

type member = {
  id: string,
  user: string,
  role: string,
  label: string,
  pub: string,
  keys: string,
}

type invite = {
  id: string,
  space: string,
  role: string,
  sealedKey: string,
  epoch: int,
}

type change = {
  id: string,
  epoch: int,
  payload: string,
  created: string,
}

let createSpace: (~token: string, ~owner: string) => promise<option<string>> = %raw(`
async function (token, owner) {
  try {
    const response = await fetch("/pb/api/collections/spaces/records", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: token },
      body: JSON.stringify({ owner, epoch: 1 }),
    });
    if (!response.ok) return undefined;
    const record = await response.json();
    return typeof record.id === "string" && record.id !== "" ? record.id : undefined;
  } catch (error) {
    return undefined;
  }
}
`)

let getSpace: (~token: string, ~id: string) => promise<option<space>> = %raw(`
async function (token, id) {
  try {
    const response = await fetch(
      "/pb/api/collections/spaces/records/" + encodeURIComponent(id),
      { headers: { Authorization: token } }
    );
    if (!response.ok) return undefined;
    const record = await response.json();
    return {
      id: String(record.id || ""),
      owner: String(record.owner || ""),
      epoch: Number(record.epoch || 1),
      snapshot: String(record.snapshot || ""),
      snapshotUntil: String(record.snapshotUntil || ""),
    };
  } catch (error) {
    return undefined;
  }
}
`)

let updateSpace: (
  ~token: string,
  ~id: string,
  ~body: string,
) => promise<bool> = %raw(`
async function (token, id, body) {
  try {
    const response = await fetch(
      "/pb/api/collections/spaces/records/" + encodeURIComponent(id),
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Authorization: token },
        body,
      }
    );
    return response.ok;
  } catch (error) {
    return false;
  }
}
`)

/** Joining (or the owner's bootstrap, with an empty invite). `pub` and `keys` are
    JSON strings; the invite id rides in the body for the server hook to burn. */
let createMember: (
  ~token: string,
  ~space: string,
  ~user: string,
  ~role: string,
  ~label: string,
  ~pub: string,
  ~keys: string,
  ~invite: string,
) => promise<bool> = %raw(`
async function (token, space, user, role, label, pub, keys, invite) {
  try {
    const body = { space, user, role, label, pub: JSON.parse(pub), keys: JSON.parse(keys) };
    if (invite !== "") body.invite = invite;
    const response = await fetch("/pb/api/collections/members/records", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: token },
      body: JSON.stringify(body),
    });
    return response.ok;
  } catch (error) {
    return false;
  }
}
`)

let listMembers: (~token: string, ~space: string) => promise<array<member>> = %raw(`
async function (token, space) {
  try {
    const filter = encodeURIComponent("space = '" + space + "'");
    const response = await fetch(
      "/pb/api/collections/members/records?perPage=200&filter=" + filter,
      { headers: { Authorization: token } }
    );
    if (!response.ok) return [];
    const answer = await response.json();
    return (answer.items || []).map((record) => ({
      id: String(record.id || ""),
      user: String(record.user || ""),
      role: String(record.role || ""),
      label: String(record.label || ""),
      pub: JSON.stringify(record.pub || null),
      keys: JSON.stringify(record.keys || null),
    }));
  } catch (error) {
    return [];
  }
}
`)

let updateMemberKeys: (~token: string, ~id: string, ~keys: string) => promise<bool> = %raw(`
async function (token, id, keys) {
  try {
    const response = await fetch(
      "/pb/api/collections/members/records/" + encodeURIComponent(id),
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json", Authorization: token },
        body: JSON.stringify({ keys: JSON.parse(keys) }),
      }
    );
    return response.ok;
  } catch (error) {
    return false;
  }
}
`)

let deleteMember: (~token: string, ~id: string) => promise<bool> = %raw(`
async function (token, id) {
  try {
    const response = await fetch(
      "/pb/api/collections/members/records/" + encodeURIComponent(id),
      { method: "DELETE", headers: { Authorization: token } }
    );
    return response.ok;
  } catch (error) {
    return false;
  }
}
`)

let createInvite: (
  ~token: string,
  ~space: string,
  ~role: string,
  ~sealedKey: string,
  ~epoch: int,
) => promise<option<string>> = %raw(`
async function (token, space, role, sealedKey, epoch) {
  try {
    const response = await fetch("/pb/api/collections/invites/records", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: token },
      body: JSON.stringify({ space, role, sealedKey, epoch }),
    });
    if (!response.ok) return undefined;
    const record = await response.json();
    return typeof record.id === "string" && record.id !== "" ? record.id : undefined;
  } catch (error) {
    return undefined;
  }
}
`)

let getInvite: (~token: string, ~id: string) => promise<option<invite>> = %raw(`
async function (token, id) {
  try {
    const response = await fetch(
      "/pb/api/collections/invites/records/" + encodeURIComponent(id),
      { headers: { Authorization: token } }
    );
    if (!response.ok) return undefined;
    const record = await response.json();
    return {
      id: String(record.id || ""),
      space: String(record.space || ""),
      role: String(record.role || ""),
      sealedKey: String(record.sealedKey || ""),
      epoch: Number(record.epoch || 1),
    };
  } catch (error) {
    return undefined;
  }
}
`)

let createChange: (
  ~token: string,
  ~space: string,
  ~author: string,
  ~epoch: int,
  ~payload: string,
) => promise<bool> = %raw(`
async function (token, space, author, epoch, payload) {
  try {
    const response = await fetch("/pb/api/collections/changes/records", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: token },
      body: JSON.stringify({ space, author, epoch, payload }),
    });
    return response.ok;
  } catch (error) {
    return false;
  }
}
`)

/** Everything after a cursor, oldest first. None is "no server here" — the caller
    pauses rather than concluding the log is quiet. The pull walks pages to the
    end: applying a change twice is free (Automerge deduplicates by hash), missing
    one is not, so the cursor advances only over what actually arrived. */
let listChangesSince: (
  ~token: string,
  ~space: string,
  ~since: string,
) => promise<option<array<change>>> = %raw(`
async function (token, space, since) {
  try {
    const collected = [];
    let page = 1;
    while (true) {
      const filter =
        since === ""
          ? "space = '" + space + "'"
          : "space = '" + space + "' && created > '" + since + "'";
      const response = await fetch(
        "/pb/api/collections/changes/records?sort=created,id&perPage=200&page=" +
          page + "&filter=" + encodeURIComponent(filter),
        { headers: { Authorization: token } }
      );
      if (!response.ok) return undefined;
      const answer = await response.json();
      const items = (answer.items || []).map((record) => ({
        id: String(record.id || ""),
        epoch: Number(record.epoch || 1),
        payload: String(record.payload || ""),
        created: String(record.created || ""),
      }));
      collected.push(...items);
      if (page >= (answer.totalPages || 1)) return collected;
      page += 1;
    }
  } catch (error) {
    return undefined;
  }
}
`)

// The button half of ::geo: a click asks the device for its position and
// writes it into the field beside it as "lat, lon" — five decimals, about a
// metre, which is as much as a browser gives anyway. Always on a user's
// gesture: the permission prompt belongs to a click, never to a page load.

let bind: Dom.element => unit = %raw(`
function (container) {
  container.querySelectorAll("[data-rn-geo]").forEach((button) => {
    const input = button.parentElement && button.parentElement.querySelector("input");
    if (!input) return;
    button.addEventListener("click", () => {
      if (!navigator.geolocation) return;
      button.disabled = true;
      navigator.geolocation.getCurrentPosition(
        (found) => {
          button.disabled = false;
          button.classList.remove("rn-error");
          input.value = found.coords.latitude.toFixed(5) + ", " + found.coords.longitude.toFixed(5);
          // Said aloud, so anything listening to the field — a live view, a
          // future validation — hears it the way it hears typing.
          input.dispatchEvent(new Event("input", { bubbles: true }));
        },
        () => {
          // Refused or unavailable: the button says so with its state, and the
          // field stays typeable — coordinates can always be pasted.
          button.disabled = false;
          button.classList.add("rn-error");
        },
        { enableHighAccuracy: true, timeout: 10000 },
      );
    });
  });
}
`)

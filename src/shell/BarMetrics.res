// How tall a sticky bar is, published as a CSS custom property.
//
// Below the two-pane breakpoint the page itself scrolls and three things want to stay
// at the top of it: the app's own bar, the pane's toolbar under it, and the page menu
// under that. Each has to know the height of what is above it, and CSS cannot measure
// — `top` takes a length, not "the bottom of that other element".
//
// A constant was the obvious answer and is wrong. The navbar is 45 px wide-ish and
// *wraps* at 320 px, where the controls drop under the wordmark and it becomes 81 px
// — and 320 px is exactly the width §1.4.10 makes us hold. A hardcoded offset there
// leaves either an overlap or a gap with the document sliding through it.
//
// So it is measured, once at mount and again whenever the bar changes shape, and
// written as a property on the document element, where it inherits to everything.
// The value is a number this module computed; nothing from a document reaches CSS.
let track: (Dom.element, string) => unit => unit = %raw(`
function (node, property) {
  const root = document.documentElement;
  const write = () => {
    root.style.setProperty(property, node.getBoundingClientRect().height + "px");
  };
  write();
  // Every browser this app supports has it; the guard is for a test environment
  // without a layout engine, where the fallback in the stylesheet is the answer.
  if (typeof ResizeObserver !== "function") return () => {};
  const observer = new ResizeObserver(write);
  observer.observe(node);
  return () => {
    observer.disconnect();
    root.style.removeProperty(property);
  };
}
`)

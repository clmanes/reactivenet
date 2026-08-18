// Typed bindings for the Adobe Spectrum custom elements.
//
// ReScript's JSX cannot express a hyphenated tag: `<sp-button />` is not parseable,
// because `sp-button` is not an identifier. So each component is a normal ReScript
// component that calls `React.createElement` with the tag name as a string, and
// declares its own props record — which gives us per-component type checking instead
// of the untyped `domProps` escape hatch.
//
// React 19 is what makes this pleasant: it sets real properties on custom elements
// when one exists and falls back to attributes otherwise, so booleans and event
// handlers behave. On React 18 these bindings would need refs and manual property
// assignment.

@module("react")
external createElement: (string, 'props) => React.element = "createElement"

// Side-effect imports: loading a module is what registers the element with the
// custom-element registry. Nothing is imported by name.
%%raw(`import "@spectrum-web-components/theme/sp-theme.js"`)
%%raw(`import "@spectrum-web-components/theme/spectrum-two/theme-light.js"`)
%%raw(`import "@spectrum-web-components/theme/spectrum-two/theme-lightest.js"`)
%%raw(`import "@spectrum-web-components/theme/spectrum-two/theme-darkest.js"`)
%%raw(`import "@spectrum-web-components/theme/express/theme-light.js"`)
%%raw(`import "@spectrum-web-components/theme/express/theme-dark.js"`)
%%raw(`import "@spectrum-web-components/theme/express/scale-medium.js"`)
%%raw(`import "@spectrum-web-components/theme/spectrum-two/theme-dark.js"`)
%%raw(`import "@spectrum-web-components/theme/spectrum-two/scale-medium.js"`)
%%raw(`import "@spectrum-web-components/action-button/sp-action-button.js"`)
%%raw(`import "@spectrum-web-components/button/sp-button.js"`)
%%raw(`import "@spectrum-web-components/switch/sp-switch.js"`)
%%raw(`import "@spectrum-web-components/picker/sp-picker.js"`)
%%raw(`import "@spectrum-web-components/menu/sp-menu-item.js"`)
%%raw(`import "@spectrum-web-components/textfield/sp-textfield.js"`)
%%raw(`import "@spectrum-web-components/field-label/sp-field-label.js"`)

module Theme = {
  type attrs = {
    system?: string,
    color?: string,
    scale?: string,
    className?: string,
    children?: React.element,
  }

  @react.component
  let make = (~system, ~color, ~scale="medium", ~className=?, ~children=?) =>
    createElement("sp-theme", {system, color, scale, ?className, ?children})
}

module ActionButton = {
  // Icon-only toolbar control. `label` becomes the accessible name and the tooltip —
  // an icon button without one is unusable with a screen reader and guesswork with a
  // mouse.
  type attrs = {
    quiet?: bool,
    selected?: bool,
    size?: string,
    disabled?: bool,
    title?: string,
    @as("aria-label") ariaLabel?: string,
    @as("aria-pressed") ariaPressed?: string,
    onClick?: JsxEvent.Mouse.t => unit,
    className?: string,
    children?: React.element,
  }

  @react.component
  let make = (
    ~label: string,
    ~selected=false,
    ~quiet=true,
    ~size=?,
    ~disabled=?,
    ~pressed=?,
    ~onClick=?,
    ~className=?,
    ~children=?,
  ) =>
    createElement(
      "sp-action-button",
      {
        quiet,
        selected,
        title: label,
        ariaLabel: label,
        ariaPressed: ?pressed->Option.map(value => value ? "true" : "false"),
        ?size,
        ?disabled,
        ?onClick,
        ?className,
        ?children,
      },
    )
}

module Button = {
  // A labelled button, for the page's primary actions. Distinct from ActionButton,
  // which is the icon-only toolbar control: this one's name is its visible text, so
  // there is no `label` to pass and nothing to keep in sync with it.
  type attrs = {
    variant?: string,
    treatment?: string,
    size?: string,
    disabled?: bool,
    @as("aria-label") ariaLabel?: string,
    onClick?: JsxEvent.Mouse.t => unit,
    className?: string,
    children?: React.element,
  }

  @react.component
  let make = (~variant="accent", ~treatment=?, ~size=?, ~disabled=?, ~onClick=?, ~className=?, ~children=?) =>
    createElement(
      "sp-button",
      {variant, ?treatment, ?size, ?disabled, ?onClick, ?className, ?children},
    )
}

module Switch = {
  type attrs = {
    checked?: bool,
    size?: string,
    // A switch with no visible text still has to have a name. React 19 sets a real
    // attribute on a custom element when there is no property of that name, which is
    // exactly what an ARIA attribute needs.
    @as("aria-label") ariaLabel?: string,
    onChange?: JsxEvent.Form.t => unit,
    className?: string,
    children?: React.element,
  }

  @react.component
  let make = (~checked=?, ~size=?, ~ariaLabel=?, ~onChange=?, ~className=?, ~children=?) =>
    createElement("sp-switch", {?checked, ?size, ?ariaLabel, ?onChange, ?className, ?children})
}


module Picker = {
  type attrs = {
    value?: string,
    size?: string,
    quiet?: bool,
    label?: string,
    @as("aria-label") ariaLabel?: string,
    onChange?: JsxEvent.Form.t => unit,
    className?: string,
    children?: React.element,
  }

  @react.component
  let make = (~value, ~label, ~size=?, ~quiet=true, ~onChange=?, ~className=?, ~children=?) =>
    createElement(
      "sp-picker",
      {value, label, ariaLabel: label, quiet, ?size, ?onChange, ?className, ?children},
    )
}

module MenuItem = {
  type attrs = {
    value?: string,
    selected?: bool,
    className?: string,
    children?: React.element,
  }

  @react.component
  let make = (~value, ~selected=?, ~className=?, ~children=?) =>
    createElement("sp-menu-item", {value, ?selected, ?className, ?children})
}

module Textfield = {
  type attrs = {
    id?: string,
    value?: string,
    placeholder?: string,
    size?: string,
    quiet?: bool,
    onInput?: JsxEvent.Form.t => unit,
    className?: string,
  }

  @react.component
  let make = (~id=?, ~value, ~placeholder=?, ~size=?, ~quiet=?, ~onInput=?, ~className=?) =>
    createElement("sp-textfield", {?id, value, ?placeholder, ?size, ?quiet, ?onInput, ?className})
}

module FieldLabel = {
  // `for` is a ReScript keyword, so the field is renamed and mapped back with @as
  type attrs = {
    @as("for") for_?: string,
    size?: string,
    className?: string,
    children?: React.element,
  }

  @react.component
  let make = (~for_=?, ~size=?, ~className=?, ~children=?) =>
    createElement("sp-field-label", {?for_, ?size, ?className, ?children})
}

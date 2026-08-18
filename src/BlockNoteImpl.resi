type props = {
  initialMarkdown: string,
  onChange: string => unit,
  dark: bool,
  localeTag: string,
}

let component: props => React.element

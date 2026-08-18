/** The prose of the two documents this app writes rather than reads. Separate from
    `Translations`, which holds interface strings: these are document contents, and a
    paragraph of markdown does not belong in the same switch as a button label. */
type text = {
  welcomeTitle: string,
  welcomeDescription: string,
  intro: string,
  openHint: string,
  reactiveHeading: string,
  reactiveIntro: string,
  volumeNow: string,
  refRule: string,
  dataHeading: string,
  dataIntro: string,
  noteField: string,
  whoField: string,
  saveButton: string,
  emptyNotes: string,
  savedNotes: string,
  componentsHeading: string,
  componentsIntro: string,
  nestingQuestion: string,
  nestingAnswer: string,
  markdownHeading: string,
  markdownIntro: string,
  starterIntro: string,
  addHeading: string,
  nameField: string,
  addButton: string,
  emptyItems: string,
  savedItems: string,
  whoHelp: string,
  viewsHeading: string,
  boardIntro: string,
  chooseHeading: string,
  chooseIntro: string,
  chooseLegend: string,
  chooseAnswer: string,
}

/** Adding a language fails to compile here until its prose is written. */
let of_: Locale.t => text

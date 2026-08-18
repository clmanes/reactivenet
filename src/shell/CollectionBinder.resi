type labels = {
  deleteRow: string,
  editRow: string,
  searchRows: string,
  previousPage: string,
  nextPage: string,
  sortedAscending: string,
  sortedDescending: string,
  allValues: string,
  previousMonth: string,
  nextMonth: string,
  previousWeek: string,
  nextWeek: string,
  today: string,
  blockedCell: string,
  pinnedRow: string,
}

/** Binds `data-rn-*` nodes inside the container to the app's stored collections:
    renders lists with their row actions, resolves `if-any`/`if-empty`, fills counts
    and aggregations, and wires the save button — which updates the row being edited
    when there is one, and inserts otherwise. Safe to call after every render.

    `labels` names the per-row buttons, which the binder creates rather than the
    renderer: there is one template and one button per row.

    `confirm` is asked before a row is deleted, with the row's own text so the
    question can name it; the row goes only if it resolves `true`. The dialog belongs
    to the caller — the preview's DOM is sanitiser output and no chrome is added to
    it.

    `locale` is the tag a row's dates are written in. Only the display changes: what
    is stored stays ISO 8601, which is what makes it sort and survive a backup taken
    in another time zone. */
let bind: (
  Dom.element,
  ~app: string,
  ~labels: labels,
  ~locale: string,
  ~confirm: string => promise<bool>,
) => unit

/** The fingerprint of the welcome app this browser was seeded with, or the empty
    string when it was never recorded — which is the case for a browser seeded before
    this existed, and is deliberately treated as "leave it alone". */
let read: unit => promise<string>

let record: string => promise<unit>

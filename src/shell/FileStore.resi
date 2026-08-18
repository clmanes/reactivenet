/** The device-local contents of large ::file attachments, by app and id. The
    row carries {name, local: id}; the bytes stay here. */

let save: (~app: string, ~id: string, string) => promise<unit>

let load: (~app: string, ~id: string) => promise<option<string>>

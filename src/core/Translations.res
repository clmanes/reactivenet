// Pure. The message catalogue, as a variant of keys rather than a map of strings.
//
// That choice is the point: each locale is a `switch` over the same key type, so
// adding a key breaks compilation in all seven languages until every one of them is
// translated. A missing translation is a build error, never a string that silently
// falls back to English at runtime.

type key =
  | EditorPane
  | PreviewPane
  | AppPane
  | MarkdownEditor
  | BlockEditor
  | PhoneWidth
  | FullWidth
  | PaletteLabel
  | DarkMode
  | LightMode
  | Language
  | LoadingBlockEditor
  | LinkRemoved
  | DocumentInfo
  | NoDocumentInfo
  | Directives
  | NoDirectives
  | RemoveDirective
  | ScrollableTable
  | DataPanel
  | NoCollections
  | BackupAction
  | RestoreAction
  | DeleteData
  | BackupFromOtherApp
  | NoAppId
  | Gallery
  | NewApp
  | OpenApp
  | EditApp
  | DeleteApp
  | NoApps
  | BackToGallery
  | AppsHeading
  | Untitled
  | SavedJustNow
  | CopyLink
  | LinkCopied
  | ViewApp
  | SearchApps
  | NoMatches
  | DeleteAppQuestion
  | DeleteAppWarning
  | CancelAction
  | DeleteDataQuestion
  | DeleteDataWarning
  | DeleteRow
  | EditRow
  | DeleteRowQuestion
  | DeleteRowWarning
  | Pages
  | ExportApp
  | ImportApp
  | ImportedAsCopy
  | NotADocument
  | SearchRows
  | PreviousPage
  | NextPage
  | SortedAscending
  | SortedDescending
  // What a form says when it refuses to save. `{n}` in the two bounds is the limit
  // the author set, put in by the binder — a message that said "too small" without
  // saying what would be big enough would send the reader back to the document.
  | FieldRequired
  | FieldNotANumber
  | FieldNotADate
  | FieldNotATime
  | FieldNotAnEmail
  | FieldNotAUrl
  | FieldBelow
  | FieldAbove
  | FieldNotMatching
  | CheckTheForm
  | ExportCollection
  | ImportCollection
  | ImportIntoCollection
  | CollectionName
  | NotACollectionFile
  | RowsImported
  | AllValues
  | PreviousMonth
  | NextMonth
  | DuplicateApp
  | ClassStructure
  | ClassData
  | ClassAi
  | ClassViews
  | ClassValues
  | ClassStatus
  | ClassControls
  | ClassNavigation
  | ClassLayout
  | ClassOverlays
  | ClassColour
  | ClassTableParts
  | ShareApp
  | ShareLinkLabel
  | ShareInvitation
  | BrokenShareLink
  | ShareTooBig
  | ShareByEmail
  | ShareNative
  | CopyAction
  | ShowCode
  | HideCode
  | PythonRunning
  | PythonLoading
  | ShareShortInfo
  | ShareLongInfo
  | ShareExpired
  | AccountLabel
  | SignInAction
  | SignOutAction
  | CreateAccountAction
  | UsernameLabel
  | PasswordLabel
  | UsernameHint
  | PasswordHint
  | AccountIntro
  | RecoveryCodeTitle
  | RecoveryCodeInfo
  | RecoveryCodeDone
  | AccountFailed
  | UsernameTaken
  | SignedInAs
  | SyncPanel
  | SyncNeedsAccount
  | SyncThisApp
  | SyncOnInfo
  | InviteAction
  | InviteLinkInfo
  | RoleOwner
  | RoleEditor
  | RoleReader
  | MembersHeading
  | RemoveMember
  | LeaveSpace
  | JoinQuestion
  | JoinAction
  | InviteInvalid
  | SyncOffline
  | ChatPanel
  | ChatSend
  | ChatPlaceholder
  | ChatEmpty
  | ChatGuest
  | ChatAttach
  | ChatFileTooBig
  | OdLoading
  | OdRows
  | OdStale
  | OdUnreachable
  | OdRefused
  | MlEngineNeeded
  | OdSearchAction
  | RemoveFilter
  | ApiRefresh
  | FileTooBig
  | RunAction
  | PreviousWeek
  | NextWeek
  | TodayAction
  | StopAction
  | InProgress
  | CellBlocked
  | PinnedRow
  | PrintAction
  | PrintEach
  | AiPanel
  | AiPlaceholder
  | AiStop
  | AiEmpty
  | AiSettingsAction
  | AiClear
  | AiKeyLabel
  | AiKeyHelp
  | AiModelLabel
  | AiEndpointLabel
  | AiSaveSettings
  | AiNeedsKey
  | AiNeedsHttps
  | AiThinking
  | AiWorking
  | AiUsedTool
  | AiCreated
  | AiProposal
  | AiApply
  | AiDiscard
  | AiStalled
  | AiMcpOffline
  | AiNoModels
  | AiModelNoTools
  | AiFailed
  | AiNoAnswer
  | AiNotConfigured
  | AiAsk
  | AiSend
  | AiConfirm
  | AiIndexing
  | LegalNotices
  | CatalogUnreachable
  | CatalogMissing
  | CatalogueHeading
  | CatalogueLead
  | CatalogueAdd
  | UpdateAvailable
  | UpdateApp
  | UpdateQuestion
  | UpdateWarning
  | UpdateDone
  | UpdateFailed
  | WorkflowRunNow
  | WorkflowSteps
  | WorkflowWaiting
  | WorkflowSkipped
  | WorkflowFailed
  | WorkflowLastRun
  | WorkflowNextRun
  | WorkflowNever
  | WorkflowCycle
  | WorkflowNoSteps
  | WorkflowWhileOpen
  | WorkflowLooped

let english = key =>
  switch key {
  | EditorPane => "Editor"
  | PreviewPane => "Preview"
  | AppPane => "App"
  | MarkdownEditor => "Markdown editor"
  | BlockEditor => "Block editor"
  | PhoneWidth => "Phone width"
  | FullWidth => "Full width"
  | PaletteLabel => "Palette"
  | DarkMode => "Dark mode"
  | LightMode => "Light mode"
  | Language => "Language"
  | LoadingBlockEditor => "Loading the block editor…"
  | LinkRemoved => "Link removed: scheme not allowed"
  | DocumentInfo => "Document info"
  | NoDocumentInfo => "This document has no frontmatter."
  | Directives => "Directives"
  | NoDirectives => "No directives in this document."
  | RemoveDirective => "Remove directive"
  | ScrollableTable => "Table, scrollable"
  | DataPanel => "Data"
  | NoCollections => "This app has stored no data yet."
  | BackupAction => "Back up"
  | RestoreAction => "Restore"
  | DeleteData => "Delete all data"
  | BackupFromOtherApp => "That backup belongs to another app."
  | NoAppId => "Give the document an appId to store data."
  | Gallery => "Apps"
  | NewApp => "New app"
  | OpenApp => "Open"
  | EditApp => "Edit"
  | DeleteApp => "Delete app"
  | NoApps => "No apps yet. Create one to get started."
  | BackToGallery => "All apps"
  | AppsHeading => "Your apps"
  | Untitled => "Untitled app"
  | SavedJustNow => "Saved"
  | CopyLink => "Copy link"
  | LinkCopied => "Link copied"
  | ViewApp => "View"
  | SearchApps => "Search apps"
  | NoMatches => "No app matches that search."
  | DeleteAppQuestion => "Delete this app?"
  | DeleteAppWarning => "Its stored data is deleted with it. This cannot be undone."
  | CancelAction => "Cancel"
  | DeleteDataQuestion => "Delete this data?"
  | DeleteDataWarning => "The rows are removed from this browser. This cannot be undone."
  | DeleteRow => "Delete row"
  | EditRow => "Edit row"
  | DeleteRowQuestion => "Delete this row?"
  | DeleteRowWarning => "The row is removed from this browser. This cannot be undone."
  | ExportApp => "Save to a file"
  | ImportApp => "Open from a file"
  | ImportedAsCopy => "An app with that id was already here, so this one was opened as a copy."
  | NotADocument => "That is not a ReactiveNET document."
  | SearchRows => "Search rows"
  | PreviousPage => "Previous page"
  | NextPage => "Next page"
  | SortedAscending => "Sorted ascending"
  | SortedDescending => "Sorted descending"
  | Pages => "Pages"
  | FieldRequired => "Required"
  | FieldNotANumber => "Must be a number"
  | FieldNotADate => "Must be a date"
  | FieldNotATime => "Must be a time"
  | FieldNotAnEmail => "Must be an email address"
  | FieldNotAUrl => "Must be a web address"
  | FieldBelow => "Must be at least {n}"
  | FieldAbove => "Must be at most {n}"
  | FieldNotMatching => "Not in the expected format"
  | CheckTheForm => "Check the fields marked below"
  | ExportCollection => "Save as CSV"
  | ImportCollection => "Add rows from a file"
  | ImportIntoCollection => "Import into"
  | CollectionName => "collection name"
  | NotACollectionFile => "That file has no columns to read."
  | RowsImported => "{n} rows added"
  | AllValues => "All"
  | PreviousMonth => "Previous month"
  | NextMonth => "Next month"
  | DuplicateApp => "Duplicate"
  | ClassStructure => "Structure"
  | ClassData => "Data"
  | ClassAi => "Assistant"
  | ClassViews => "Views"
  | ClassValues => "Values"
  | ClassStatus => "Status"
  | ClassControls => "Controls"
  | ClassNavigation => "Navigation"
  | ClassLayout => "Layout"
  | ClassOverlays => "Overlays"
  | ClassColour => "Colour"
  | ClassTableParts => "Table parts"
  | ShareApp => "Share this app"
  | ShareLinkLabel => "Anyone with this link gets a copy of the app — not of its data."
  | ShareInvitation => "open this app"
  | BrokenShareLink => "That link is incomplete: ask for it again."
  | ShareTooBig => "This app is too large to send as a link. Save it to a file instead."
  | ShareByEmail => "Email"
  | ShareNative => "Share…"
  | CopyAction => "Copy"
  | ShowCode => "Show code"
  | HideCode => "Hide code"
  | PythonRunning => "Running…"
  | PythonLoading => "Starting Python…"
  | ShareShortInfo => "Encrypted — the server cannot read it. Expires 120 days after its last opening."
  | ShareLongInfo => "Full link, no server involved"
  | ShareExpired => "This link has expired or was removed: ask for it again."
  | AccountLabel => "Account"
  | SignInAction => "Sign in"
  | SignOutAction => "Sign out"
  | CreateAccountAction => "Create account"
  | UsernameLabel => "Username"
  | PasswordLabel => "Password"
  | UsernameHint => "3–32 characters: lowercase letters, digits, dashes."
  | PasswordHint => "At least 8 characters."
  | AccountIntro => "An account is needed only to sync shared data with other people — everything else stays in this browser. No email, no name: a username and a password."
  | RecoveryCodeTitle => "Recovery code"
  | RecoveryCodeInfo => "Write it down and keep it somewhere safe. If you forget your password, this code is the only way back to your shared data: the server holds it encrypted and cannot reset what it cannot read."
  | RecoveryCodeDone => "I saved it"
  | AccountFailed => "That did not work. Check the username and the password."
  | UsernameTaken => "That username is taken."
  | SignedInAs => "Signed in as"
  | SyncPanel => "Sync"
  | SyncNeedsAccount => "Sign in to sync this app's data with other people."
  | SyncThisApp => "Sync this app's data"
  | SyncOnInfo => "This app's data is shared: it syncs, encrypted, with everyone invited."
  | InviteAction => "Invite"
  | InviteLinkInfo => "Whoever opens this link joins with the role it names. It works once."
  | RoleOwner => "Owner"
  | RoleEditor => "Can edit"
  | RoleReader => "Read only"
  | MembersHeading => "Members"
  | RemoveMember => "Remove"
  | LeaveSpace => "Leave"
  | JoinQuestion => "This link invites you to an app with shared data. Join?"
  | JoinAction => "Join"
  | InviteInvalid => "This invitation has expired or was already used."
  | SyncOffline => "Sync is paused: the server is not reachable."
  | ChatPanel => "Chat"
  | ChatSend => "Send"
  | ChatPlaceholder => "Write a message…"
  | ChatEmpty => "No messages yet."
  | ChatGuest => "Guest"
  | ChatAttach => "Attach a file"
  | ChatFileTooBig => "An attachment can be at most 700 kB."
  | OdLoading => "Loading open data…"
  | OdRows => "rows"
  | OdStale => "the service is not answering — showing the last data received"
  | OdUnreachable => "The open-data service is not reachable."
  | OdRefused => "The query was refused:"
  | MlEngineNeeded => "The calculation engine has to be downloaded for this model."
  | OdSearchAction => "Search"
  | RemoveFilter => "Remove the filter"
  | ApiRefresh => "Refresh the data"
  | FileTooBig => "The file is over the {n} kB ceiling."
  | RunAction => "Run"
  | PreviousWeek => "Previous week"
  | NextWeek => "Next week"
  | TodayAction => "Today"
  | StopAction => "Stop"
  | InProgress => "In progress…"
  | CellBlocked => "This slot is not available."
  | PinnedRow => "Fixed — it cannot be moved"
  | PrintAction => "Print"
  | PrintEach => "Print one page each"
  | AiPanel => "Assistant"
  | AiPlaceholder => "Describe the app you want"
  | AiStop => "Stop"
  | AiEmpty => "Ask for an app: it is written, checked, and added to your gallery."
  | AiSettingsAction => "Assistant settings"
  | AiClear => "Clear the conversation"
  | AiKeyLabel => "API key"
  | AiKeyHelp => "Kept in this browser, and sent only to the provider you chose."
  | AiModelLabel => "Model"
  | AiEndpointLabel => "Endpoint"
  | AiSaveSettings => "Save"
  | AiNeedsKey => "Enter your API key, or choose a model running on this computer."
  | AiNeedsHttps => "The endpoint has to be https, or http on localhost."
  | AiThinking => "Thinking…"
  | AiWorking => "Working…"
  | AiUsedTool => "Tool used"
  | AiCreated => "App created"
  | AiProposal => "Proposed change"
  | AiApply => "Apply"
  | AiDiscard => "Discard"
  | AiStalled => "The assistant stopped after too many steps. Ask again, more simply."
  | AiMcpOffline => "The documentation server is not answering, so the assistant cannot look the directives up or check what it writes. Start it with: bun run mcp"
  | AiNoModels => "No model on this computer. Install one, for example: ollama pull qwen3.5:4b"
  | AiModelNoTools => "cannot use tools"
  | AiFailed => "It did not work:"
  | AiNoAnswer => "The model ended without answering. Ask again, or try a larger model."
  | AiNotConfigured => "No model configured: open the assistant's settings to choose one. The app keeps working without it."
  | AiAsk => "Ask something…"
  | AiSend => "Send"
  | AiConfirm => "Confirm"
  | AiIndexing => "Indexing…"
  | WorkflowRunNow => "Run now"
  | WorkflowSteps => "Steps"
  | WorkflowWaiting => "waiting"
  | WorkflowSkipped => "skipped — the step before it did not finish"
  | WorkflowFailed => "did not finish"
  | WorkflowLastRun => "Last run:"
  | WorkflowNextRun => "Next:"
  | WorkflowNever => "never run"
  | WorkflowCycle => "These steps feed each other in a circle, so none of them can go first. Give one of them a collection of its own."
  | WorkflowNoSteps => "This workflow has nothing to run: put the directives that produce data inside it — ::od-query, ::sql, ::python, ml-*."
  | WorkflowWhileOpen => "Runs while the app is open."
  | WorkflowLooped => "in a circle"
  | CatalogUnreachable => "The catalogue did not answer. Check the connection and try again."
  | CatalogMissing => "The catalogue does not have that app."
  | CatalogueHeading => "From the catalogue"
  | CatalogueLead => "Published apps you do not have yet. Opening one copies it into this browser, where it becomes yours to change."
  | CatalogueAdd => "Add it"
  | UpdateAvailable => "Update available"
  | UpdateApp => "Update"
  | UpdateQuestion => "Take the published version?"
  | UpdateWarning => "The document of this app is replaced by the one the catalogue publishes. Its saved data is not touched — the rows live outside the document — but anything you changed in the document itself is lost."
  | UpdateDone => "Updated from the catalogue."
  | UpdateFailed => "The catalogue did not answer: the app is unchanged."
  | LegalNotices => "Legal notices"
  }

let french = key =>
  switch key {
  | EditorPane => "Éditeur"
  | PreviewPane => "Aperçu"
  | AppPane => "Application"
  | MarkdownEditor => "Éditeur Markdown"
  | BlockEditor => "Éditeur de blocs"
  | PhoneWidth => "Largeur mobile"
  | FullWidth => "Pleine largeur"
  | PaletteLabel => "Palette"
  | DarkMode => "Mode sombre"
  | LightMode => "Mode clair"
  | Language => "Langue"
  | LoadingBlockEditor => "Chargement de l'éditeur de blocs…"
  | LinkRemoved => "Lien supprimé : schéma non autorisé"
  | DocumentInfo => "Informations du document"
  | NoDocumentInfo => "Ce document n'a pas d'en-tête."
  | Directives => "Directives"
  | NoDirectives => "Aucune directive dans ce document."
  | RemoveDirective => "Supprimer la directive"
  | ScrollableTable => "Tableau, défilement horizontal"
  | DataPanel => "Données"
  | NoCollections => "Cette application n'a encore aucune donnée."
  | BackupAction => "Sauvegarder"
  | RestoreAction => "Restaurer"
  | DeleteData => "Supprimer toutes les données"
  | BackupFromOtherApp => "Cette sauvegarde appartient à une autre application."
  | NoAppId => "Donnez un appId au document pour stocker des données."
  | Gallery => "Applications"
  | NewApp => "Nouvelle application"
  | OpenApp => "Ouvrir"
  | EditApp => "Modifier"
  | DeleteApp => "Supprimer l'application"
  | NoApps => "Aucune application. Créez-en une pour commencer."
  | BackToGallery => "Toutes les applications"
  | AppsHeading => "Vos applications"
  | Untitled => "Application sans titre"
  | SavedJustNow => "Enregistré"
  | CopyLink => "Copier le lien"
  | LinkCopied => "Lien copié"
  | ViewApp => "Afficher"
  | SearchApps => "Rechercher une application"
  | NoMatches => "Aucune application ne correspond."
  | DeleteAppQuestion => "Supprimer cette application ?"
  | DeleteAppWarning => "Ses données enregistrées sont supprimées avec elle. Action irréversible."
  | CancelAction => "Annuler"
  | DeleteDataQuestion => "Supprimer ces données ?"
  | DeleteDataWarning => "Les lignes sont retirées de ce navigateur. Action irréversible."
  | DeleteRow => "Supprimer la ligne"
  | EditRow => "Modifier la ligne"
  | DeleteRowQuestion => "Supprimer cette ligne ?"
  | DeleteRowWarning => "La ligne est retirée de ce navigateur. Action irréversible."
  | ExportApp => "Enregistrer dans un fichier"
  | ImportApp => "Ouvrir depuis un fichier"
  | ImportedAsCopy => "Une application portait déjà cet identifiant : celle-ci a été ouverte comme copie."
  | NotADocument => "Ce n'est pas un document ReactiveNET."
  | SearchRows => "Rechercher une ligne"
  | PreviousPage => "Page précédente"
  | NextPage => "Page suivante"
  | SortedAscending => "Tri croissant"
  | SortedDescending => "Tri décroissant"
  | Pages => "Pages"
  | FieldRequired => "Obligatoire"
  | FieldNotANumber => "Doit être un nombre"
  | FieldNotADate => "Doit être une date"
  | FieldNotATime => "Doit être une heure"
  | FieldNotAnEmail => "Doit être une adresse e-mail"
  | FieldNotAUrl => "Doit être une adresse web"
  | FieldBelow => "Doit valoir au moins {n}"
  | FieldAbove => "Doit valoir au plus {n}"
  | FieldNotMatching => "Format inattendu"
  | CheckTheForm => "Vérifiez les champs signalés"
  | ExportCollection => "Enregistrer en CSV"
  | ImportCollection => "Ajouter des lignes depuis un fichier"
  | ImportIntoCollection => "Importer dans"
  | CollectionName => "nom de la collection"
  | NotACollectionFile => "Ce fichier n'a aucune colonne lisible."
  | RowsImported => "{n} lignes ajoutées"
  | AllValues => "Tous"
  | PreviousMonth => "Mois précédent"
  | NextMonth => "Mois suivant"
  | DuplicateApp => "Dupliquer"
  | ClassStructure => "Structure"
  | ClassData => "Données"
  | ClassAi => "Assistant"
  | ClassViews => "Vues"
  | ClassValues => "Valeurs"
  | ClassStatus => "État"
  | ClassControls => "Contrôles"
  | ClassNavigation => "Navigation"
  | ClassLayout => "Mise en page"
  | ClassOverlays => "Superpositions"
  | ClassColour => "Couleur"
  | ClassTableParts => "Éléments de tableau"
  | ShareApp => "Partager cette application"
  | ShareLinkLabel => "Ce lien donne une copie de l'application — pas de ses données."
  | ShareInvitation => "ouvrir cette application"
  | BrokenShareLink => "Ce lien est incomplet : demandez-le à nouveau."
  | ShareTooBig => "Cette application est trop grande pour un lien. Enregistrez-la dans un fichier."
  | ShareByEmail => "E-mail"
  | ShareNative => "Partager…"
  | CopyAction => "Copier"
  | ShowCode => "Afficher le code"
  | HideCode => "Masquer le code"
  | PythonRunning => "Exécution…"
  | PythonLoading => "Démarrage de Python…"
  | ShareShortInfo => "Chiffré — le serveur ne peut pas le lire. Expire 120 jours après la dernière ouverture."
  | ShareLongInfo => "Lien complet, sans serveur"
  | ShareExpired => "Ce lien a expiré ou a été supprimé : demandez-le à nouveau."
  | AccountLabel => "Compte"
  | SignInAction => "Se connecter"
  | SignOutAction => "Se déconnecter"
  | CreateAccountAction => "Créer un compte"
  | UsernameLabel => "Nom d'utilisateur"
  | PasswordLabel => "Mot de passe"
  | UsernameHint => "De 3 à 32 caractères : minuscules, chiffres, tirets."
  | PasswordHint => "Au moins 8 caractères."
  | AccountIntro => "Un compte ne sert qu'à synchroniser les données partagées avec d'autres personnes — tout le reste demeure dans ce navigateur. Ni e-mail, ni nom : un nom d'utilisateur et un mot de passe."
  | RecoveryCodeTitle => "Code de récupération"
  | RecoveryCodeInfo => "Notez-le et gardez-le en lieu sûr. Si vous oubliez votre mot de passe, ce code est le seul retour vers vos données partagées : le serveur les détient chiffrées et ne peut pas réinitialiser ce qu'il ne peut pas lire."
  | RecoveryCodeDone => "Je l'ai noté"
  | AccountFailed => "Cela n'a pas fonctionné. Vérifiez le nom d'utilisateur et le mot de passe."
  | UsernameTaken => "Ce nom d'utilisateur est déjà pris."
  | SignedInAs => "Connecté en tant que"
  | SyncPanel => "Synchronisation"
  | SyncNeedsAccount => "Connectez-vous pour synchroniser les données de cette application avec d'autres personnes."
  | SyncThisApp => "Synchroniser les données de cette application"
  | SyncOnInfo => "Les données de cette application sont partagées : elles se synchronisent, chiffrées, avec toutes les personnes invitées."
  | InviteAction => "Inviter"
  | InviteLinkInfo => "Qui ouvre ce lien rejoint avec le rôle qu'il indique. Il ne fonctionne qu'une fois."
  | RoleOwner => "Propriétaire"
  | RoleEditor => "Peut modifier"
  | RoleReader => "Lecture seule"
  | MembersHeading => "Membres"
  | RemoveMember => "Retirer"
  | LeaveSpace => "Quitter l'espace"
  | JoinQuestion => "Ce lien vous invite à une application aux données partagées. Rejoindre ?"
  | JoinAction => "Rejoindre"
  | InviteInvalid => "Cette invitation a expiré ou a déjà été utilisée."
  | SyncOffline => "Synchronisation en pause : le serveur est injoignable."
  | ChatPanel => "Discussion"
  | ChatSend => "Envoyer"
  | ChatPlaceholder => "Écrire un message…"
  | ChatEmpty => "Aucun message pour l'instant."
  | ChatGuest => "Invité"
  | ChatAttach => "Joindre un fichier"
  | ChatFileTooBig => "Une pièce jointe ne peut pas dépasser 700 ko."
  | OdLoading => "Chargement des données ouvertes…"
  | OdRows => "lignes"
  | OdStale => "le service ne répond pas — affichage des dernières données reçues"
  | OdUnreachable => "Le service de données ouvertes est injoignable."
  | OdRefused => "La requête a été refusée :"
  | MlEngineNeeded => "Le moteur de calcul doit être téléchargé pour ce modèle."
  | OdSearchAction => "Rechercher"
  | RemoveFilter => "Retirer le filtre"
  | ApiRefresh => "Actualiser les données"
  | FileTooBig => "Le fichier dépasse le plafond de {n} ko."
  | RunAction => "Exécuter"
  | PreviousWeek => "Semaine précédente"
  | NextWeek => "Semaine suivante"
  | TodayAction => "Aujourd'hui"
  | StopAction => "Arrêter"
  | InProgress => "En cours…"
  | CellBlocked => "Ce créneau n'est pas disponible."
  | PinnedRow => "Fixé — impossible à déplacer"
  | PrintAction => "Imprimer"
  | PrintEach => "Imprimer une page par ligne"
  | AiPanel => "Assistant"
  | AiPlaceholder => "Décrivez l'application voulue"
  | AiStop => "Arrêter"
  | AiEmpty => "Demandez une application : elle est écrite, vérifiée, puis ajoutée à votre galerie."
  | AiSettingsAction => "Réglages de l'assistant"
  | AiClear => "Effacer la conversation"
  | AiKeyLabel => "Clé API"
  | AiKeyHelp => "Conservée dans ce navigateur, et envoyée au seul fournisseur choisi."
  | AiModelLabel => "Modèle"
  | AiEndpointLabel => "Adresse du service"
  | AiSaveSettings => "Enregistrer"
  | AiNeedsKey => "Saisissez votre clé API, ou choisissez un modèle installé sur cet ordinateur."
  | AiNeedsHttps => "L'adresse doit être en https, ou en http sur localhost."
  | AiThinking => "Réflexion…"
  | AiWorking => "Traitement…"
  | AiUsedTool => "Outil utilisé"
  | AiCreated => "Application créée"
  | AiProposal => "Modification proposée"
  | AiApply => "Appliquer"
  | AiDiscard => "Abandonner"
  | AiStalled => "L'assistant s'est arrêté après trop d'étapes. Reformulez plus simplement."
  | AiMcpOffline => "Le serveur de documentation ne répond pas : l'assistant ne peut ni consulter les directives ni vérifier ce qu'il écrit. Démarrez-le avec : bun run mcp"
  | AiNoModels => "Aucun modèle sur cet ordinateur. Installez-en un, par exemple : ollama pull qwen3.5:4b"
  | AiModelNoTools => "ne sait pas utiliser d'outils"
  | AiFailed => "Cela n'a pas fonctionné :"
  | AiNoAnswer => "Le modèle s'est arrêté sans répondre. Redemandez, ou essayez un modèle plus grand."
  | AiNotConfigured => "Aucun modèle configuré : ouvrez les réglages de l'assistant pour en choisir un. L'application fonctionne sans."
  | AiAsk => "Posez une question…"
  | AiSend => "Envoyer"
  | AiConfirm => "Confirmer"
  | AiIndexing => "Indexation…"
  | WorkflowRunNow => "Exécuter maintenant"
  | WorkflowSteps => "Étapes"
  | WorkflowWaiting => "en attente"
  | WorkflowSkipped => "ignorée — l'étape précédente n'a pas abouti"
  | WorkflowFailed => "n'a pas abouti"
  | WorkflowLastRun => "Dernière exécution :"
  | WorkflowNextRun => "Prochaine :"
  | WorkflowNever => "jamais exécuté"
  | WorkflowCycle => "Ces étapes s'alimentent en cercle : aucune ne peut passer en premier. Donnez à l'une d'elles une collection à elle."
  | WorkflowNoSteps => "Ce flux n'a rien à exécuter : placez à l'intérieur les directives qui produisent des données — ::od-query, ::sql, ::python, ml-*."
  | WorkflowWhileOpen => "S'exécute tant que l'application est ouverte."
  | WorkflowLooped => "dans un cercle"
  | CatalogUnreachable => "Le catalogue n'a pas répondu. Vérifiez la connexion et réessayez."
  | CatalogMissing => "Le catalogue n'a pas cette application."
  | CatalogueHeading => "Du catalogue"
  | CatalogueLead => "Des applications publiées que vous n'avez pas encore. En ouvrir une la copie dans ce navigateur, où elle devient la vôtre."
  | CatalogueAdd => "L'ajouter"
  | UpdateAvailable => "Mise à jour disponible"
  | UpdateApp => "Mettre à jour"
  | UpdateQuestion => "Prendre la version publiée ?"
  | UpdateWarning => "Le document de cette application est remplacé par celui que publie le catalogue. Ses données enregistrées ne sont pas touchées — les lignes vivent hors du document — mais ce que vous avez modifié dans le document lui-même est perdu."
  | UpdateDone => "Mise à jour depuis le catalogue."
  | UpdateFailed => "Le catalogue n'a pas répondu : l'application est inchangée."
  | LegalNotices => "Mentions légales"
  }

let german = key =>
  switch key {
  | EditorPane => "Editor"
  | PreviewPane => "Vorschau"
  | AppPane => "Anwendung"
  | MarkdownEditor => "Markdown-Editor"
  | BlockEditor => "Blockeditor"
  | PhoneWidth => "Handybreite"
  | FullWidth => "Volle Breite"
  | PaletteLabel => "Farbpalette"
  | DarkMode => "Dunkelmodus"
  | LightMode => "Hellmodus"
  | Language => "Sprache"
  | LoadingBlockEditor => "Blockeditor wird geladen…"
  | LinkRemoved => "Link entfernt: Schema nicht zulässig"
  | DocumentInfo => "Dokumentinfo"
  | NoDocumentInfo => "Dieses Dokument hat kein Frontmatter."
  | Directives => "Direktiven"
  | NoDirectives => "Keine Direktiven in diesem Dokument."
  | RemoveDirective => "Direktive entfernen"
  | ScrollableTable => "Tabelle, scrollbar"
  | DataPanel => "Daten"
  | NoCollections => "Diese App hat noch keine Daten gespeichert."
  | BackupAction => "Sichern"
  | RestoreAction => "Wiederherstellen"
  | DeleteData => "Alle Daten löschen"
  | BackupFromOtherApp => "Diese Sicherung gehört zu einer anderen App."
  | NoAppId => "Geben Sie dem Dokument eine appId, um Daten zu speichern."
  | Gallery => "Apps"
  | NewApp => "Neue App"
  | OpenApp => "Öffnen"
  | EditApp => "Bearbeiten"
  | DeleteApp => "App löschen"
  | NoApps => "Noch keine Apps. Erstellen Sie eine, um zu beginnen."
  | BackToGallery => "Alle Apps"
  | AppsHeading => "Ihre Apps"
  | Untitled => "App ohne Titel"
  | SavedJustNow => "Gespeichert"
  | CopyLink => "Link kopieren"
  | LinkCopied => "Link kopiert"
  | ViewApp => "Ansehen"
  | SearchApps => "Apps durchsuchen"
  | NoMatches => "Keine App passt zu dieser Suche."
  | DeleteAppQuestion => "Diese App löschen?"
  | DeleteAppWarning => "Ihre gespeicherten Daten werden mitgelöscht. Das lässt sich nicht rückgängig machen."
  | CancelAction => "Abbrechen"
  | DeleteDataQuestion => "Diese Daten löschen?"
  | DeleteDataWarning => "Die Zeilen werden aus diesem Browser entfernt. Das lässt sich nicht rückgängig machen."
  | DeleteRow => "Zeile löschen"
  | EditRow => "Zeile bearbeiten"
  | DeleteRowQuestion => "Diese Zeile löschen?"
  | DeleteRowWarning => "Die Zeile wird aus diesem Browser entfernt. Das lässt sich nicht rückgängig machen."
  | ExportApp => "In eine Datei speichern"
  | ImportApp => "Aus einer Datei öffnen"
  | ImportedAsCopy => "Eine App mit dieser Kennung war schon da, diese wurde als Kopie geöffnet."
  | NotADocument => "Das ist kein ReactiveNET-Dokument."
  | SearchRows => "Zeilen durchsuchen"
  | PreviousPage => "Vorherige Seite"
  | NextPage => "Nächste Seite"
  | SortedAscending => "Aufsteigend sortiert"
  | SortedDescending => "Absteigend sortiert"
  | Pages => "Seiten"
  | FieldRequired => "Erforderlich"
  | FieldNotANumber => "Muss eine Zahl sein"
  | FieldNotADate => "Muss ein Datum sein"
  | FieldNotATime => "Muss eine Uhrzeit sein"
  | FieldNotAnEmail => "Muss eine E-Mail-Adresse sein"
  | FieldNotAUrl => "Muss eine Webadresse sein"
  | FieldBelow => "Muss mindestens {n} sein"
  | FieldAbove => "Darf höchstens {n} sein"
  | FieldNotMatching => "Entspricht nicht dem erwarteten Format"
  | CheckTheForm => "Prüfen Sie die markierten Felder"
  | ExportCollection => "Als CSV speichern"
  | ImportCollection => "Zeilen aus einer Datei hinzufügen"
  | ImportIntoCollection => "Importieren in"
  | CollectionName => "Name der Sammlung"
  | NotACollectionFile => "Diese Datei hat keine lesbaren Spalten."
  | RowsImported => "{n} Zeilen hinzugefügt"
  | AllValues => "Alle"
  | PreviousMonth => "Vorheriger Monat"
  | NextMonth => "Nächster Monat"
  | DuplicateApp => "Duplizieren"
  | ClassStructure => "Struktur"
  | ClassData => "Daten"
  | ClassAi => "Assistent"
  | ClassViews => "Ansichten"
  | ClassValues => "Werte"
  | ClassStatus => "Status"
  | ClassControls => "Bedienelemente"
  | ClassNavigation => "Navigation"
  | ClassLayout => "Layout"
  | ClassOverlays => "Overlays"
  | ClassColour => "Farbe"
  | ClassTableParts => "Tabellenteile"
  | ShareApp => "Diese App teilen"
  | ShareLinkLabel => "Wer den Link hat, bekommt eine Kopie der App — nicht ihrer Daten."
  | ShareInvitation => "diese App öffnen"
  | BrokenShareLink => "Dieser Link ist unvollständig: bitte erneut anfordern."
  | ShareTooBig => "Diese App ist zu groß für einen Link. Speichern Sie sie als Datei."
  | ShareByEmail => "E-Mail"
  | ShareNative => "Teilen…"
  | CopyAction => "Kopieren"
  | ShowCode => "Code anzeigen"
  | HideCode => "Code ausblenden"
  | PythonRunning => "Läuft…"
  | PythonLoading => "Python wird gestartet…"
  | ShareShortInfo => "Verschlüsselt — der Server kann es nicht lesen. Verfällt 120 Tage nach dem letzten Öffnen."
  | ShareLongInfo => "Vollständiger Link, ohne Server"
  | ShareExpired => "Dieser Link ist abgelaufen oder wurde entfernt: bitte erneut anfordern."
  | AccountLabel => "Konto"
  | SignInAction => "Anmelden"
  | SignOutAction => "Abmelden"
  | CreateAccountAction => "Konto erstellen"
  | UsernameLabel => "Benutzername"
  | PasswordLabel => "Passwort"
  | UsernameHint => "3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Bindestriche."
  | PasswordHint => "Mindestens 8 Zeichen."
  | AccountIntro => "Ein Konto dient nur dazu, geteilte Daten mit anderen zu synchronisieren — alles andere bleibt in diesem Browser. Keine E-Mail, kein Name: ein Benutzername und ein Passwort."
  | RecoveryCodeTitle => "Wiederherstellungscode"
  | RecoveryCodeInfo => "Schreiben Sie ihn auf und bewahren Sie ihn sicher auf. Wenn Sie Ihr Passwort vergessen, ist dieser Code der einzige Weg zurück zu Ihren geteilten Daten: der Server hält sie verschlüsselt und kann nicht zurücksetzen, was er nicht lesen kann."
  | RecoveryCodeDone => "Ich habe ihn gesichert"
  | AccountFailed => "Das hat nicht funktioniert. Prüfen Sie Benutzername und Passwort."
  | UsernameTaken => "Dieser Benutzername ist bereits vergeben."
  | SignedInAs => "Angemeldet als"
  | SyncPanel => "Synchronisierung"
  | SyncNeedsAccount => "Melden Sie sich an, um die Daten dieser App mit anderen zu synchronisieren."
  | SyncThisApp => "Daten dieser App synchronisieren"
  | SyncOnInfo => "Die Daten dieser App sind geteilt: sie synchronisieren sich, verschlüsselt, mit allen Eingeladenen."
  | InviteAction => "Einladen"
  | InviteLinkInfo => "Wer diesen Link öffnet, tritt mit der genannten Rolle bei. Er funktioniert nur einmal."
  | RoleOwner => "Eigentümer"
  | RoleEditor => "Darf bearbeiten"
  | RoleReader => "Nur lesen"
  | MembersHeading => "Mitglieder"
  | RemoveMember => "Entfernen"
  | LeaveSpace => "Raum verlassen"
  | JoinQuestion => "Dieser Link lädt Sie zu einer App mit geteilten Daten ein. Beitreten?"
  | JoinAction => "Beitreten"
  | InviteInvalid => "Diese Einladung ist abgelaufen oder wurde bereits verwendet."
  | SyncOffline => "Synchronisierung pausiert: der Server ist nicht erreichbar."
  | ChatPanel => "Chat"
  | ChatSend => "Senden"
  | ChatPlaceholder => "Nachricht schreiben…"
  | ChatEmpty => "Noch keine Nachrichten."
  | ChatGuest => "Gast"
  | ChatAttach => "Datei anhängen"
  | ChatFileTooBig => "Ein Anhang darf höchstens 700 kB groß sein."
  | OdLoading => "Offene Daten werden geladen…"
  | OdRows => "Zeilen"
  | OdStale => "der Dienst antwortet nicht — die zuletzt empfangenen Daten werden gezeigt"
  | OdUnreachable => "Der Open-Data-Dienst ist nicht erreichbar."
  | OdRefused => "Die Abfrage wurde abgelehnt:"
  | MlEngineNeeded => "Für dieses Modell muss die Rechen-Engine heruntergeladen werden."
  | OdSearchAction => "Suchen"
  | RemoveFilter => "Filter entfernen"
  | ApiRefresh => "Daten aktualisieren"
  | FileTooBig => "Die Datei liegt über der Grenze von {n} kB."
  | RunAction => "Ausführen"
  | PreviousWeek => "Vorige Woche"
  | NextWeek => "Nächste Woche"
  | TodayAction => "Heute"
  | StopAction => "Anhalten"
  | InProgress => "Läuft…"
  | CellBlocked => "Dieser Platz ist nicht verfügbar."
  | PinnedRow => "Fixiert — nicht verschiebbar"
  | PrintAction => "Drucken"
  | PrintEach => "Je eine Seite drucken"
  | AiPanel => "Assistent"
  | AiPlaceholder => "Beschreiben Sie die gewünschte App"
  | AiStop => "Anhalten"
  | AiEmpty => "Fragen Sie nach einer App: Sie wird geschrieben, geprüft und Ihrer Galerie hinzugefügt."
  | AiSettingsAction => "Assistent-Einstellungen"
  | AiClear => "Unterhaltung löschen"
  | AiKeyLabel => "API-Schlüssel"
  | AiKeyHelp => "Bleibt in diesem Browser und geht nur an den gewählten Anbieter."
  | AiModelLabel => "Modell"
  | AiEndpointLabel => "Endpunkt"
  | AiSaveSettings => "Speichern"
  | AiNeedsKey => "Geben Sie Ihren API-Schlüssel ein, oder wählen Sie ein Modell auf diesem Rechner."
  | AiNeedsHttps => "Der Endpunkt muss https sein, oder http auf localhost."
  | AiThinking => "Denkt nach…"
  | AiWorking => "Verarbeitung…"
  | AiUsedTool => "Werkzeug benutzt"
  | AiCreated => "App erstellt"
  | AiProposal => "Vorgeschlagene Änderung"
  | AiApply => "Übernehmen"
  | AiDiscard => "Verwerfen"
  | AiStalled => "Der Assistent hat nach zu vielen Schritten aufgehört. Fragen Sie einfacher noch einmal."
  | AiMcpOffline => "Der Dokumentationsserver antwortet nicht, also kann der Assistent die Direktiven weder nachschlagen noch prüfen, was er schreibt. Starten Sie ihn mit: bun run mcp"
  | AiNoModels => "Kein Modell auf diesem Rechner. Installieren Sie eines, zum Beispiel: ollama pull qwen3.5:4b"
  | AiModelNoTools => "kann keine Werkzeuge benutzen"
  | AiFailed => "Das hat nicht funktioniert:"
  | AiNoAnswer => "Das Modell hat ohne Antwort aufgehört. Fragen Sie noch einmal, oder nehmen Sie ein größeres Modell."
  | AiNotConfigured => "Kein Modell eingerichtet: Wählen Sie eines in den Einstellungen des Assistenten. Die App funktioniert auch ohne."
  | AiAsk => "Stellen Sie eine Frage…"
  | AiSend => "Senden"
  | AiConfirm => "Bestätigen"
  | AiIndexing => "Wird indiziert…"
  | WorkflowRunNow => "Jetzt ausführen"
  | WorkflowSteps => "Schritte"
  | WorkflowWaiting => "wartet"
  | WorkflowSkipped => "übersprungen — der Schritt davor kam nicht durch"
  | WorkflowFailed => "nicht durchgelaufen"
  | WorkflowLastRun => "Zuletzt ausgeführt:"
  | WorkflowNextRun => "Nächste:"
  | WorkflowNever => "nie ausgeführt"
  | WorkflowCycle => "Diese Schritte speisen einander im Kreis, also kann keiner zuerst laufen. Geben Sie einem davon eine eigene Sammlung."
  | WorkflowNoSteps => "Dieser Ablauf hat nichts auszuführen: Stellen Sie die Direktiven hinein, die Daten erzeugen — ::od-query, ::sql, ::python, ml-*."
  | WorkflowWhileOpen => "Läuft, solange die App geöffnet ist."
  | WorkflowLooped => "im Kreis"
  | CatalogUnreachable => "Der Katalog hat nicht geantwortet. Prüfen Sie die Verbindung und versuchen Sie es erneut."
  | CatalogMissing => "Der Katalog hat diese App nicht."
  | CatalogueHeading => "Aus dem Katalog"
  | CatalogueLead => "Veröffentlichte Apps, die Sie noch nicht haben. Eine zu öffnen kopiert sie in diesen Browser, wo sie Ihnen gehört."
  | CatalogueAdd => "Hinzufügen"
  | UpdateAvailable => "Aktualisierung verfügbar"
  | UpdateApp => "Aktualisieren"
  | UpdateQuestion => "Die veröffentlichte Fassung übernehmen?"
  | UpdateWarning => "Das Dokument dieser App wird durch das aus dem Katalog ersetzt. Die gespeicherten Daten bleiben unberührt — die Zeilen liegen außerhalb des Dokuments — aber alles, was Sie am Dokument selbst geändert haben, geht verloren."
  | UpdateDone => "Aus dem Katalog aktualisiert."
  | UpdateFailed => "Der Katalog hat nicht geantwortet: die App bleibt unverändert."
  | LegalNotices => "Rechtliche Hinweise"
  }

let spanish = key =>
  switch key {
  | EditorPane => "Editor"
  | PreviewPane => "Vista previa"
  | AppPane => "Aplicación"
  | MarkdownEditor => "Editor Markdown"
  | BlockEditor => "Editor de bloques"
  | PhoneWidth => "Ancho de móvil"
  | FullWidth => "Ancho completo"
  | PaletteLabel => "Paleta"
  | DarkMode => "Modo oscuro"
  | LightMode => "Modo claro"
  | Language => "Idioma"
  | LoadingBlockEditor => "Cargando el editor de bloques…"
  | LinkRemoved => "Enlace eliminado: esquema no permitido"
  | DocumentInfo => "Información del documento"
  | NoDocumentInfo => "Este documento no tiene frontmatter."
  | Directives => "Directivas"
  | NoDirectives => "No hay directivas en este documento."
  | RemoveDirective => "Eliminar directiva"
  | ScrollableTable => "Tabla, desplazable"
  | DataPanel => "Datos"
  | NoCollections => "Esta aplicación aún no tiene datos guardados."
  | BackupAction => "Copia de seguridad"
  | RestoreAction => "Restaurar"
  | DeleteData => "Eliminar todos los datos"
  | BackupFromOtherApp => "Esa copia pertenece a otra aplicación."
  | NoAppId => "Da un appId al documento para guardar datos."
  | Gallery => "Aplicaciones"
  | NewApp => "Nueva aplicación"
  | OpenApp => "Abrir"
  | EditApp => "Editar"
  | DeleteApp => "Eliminar la aplicación"
  | NoApps => "Aún no hay aplicaciones. Crea una para empezar."
  | BackToGallery => "Todas las aplicaciones"
  | AppsHeading => "Tus aplicaciones"
  | Untitled => "Aplicación sin título"
  | SavedJustNow => "Guardado"
  | CopyLink => "Copiar enlace"
  | LinkCopied => "Enlace copiado"
  | ViewApp => "Ver"
  | SearchApps => "Buscar aplicaciones"
  | NoMatches => "Ninguna aplicación coincide con la búsqueda."
  | DeleteAppQuestion => "¿Eliminar esta aplicación?"
  | DeleteAppWarning => "Sus datos guardados se eliminan con ella. No se puede deshacer."
  | CancelAction => "Cancelar"
  | DeleteDataQuestion => "¿Eliminar estos datos?"
  | DeleteDataWarning => "Las filas se quitan de este navegador. No se puede deshacer."
  | DeleteRow => "Eliminar la fila"
  | EditRow => "Editar la fila"
  | DeleteRowQuestion => "¿Eliminar esta fila?"
  | DeleteRowWarning => "La fila se quita de este navegador. No se puede deshacer."
  | ExportApp => "Guardar en un archivo"
  | ImportApp => "Abrir desde un archivo"
  | ImportedAsCopy => "Ya había una aplicación con ese identificador, así que esta se abrió como copia."
  | NotADocument => "Eso no es un documento de ReactiveNET."
  | SearchRows => "Buscar filas"
  | PreviousPage => "Página anterior"
  | NextPage => "Página siguiente"
  | SortedAscending => "Orden ascendente"
  | SortedDescending => "Orden descendente"
  | Pages => "Páginas"
  | FieldRequired => "Obligatorio"
  | FieldNotANumber => "Debe ser un número"
  | FieldNotADate => "Debe ser una fecha"
  | FieldNotATime => "Debe ser una hora"
  | FieldNotAnEmail => "Debe ser una dirección de correo"
  | FieldNotAUrl => "Debe ser una dirección web"
  | FieldBelow => "Debe ser al menos {n}"
  | FieldAbove => "Debe ser como máximo {n}"
  | FieldNotMatching => "No tiene el formato esperado"
  | CheckTheForm => "Revise los campos señalados"
  | ExportCollection => "Guardar como CSV"
  | ImportCollection => "Añadir filas desde un archivo"
  | ImportIntoCollection => "Importar en"
  | CollectionName => "nombre de la colección"
  | NotACollectionFile => "Ese archivo no tiene columnas legibles."
  | RowsImported => "{n} filas añadidas"
  | AllValues => "Todos"
  | PreviousMonth => "Mes anterior"
  | NextMonth => "Mes siguiente"
  | DuplicateApp => "Duplicar"
  | ClassStructure => "Estructura"
  | ClassData => "Datos"
  | ClassAi => "Asistente"
  | ClassViews => "Vistas"
  | ClassValues => "Valores"
  | ClassStatus => "Estado"
  | ClassControls => "Controles"
  | ClassNavigation => "Navegación"
  | ClassLayout => "Diseño"
  | ClassOverlays => "Superposiciones"
  | ClassColour => "Color"
  | ClassTableParts => "Partes de tabla"
  | ShareApp => "Compartir esta app"
  | ShareLinkLabel => "Quien tenga el enlace recibe una copia de la app — no de sus datos."
  | ShareInvitation => "abrir esta app"
  | BrokenShareLink => "Ese enlace está incompleto: pídelo de nuevo."
  | ShareTooBig => "Esta app es demasiado grande para un enlace. Guárdala en un archivo."
  | ShareByEmail => "Correo"
  | ShareNative => "Compartir…"
  | CopyAction => "Copiar"
  | ShowCode => "Mostrar el código"
  | HideCode => "Ocultar el código"
  | PythonRunning => "Ejecutando…"
  | PythonLoading => "Iniciando Python…"
  | ShareShortInfo => "Cifrado — el servidor no puede leerlo. Caduca a los 120 días de la última apertura."
  | ShareLongInfo => "Enlace completo, sin servidor"
  | ShareExpired => "Este enlace ha caducado o fue eliminado: pídelo de nuevo."
  | AccountLabel => "Cuenta"
  | SignInAction => "Iniciar sesión"
  | SignOutAction => "Cerrar sesión"
  | CreateAccountAction => "Crear cuenta"
  | UsernameLabel => "Nombre de usuario"
  | PasswordLabel => "Contraseña"
  | UsernameHint => "De 3 a 32 caracteres: minúsculas, cifras, guiones."
  | PasswordHint => "Al menos 8 caracteres."
  | AccountIntro => "Una cuenta sirve solo para sincronizar los datos compartidos con otras personas — todo lo demás permanece en este navegador. Sin correo, sin nombre: un nombre de usuario y una contraseña."
  | RecoveryCodeTitle => "Código de recuperación"
  | RecoveryCodeInfo => "Anótalo y guárdalo en un lugar seguro. Si olvidas la contraseña, este código es la única vuelta a tus datos compartidos: el servidor los guarda cifrados y no puede restablecer lo que no puede leer."
  | RecoveryCodeDone => "Lo he guardado"
  | AccountFailed => "No ha funcionado. Comprueba el nombre de usuario y la contraseña."
  | UsernameTaken => "Ese nombre de usuario ya está en uso."
  | SignedInAs => "Conectado como"
  | SyncPanel => "Sincronización"
  | SyncNeedsAccount => "Inicia sesión para sincronizar los datos de esta app con otras personas."
  | SyncThisApp => "Sincronizar los datos de esta app"
  | SyncOnInfo => "Los datos de esta app están compartidos: se sincronizan, cifrados, con todas las personas invitadas."
  | InviteAction => "Invitar"
  | InviteLinkInfo => "Quien abre este enlace entra con el rol que indica. Funciona una sola vez."
  | RoleOwner => "Propietario"
  | RoleEditor => "Puede editar"
  | RoleReader => "Solo lectura"
  | MembersHeading => "Miembros"
  | RemoveMember => "Quitar"
  | LeaveSpace => "Salir del espacio"
  | JoinQuestion => "Este enlace te invita a una app con datos compartidos. ¿Entrar?"
  | JoinAction => "Entrar"
  | InviteInvalid => "Esta invitación ha caducado o ya se ha usado."
  | SyncOffline => "Sincronización en pausa: el servidor no responde."
  | ChatPanel => "Chat"
  | ChatSend => "Enviar"
  | ChatPlaceholder => "Escribe un mensaje…"
  | ChatEmpty => "Aún no hay mensajes."
  | ChatGuest => "Invitado"
  | ChatAttach => "Adjuntar un archivo"
  | ChatFileTooBig => "Un adjunto puede pesar como máximo 700 kB."
  | OdLoading => "Cargando datos abiertos…"
  | OdRows => "filas"
  | OdStale => "el servicio no responde — se muestran los últimos datos recibidos"
  | OdUnreachable => "El servicio de datos abiertos no responde."
  | OdRefused => "La consulta fue rechazada:"
  | MlEngineNeeded => "Para este modelo hay que descargar el motor de cálculo."
  | OdSearchAction => "Buscar"
  | RemoveFilter => "Quitar el filtro"
  | ApiRefresh => "Actualizar los datos"
  | FileTooBig => "El archivo supera el límite de {n} kB."
  | RunAction => "Ejecutar"
  | PreviousWeek => "Semana anterior"
  | NextWeek => "Semana siguiente"
  | TodayAction => "Hoy"
  | StopAction => "Detener"
  | InProgress => "En curso…"
  | CellBlocked => "Esta franja no está disponible."
  | PinnedRow => "Fijado: no se puede mover"
  | PrintAction => "Imprimir"
  | PrintEach => "Imprimir una página por fila"
  | AiPanel => "Asistente"
  | AiPlaceholder => "Describe la aplicación que quieres"
  | AiStop => "Detener"
  | AiEmpty => "Pide una aplicación: se escribe, se comprueba y se añade a tu galería."
  | AiSettingsAction => "Ajustes del asistente"
  | AiClear => "Borrar la conversación"
  | AiKeyLabel => "Clave API"
  | AiKeyHelp => "Se queda en este navegador y solo se envía al proveedor que elijas."
  | AiModelLabel => "Modelo"
  | AiEndpointLabel => "Dirección del servicio"
  | AiSaveSettings => "Guardar"
  | AiNeedsKey => "Introduce tu clave API, o elige un modelo instalado en este ordenador."
  | AiNeedsHttps => "La dirección tiene que ser https, o http en localhost."
  | AiThinking => "Pensando…"
  | AiWorking => "Procesando…"
  | AiUsedTool => "Herramienta usada"
  | AiCreated => "Aplicación creada"
  | AiProposal => "Cambio propuesto"
  | AiApply => "Aplicar"
  | AiDiscard => "Descartar"
  | AiStalled => "El asistente se detuvo tras demasiados pasos. Vuelve a pedirlo más sencillo."
  | AiMcpOffline => "El servidor de documentación no responde, así que el asistente no puede consultar las directivas ni comprobar lo que escribe. Arráncalo con: bun run mcp"
  | AiNoModels => "No hay ningún modelo en este ordenador. Instala uno, por ejemplo: ollama pull qwen3.5:4b"
  | AiModelNoTools => "no sabe usar herramientas"
  | AiFailed => "No ha funcionado:"
  | AiNoAnswer => "El modelo terminó sin responder. Vuelve a preguntar, o prueba un modelo más grande."
  | AiNotConfigured => "Ningún modelo configurado: elige uno en los ajustes del asistente. La aplicación sigue funcionando sin él."
  | AiAsk => "Pregunta algo…"
  | AiSend => "Enviar"
  | AiConfirm => "Confirmar"
  | AiIndexing => "Indexando…"
  | WorkflowRunNow => "Ejecutar ahora"
  | WorkflowSteps => "Pasos"
  | WorkflowWaiting => "en espera"
  | WorkflowSkipped => "omitido — el paso anterior no terminó"
  | WorkflowFailed => "no terminó"
  | WorkflowLastRun => "Última ejecución:"
  | WorkflowNextRun => "Siguiente:"
  | WorkflowNever => "nunca ejecutado"
  | WorkflowCycle => "Estos pasos se alimentan en círculo, así que ninguno puede ir primero. Dé a uno de ellos una colección propia."
  | WorkflowNoSteps => "Este flujo no tiene nada que ejecutar: ponga dentro las directivas que producen datos — ::od-query, ::sql, ::python, ml-*."
  | WorkflowWhileOpen => "Se ejecuta mientras la aplicación está abierta."
  | WorkflowLooped => "en círculo"
  | CatalogUnreachable => "El catálogo no respondió. Comprueba la conexión y vuelve a intentarlo."
  | CatalogMissing => "El catálogo no tiene esa aplicación."
  | CatalogueHeading => "Del catálogo"
  | CatalogueLead => "Aplicaciones publicadas que aún no tienes. Al abrir una se copia en este navegador, donde pasa a ser tuya."
  | CatalogueAdd => "Añadirla"
  | UpdateAvailable => "Actualización disponible"
  | UpdateApp => "Actualizar"
  | UpdateQuestion => "¿Tomar la versión publicada?"
  | UpdateWarning => "El documento de esta aplicación se sustituye por el que publica el catálogo. Sus datos guardados no se tocan — las filas viven fuera del documento — pero se pierde lo que hayas cambiado en el documento mismo."
  | UpdateDone => "Actualizada desde el catálogo."
  | UpdateFailed => "El catálogo no ha respondido: la aplicación no ha cambiado."
  | LegalNotices => "Avisos legales"
  }

let portuguese = key =>
  switch key {
  | EditorPane => "Editor"
  | PreviewPane => "Pré-visualização"
  | AppPane => "Aplicação"
  | MarkdownEditor => "Editor Markdown"
  | BlockEditor => "Editor de blocos"
  | PhoneWidth => "Largura de telemóvel"
  | FullWidth => "Largura total"
  | PaletteLabel => "Paleta"
  | DarkMode => "Modo escuro"
  | LightMode => "Modo claro"
  | Language => "Idioma"
  | LoadingBlockEditor => "A carregar o editor de blocos…"
  | LinkRemoved => "Ligação removida: esquema não permitido"
  | DocumentInfo => "Informação do documento"
  | NoDocumentInfo => "Este documento não tem frontmatter."
  | Directives => "Diretivas"
  | NoDirectives => "Nenhuma diretiva neste documento."
  | RemoveDirective => "Remover diretiva"
  | ScrollableTable => "Tabela, deslocável"
  | DataPanel => "Dados"
  | NoCollections => "Esta aplicação ainda não tem dados guardados."
  | BackupAction => "Cópia de segurança"
  | RestoreAction => "Restaurar"
  | DeleteData => "Eliminar todos os dados"
  | BackupFromOtherApp => "Essa cópia pertence a outra aplicação."
  | NoAppId => "Dê um appId ao documento para guardar dados."
  | Gallery => "Aplicações"
  | NewApp => "Nova aplicação"
  | OpenApp => "Abrir"
  | EditApp => "Editar"
  | DeleteApp => "Eliminar a aplicação"
  | NoApps => "Ainda não há aplicações. Crie uma para começar."
  | BackToGallery => "Todas as aplicações"
  | AppsHeading => "As suas aplicações"
  | Untitled => "Aplicação sem título"
  | SavedJustNow => "Guardado"
  | CopyLink => "Copiar ligação"
  | LinkCopied => "Ligação copiada"
  | ViewApp => "Ver"
  | SearchApps => "Procurar aplicações"
  | NoMatches => "Nenhuma aplicação corresponde à procura."
  | DeleteAppQuestion => "Eliminar esta aplicação?"
  | DeleteAppWarning => "Os dados guardados são eliminados com ela. Não é possível anular."
  | CancelAction => "Cancelar"
  | DeleteDataQuestion => "Eliminar estes dados?"
  | DeleteDataWarning => "As linhas são removidas deste navegador. Não é possível anular."
  | DeleteRow => "Eliminar a linha"
  | EditRow => "Editar a linha"
  | DeleteRowQuestion => "Eliminar esta linha?"
  | DeleteRowWarning => "A linha é removida deste navegador. Não é possível anular."
  | ExportApp => "Guardar num ficheiro"
  | ImportApp => "Abrir a partir de um ficheiro"
  | ImportedAsCopy => "Já existia uma aplicação com esse identificador, por isso esta foi aberta como cópia."
  | NotADocument => "Isto não é um documento ReactiveNET."
  | SearchRows => "Procurar linhas"
  | PreviousPage => "Página anterior"
  | NextPage => "Página seguinte"
  | SortedAscending => "Ordem crescente"
  | SortedDescending => "Ordem decrescente"
  | Pages => "Páginas"
  | FieldRequired => "Obrigatório"
  | FieldNotANumber => "Tem de ser um número"
  | FieldNotADate => "Tem de ser uma data"
  | FieldNotATime => "Tem de ser uma hora"
  | FieldNotAnEmail => "Tem de ser um endereço de e-mail"
  | FieldNotAUrl => "Tem de ser um endereço web"
  | FieldBelow => "Tem de ser pelo menos {n}"
  | FieldAbove => "Tem de ser no máximo {n}"
  | FieldNotMatching => "Não tem o formato esperado"
  | CheckTheForm => "Verifique os campos assinalados"
  | ExportCollection => "Guardar como CSV"
  | ImportCollection => "Adicionar linhas a partir de um ficheiro"
  | ImportIntoCollection => "Importar para"
  | CollectionName => "nome da coleção"
  | NotACollectionFile => "Esse ficheiro não tem colunas legíveis."
  | RowsImported => "{n} linhas adicionadas"
  | AllValues => "Todos"
  | PreviousMonth => "Mês anterior"
  | NextMonth => "Mês seguinte"
  | DuplicateApp => "Duplicar"
  | ClassStructure => "Estrutura"
  | ClassData => "Dados"
  | ClassAi => "Assistente"
  | ClassViews => "Vistas"
  | ClassValues => "Valores"
  | ClassStatus => "Estado"
  | ClassControls => "Controlos"
  | ClassNavigation => "Navegação"
  | ClassLayout => "Disposição"
  | ClassOverlays => "Sobreposições"
  | ClassColour => "Cor"
  | ClassTableParts => "Partes de tabela"
  | ShareApp => "Partilhar esta app"
  | ShareLinkLabel => "Quem tiver o link recebe uma cópia da app — não dos seus dados."
  | ShareInvitation => "abrir esta app"
  | BrokenShareLink => "Esse link está incompleto: peça-o novamente."
  | ShareTooBig => "Esta app é demasiado grande para um link. Guarde-a num ficheiro."
  | ShareByEmail => "E-mail"
  | ShareNative => "Partilhar…"
  | CopyAction => "Copiar"
  | ShowCode => "Mostrar o código"
  | HideCode => "Ocultar o código"
  | PythonRunning => "A executar…"
  | PythonLoading => "A iniciar o Python…"
  | ShareShortInfo => "Cifrado — o servidor não consegue lê-lo. Expira 120 dias após a última abertura."
  | ShareLongInfo => "Link completo, sem servidor"
  | ShareExpired => "Este link expirou ou foi removido: peça-o novamente."
  | AccountLabel => "Conta"
  | SignInAction => "Iniciar sessão"
  | SignOutAction => "Terminar sessão"
  | CreateAccountAction => "Criar conta"
  | UsernameLabel => "Nome de utilizador"
  | PasswordLabel => "Palavra-passe"
  | UsernameHint => "De 3 a 32 caracteres: minúsculas, algarismos, hífenes."
  | PasswordHint => "Pelo menos 8 caracteres."
  | AccountIntro => "Uma conta serve apenas para sincronizar os dados partilhados com outras pessoas — tudo o resto fica neste navegador. Sem e-mail, sem nome: um nome de utilizador e uma palavra-passe."
  | RecoveryCodeTitle => "Código de recuperação"
  | RecoveryCodeInfo => "Anote-o e guarde-o num lugar seguro. Se esquecer a palavra-passe, este código é o único regresso aos seus dados partilhados: o servidor guarda-os cifrados e não pode repor o que não pode ler."
  | RecoveryCodeDone => "Guardei-o"
  | AccountFailed => "Não funcionou. Verifique o nome de utilizador e a palavra-passe."
  | UsernameTaken => "Esse nome de utilizador já está em uso."
  | SignedInAs => "Ligado como"
  | SyncPanel => "Sincronização"
  | SyncNeedsAccount => "Inicie sessão para sincronizar os dados desta app com outras pessoas."
  | SyncThisApp => "Sincronizar os dados desta app"
  | SyncOnInfo => "Os dados desta app estão partilhados: sincronizam-se, cifrados, com todas as pessoas convidadas."
  | InviteAction => "Convidar"
  | InviteLinkInfo => "Quem abre esta ligação entra com o papel que ela indica. Funciona uma única vez."
  | RoleOwner => "Proprietário"
  | RoleEditor => "Pode editar"
  | RoleReader => "Só leitura"
  | MembersHeading => "Membros"
  | RemoveMember => "Remover"
  | LeaveSpace => "Sair do espaço"
  | JoinQuestion => "Esta ligação convida-o para uma app com dados partilhados. Entrar?"
  | JoinAction => "Entrar"
  | InviteInvalid => "Este convite expirou ou já foi usado."
  | SyncOffline => "Sincronização em pausa: o servidor não está acessível."
  | ChatPanel => "Conversa"
  | ChatSend => "Enviar"
  | ChatPlaceholder => "Escreva uma mensagem…"
  | ChatEmpty => "Ainda não há mensagens."
  | ChatGuest => "Convidado"
  | ChatAttach => "Anexar um ficheiro"
  | ChatFileTooBig => "Um anexo pode ter no máximo 700 kB."
  | OdLoading => "A carregar dados abertos…"
  | OdRows => "linhas"
  | OdStale => "o serviço não responde — mostram-se os últimos dados recebidos"
  | OdUnreachable => "O serviço de dados abertos não está acessível."
  | OdRefused => "A consulta foi recusada:"
  | MlEngineNeeded => "Para este modelo é preciso descarregar o motor de cálculo."
  | OdSearchAction => "Pesquisar"
  | RemoveFilter => "Remover o filtro"
  | ApiRefresh => "Atualizar os dados"
  | FileTooBig => "O ficheiro excede o limite de {n} kB."
  | RunAction => "Executar"
  | PreviousWeek => "Semana anterior"
  | NextWeek => "Semana seguinte"
  | TodayAction => "Hoje"
  | StopAction => "Parar"
  | InProgress => "Em curso…"
  | CellBlocked => "Este horário não está disponível."
  | PinnedRow => "Fixado: não pode ser movido"
  | PrintAction => "Imprimir"
  | PrintEach => "Imprimir uma página por linha"
  | AiPanel => "Assistente"
  | AiPlaceholder => "Descreva a aplicação que quer"
  | AiStop => "Parar"
  | AiEmpty => "Peça uma aplicação: é escrita, verificada e acrescentada à sua galeria."
  | AiSettingsAction => "Definições do assistente"
  | AiClear => "Apagar a conversa"
  | AiKeyLabel => "Chave API"
  | AiKeyHelp => "Fica neste navegador e só é enviada ao fornecedor que escolher."
  | AiModelLabel => "Modelo"
  | AiEndpointLabel => "Endereço do serviço"
  | AiSaveSettings => "Guardar"
  | AiNeedsKey => "Introduza a sua chave API, ou escolha um modelo instalado neste computador."
  | AiNeedsHttps => "O endereço tem de ser https, ou http em localhost."
  | AiThinking => "A pensar…"
  | AiWorking => "A processar…"
  | AiUsedTool => "Ferramenta usada"
  | AiCreated => "Aplicação criada"
  | AiProposal => "Alteração proposta"
  | AiApply => "Aplicar"
  | AiDiscard => "Descartar"
  | AiStalled => "O assistente parou depois de demasiados passos. Peça outra vez, de forma mais simples."
  | AiMcpOffline => "O servidor de documentação não responde, por isso o assistente não consegue consultar as diretivas nem verificar o que escreve. Inicie-o com: bun run mcp"
  | AiNoModels => "Nenhum modelo neste computador. Instale um, por exemplo: ollama pull qwen3.5:4b"
  | AiModelNoTools => "não sabe usar ferramentas"
  | AiFailed => "Não resultou:"
  | AiNoAnswer => "O modelo terminou sem responder. Pergunte outra vez, ou experimente um modelo maior."
  | AiNotConfigured => "Nenhum modelo configurado: escolha um nas definições do assistente. A aplicação continua a funcionar sem ele."
  | AiAsk => "Pergunte algo…"
  | AiSend => "Enviar"
  | AiConfirm => "Confirmar"
  | AiIndexing => "A indexar…"
  | WorkflowRunNow => "Executar agora"
  | WorkflowSteps => "Passos"
  | WorkflowWaiting => "à espera"
  | WorkflowSkipped => "ignorado — o passo anterior não terminou"
  | WorkflowFailed => "não terminou"
  | WorkflowLastRun => "Última execução:"
  | WorkflowNextRun => "Seguinte:"
  | WorkflowNever => "nunca executado"
  | WorkflowCycle => "Estes passos alimentam-se em círculo, por isso nenhum pode ir primeiro. Dê a um deles uma coleção própria."
  | WorkflowNoSteps => "Este fluxo não tem nada para executar: coloque lá dentro as diretivas que produzem dados — ::od-query, ::sql, ::python, ml-*."
  | WorkflowWhileOpen => "É executado enquanto a aplicação está aberta."
  | WorkflowLooped => "em círculo"
  | CatalogUnreachable => "O catálogo não respondeu. Verifique a ligação e tente outra vez."
  | CatalogMissing => "O catálogo não tem essa aplicação."
  | CatalogueHeading => "Do catálogo"
  | CatalogueLead => "Aplicações publicadas que ainda não tem. Abrir uma copia-a para este navegador, onde passa a ser sua."
  | CatalogueAdd => "Adicionar"
  | UpdateAvailable => "Atualização disponível"
  | UpdateApp => "Atualizar"
  | UpdateQuestion => "Aceitar a versão publicada?"
  | UpdateWarning => "O documento desta aplicação é substituído pelo que o catálogo publica. Os dados guardados não são tocados — as linhas vivem fora do documento — mas perde-se o que tiver alterado no próprio documento."
  | UpdateDone => "Atualizada a partir do catálogo."
  | UpdateFailed => "O catálogo não respondeu: a aplicação está inalterada."
  | LegalNotices => "Avisos legais"
  }

let chinese = key =>
  switch key {
  | EditorPane => "编辑器"
  | PreviewPane => "预览"
  | AppPane => "应用"
  | MarkdownEditor => "Markdown 编辑器"
  | BlockEditor => "块编辑器"
  | PhoneWidth => "手机宽度"
  | FullWidth => "全宽"
  | PaletteLabel => "配色"
  | DarkMode => "深色模式"
  | LightMode => "浅色模式"
  | Language => "语言"
  | LoadingBlockEditor => "正在加载块编辑器…"
  | LinkRemoved => "链接已移除：不允许该协议"
  | DocumentInfo => "文档信息"
  | NoDocumentInfo => "该文档没有前置元数据。"
  | Directives => "指令"
  | NoDirectives => "该文档中没有指令。"
  | RemoveDirective => "移除指令"
  | ScrollableTable => "表格，可横向滚动"
  | DataPanel => "数据"
  | NoCollections => "此应用尚未存储数据。"
  | BackupAction => "备份"
  | RestoreAction => "恢复"
  | DeleteData => "删除全部数据"
  | BackupFromOtherApp => "该备份属于另一个应用。"
  | NoAppId => "请为文档设置 appId 以存储数据。"
  | Gallery => "应用"
  | NewApp => "新建应用"
  | OpenApp => "打开"
  | EditApp => "编辑"
  | DeleteApp => "删除应用"
  | NoApps => "还没有应用。新建一个开始吧。"
  | BackToGallery => "全部应用"
  | AppsHeading => "你的应用"
  | Untitled => "未命名应用"
  | SavedJustNow => "已保存"
  | CopyLink => "复制链接"
  | LinkCopied => "链接已复制"
  | ViewApp => "查看"
  | SearchApps => "搜索应用"
  | NoMatches => "没有匹配的应用。"
  | DeleteAppQuestion => "删除这个应用？"
  | DeleteAppWarning => "它保存的数据会一并删除，且无法撤销。"
  | CancelAction => "取消"
  | DeleteDataQuestion => "删除这些数据？"
  | DeleteDataWarning => "这些行将从此浏览器中移除，且无法撤销。"
  | DeleteRow => "删除该行"
  | EditRow => "编辑该行"
  | DeleteRowQuestion => "删除这一行？"
  | DeleteRowWarning => "该行将从此浏览器中移除，且无法撤销。"
  | ExportApp => "保存为文件"
  | ImportApp => "从文件打开"
  | ImportedAsCopy => "已有同名标识的应用，因此这个以副本方式打开。"
  | NotADocument => "这不是 ReactiveNET 文档。"
  | SearchRows => "搜索行"
  | PreviousPage => "上一页"
  | NextPage => "下一页"
  | SortedAscending => "升序排列"
  | SortedDescending => "降序排列"
  | Pages => "页面"
  | FieldRequired => "必填"
  | FieldNotANumber => "必须是数字"
  | FieldNotADate => "必须是日期"
  | FieldNotATime => "必须是时间"
  | FieldNotAnEmail => "必须是电子邮件地址"
  | FieldNotAUrl => "必须是网址"
  | FieldBelow => "不能小于 {n}"
  | FieldAbove => "不能大于 {n}"
  | FieldNotMatching => "格式不符"
  | CheckTheForm => "请检查标记的字段"
  | ExportCollection => "另存为 CSV"
  | ImportCollection => "从文件添加行"
  | ImportIntoCollection => "导入到"
  | CollectionName => "集合名称"
  | NotACollectionFile => "该文件没有可读取的列。"
  | RowsImported => "已添加 {n} 行"
  | AllValues => "全部"
  | PreviousMonth => "上个月"
  | NextMonth => "下个月"
  | DuplicateApp => "复制"
  | ClassStructure => "结构"
  | ClassData => "数据"
  | ClassAi => "助手"
  | ClassViews => "视图"
  | ClassValues => "数值"
  | ClassStatus => "状态"
  | ClassControls => "控件"
  | ClassNavigation => "导航"
  | ClassLayout => "布局"
  | ClassOverlays => "浮层"
  | ClassColour => "颜色"
  | ClassTableParts => "表格部件"
  | ShareApp => "分享此应用"
  | ShareLinkLabel => "拿到链接的人会得到应用的副本，但不包括其数据。"
  | ShareInvitation => "打开这个应用"
  | BrokenShareLink => "该链接不完整：请重新索取。"
  | ShareTooBig => "此应用太大，无法用链接发送。请保存为文件。"
  | ShareByEmail => "电子邮件"
  | ShareNative => "分享…"
  | CopyAction => "复制"
  | ShowCode => "显示代码"
  | HideCode => "隐藏代码"
  | PythonRunning => "运行中…"
  | PythonLoading => "正在启动 Python…"
  | ShareShortInfo => "已加密——服务器无法读取。最后一次打开后 120 天过期。"
  | ShareLongInfo => "完整链接，不经过服务器"
  | ShareExpired => "该链接已过期或已被删除：请重新索取。"
  | AccountLabel => "账户"
  | SignInAction => "登录"
  | SignOutAction => "退出登录"
  | CreateAccountAction => "创建账户"
  | UsernameLabel => "用户名"
  | PasswordLabel => "密码"
  | UsernameHint => "3 到 32 个字符：小写字母、数字、连字符。"
  | PasswordHint => "至少 8 个字符。"
  | AccountIntro => "账户仅用于与他人同步共享数据——其余一切都留在此浏览器中。无需邮箱，无需姓名：一个用户名和一个密码。"
  | RecoveryCodeTitle => "恢复码"
  | RecoveryCodeInfo => "请抄下并妥善保存。如果忘记密码，这个恢复码是找回共享数据的唯一途径：服务器只保存加密内容，无法重置它读不到的东西。"
  | RecoveryCodeDone => "我已保存"
  | AccountFailed => "未成功。请检查用户名和密码。"
  | UsernameTaken => "该用户名已被使用。"
  | SignedInAs => "已登录："
  | SyncPanel => "同步"
  | SyncNeedsAccount => "登录后即可与他人同步此应用的数据。"
  | SyncThisApp => "同步此应用的数据"
  | SyncOnInfo => "此应用的数据已共享：与所有受邀者加密同步。"
  | InviteAction => "邀请"
  | InviteLinkInfo => "打开此链接的人将以链接所示角色加入。仅可使用一次。"
  | RoleOwner => "所有者"
  | RoleEditor => "可编辑"
  | RoleReader => "只读"
  | MembersHeading => "成员"
  | RemoveMember => "移除"
  | LeaveSpace => "退出空间"
  | JoinQuestion => "此链接邀请你加入一个含共享数据的应用。加入吗？"
  | JoinAction => "加入"
  | InviteInvalid => "此邀请已过期或已被使用。"
  | SyncOffline => "同步已暂停：无法连接服务器。"
  | ChatPanel => "聊天"
  | ChatSend => "发送"
  | ChatPlaceholder => "输入消息…"
  | ChatEmpty => "还没有消息。"
  | ChatGuest => "访客"
  | ChatAttach => "附加文件"
  | ChatFileTooBig => "附件最大为 700 kB。"
  | OdLoading => "正在加载开放数据…"
  | OdRows => "行"
  | OdStale => "服务无响应——显示最近收到的数据"
  | OdUnreachable => "开放数据服务无法访问。"
  | OdRefused => "查询被拒绝："
  | MlEngineNeeded => "此模型需要先下载计算引擎。"
  | OdSearchAction => "搜索"
  | RemoveFilter => "移除筛选"
  | ApiRefresh => "刷新数据"
  | FileTooBig => "文件超过 {n} kB 的上限。"
  | RunAction => "运行"
  | PreviousWeek => "上一周"
  | NextWeek => "下一周"
  | TodayAction => "今天"
  | StopAction => "停止"
  | InProgress => "进行中…"
  | CellBlocked => "该时段不可用。"
  | PinnedRow => "已固定，无法移动"
  | PrintAction => "打印"
  | PrintEach => "每行打印一页"
  | AiPanel => "助手"
  | AiPlaceholder => "描述你想要的应用"
  | AiStop => "停止"
  | AiEmpty => "说出你要的应用：助手会写好、检查，并加入你的应用库。"
  | AiSettingsAction => "助手设置"
  | AiClear => "清空对话"
  | AiKeyLabel => "API 密钥"
  | AiKeyHelp => "只保存在本浏览器，并且只发送给你选择的服务商。"
  | AiModelLabel => "模型"
  | AiEndpointLabel => "服务地址"
  | AiSaveSettings => "保存"
  | AiNeedsKey => "请输入 API 密钥，或选择本机上的模型。"
  | AiNeedsHttps => "地址必须是 https，或者 localhost 上的 http。"
  | AiThinking => "思考中…"
  | AiWorking => "处理中…"
  | AiUsedTool => "已使用工具"
  | AiCreated => "应用已创建"
  | AiProposal => "建议的修改"
  | AiApply => "应用"
  | AiDiscard => "放弃"
  | AiStalled => "助手在太多步骤后停止了。请换一个更简单的说法再试。"
  | AiMcpOffline => "文档服务器没有响应，助手无法查阅指令，也无法检查自己写的内容。请用 bun run mcp 启动它。"
  | AiNoModels => "本机没有模型。请先安装一个，例如：ollama pull qwen3.5:4b"
  | AiModelNoTools => "不能使用工具"
  | AiFailed => "没有成功："
  | AiNoAnswer => "模型没有给出回答就结束了。请再问一次，或换一个更大的模型。"
  | AiNotConfigured => "尚未配置模型：请在助手设置中选择一个。没有它，应用仍然可以使用。"
  | AiAsk => "提个问题…"
  | AiSend => "发送"
  | AiConfirm => "确认"
  | AiIndexing => "正在建立索引…"
  | WorkflowRunNow => "立即运行"
  | WorkflowSteps => "步骤"
  | WorkflowWaiting => "等待中"
  | WorkflowSkipped => "已跳过 — 上一步未完成"
  | WorkflowFailed => "未完成"
  | WorkflowLastRun => "上次运行："
  | WorkflowNextRun => "下次："
  | WorkflowNever => "尚未运行"
  | WorkflowCycle => "这些步骤互相循环供数，没有一步能先运行。请给其中一步一个自己的集合。"
  | WorkflowNoSteps => "此工作流没有可运行的内容：请把产生数据的指令放进去 — ::od-query、::sql、::python、ml-*。"
  | WorkflowWhileOpen => "仅在应用打开时运行。"
  | WorkflowLooped => "处于循环中"
  | CatalogUnreachable => "目录没有响应。请检查网络后重试。"
  | CatalogMissing => "目录中没有这个应用。"
  | CatalogueHeading => "来自目录"
  | CatalogueLead => "你还没有的已发布应用。打开一个会把它复制到这个浏览器，从此归你所有，可以随意修改。"
  | CatalogueAdd => "添加"
  | UpdateAvailable => "有可用更新"
  | UpdateApp => "更新"
  | UpdateQuestion => "采用已发布的版本？"
  | UpdateWarning => "此应用的文档将被目录中发布的文档替换。已保存的数据不受影响——数据行存放在文档之外——但你对文档本身所做的修改会丢失。"
  | UpdateDone => "已从目录更新。"
  | UpdateFailed => "目录没有响应：应用未改变。"
  | LegalNotices => "法律信息"
  }

let italian = key =>
  switch key {
  | EditorPane => "Editor"
  | PreviewPane => "Anteprima"
  | AppPane => "Applicazione"
  | MarkdownEditor => "Editor Markdown"
  | BlockEditor => "Editor a blocchi"
  | PhoneWidth => "Larghezza telefono"
  | FullWidth => "Larghezza piena"
  | PaletteLabel => "Tavolozza"
  | DarkMode => "Modalità scura"
  | LightMode => "Modalità chiara"
  | Language => "Lingua"
  | LoadingBlockEditor => "Caricamento dell'editor a blocchi…"
  | LinkRemoved => "Link rimosso: schema non consentito"
  | DocumentInfo => "Informazioni documento"
  | NoDocumentInfo => "Questo documento non ha frontmatter."
  | Directives => "Direttive"
  | NoDirectives => "Nessuna direttiva in questo documento."
  | RemoveDirective => "Rimuovi direttiva"
  | ScrollableTable => "Tabella, scorrevole"
  | DataPanel => "Dati"
  | NoCollections => "Questa app non ha ancora dati salvati."
  | BackupAction => "Backup"
  | RestoreAction => "Ripristina"
  | DeleteData => "Elimina tutti i dati"
  | BackupFromOtherApp => "Quel backup appartiene a un'altra app."
  | NoAppId => "Assegna un appId al documento per salvare dati."
  | Gallery => "App"
  | NewApp => "Nuova app"
  | OpenApp => "Apri"
  | EditApp => "Modifica"
  | DeleteApp => "Elimina l'app"
  | NoApps => "Ancora nessuna app. Creane una per iniziare."
  | BackToGallery => "Tutte le app"
  | AppsHeading => "Le tue app"
  | Untitled => "App senza titolo"
  | SavedJustNow => "Salvato"
  | CopyLink => "Copia il link"
  | LinkCopied => "Link copiato"
  | ViewApp => "Visualizza"
  | SearchApps => "Cerca le app"
  | NoMatches => "Nessuna app corrisponde alla ricerca."
  | DeleteAppQuestion => "Eliminare questa app?"
  | DeleteAppWarning => "I dati salvati vengono eliminati con essa. L'operazione è irreversibile."
  | CancelAction => "Annulla"
  | DeleteDataQuestion => "Eliminare questi dati?"
  | DeleteDataWarning => "Le righe vengono rimosse da questo browser. L'operazione è irreversibile."
  | DeleteRow => "Elimina la riga"
  | EditRow => "Modifica la riga"
  | DeleteRowQuestion => "Eliminare questa riga?"
  | DeleteRowWarning => "La riga viene rimossa da questo browser. L'operazione è irreversibile."
  | ExportApp => "Salva in un file"
  | ImportApp => "Apri da un file"
  | ImportedAsCopy => "Un'app con quell'identificatore c'era già, quindi questa è stata aperta come copia."
  | NotADocument => "Questo non è un documento ReactiveNET."
  | SearchRows => "Cerca nelle righe"
  | PreviousPage => "Pagina precedente"
  | NextPage => "Pagina successiva"
  | SortedAscending => "Ordine crescente"
  | SortedDescending => "Ordine decrescente"
  | Pages => "Pagine"
  | FieldRequired => "Obbligatorio"
  | FieldNotANumber => "Deve essere un numero"
  | FieldNotADate => "Deve essere una data"
  | FieldNotATime => "Deve essere un orario"
  | FieldNotAnEmail => "Deve essere un indirizzo e-mail"
  | FieldNotAUrl => "Deve essere un indirizzo web"
  | FieldBelow => "Deve essere almeno {n}"
  | FieldAbove => "Deve essere al massimo {n}"
  | FieldNotMatching => "Formato non previsto"
  | CheckTheForm => "Controlla i campi segnalati"
  | ExportCollection => "Salva in CSV"
  | ImportCollection => "Aggiungi righe da un file"
  | ImportIntoCollection => "Importa in"
  | CollectionName => "nome della collezione"
  | NotACollectionFile => "Quel file non ha colonne leggibili."
  | RowsImported => "{n} righe aggiunte"
  | AllValues => "Tutti"
  | PreviousMonth => "Mese precedente"
  | NextMonth => "Mese successivo"
  | DuplicateApp => "Duplica"
  | ClassStructure => "Struttura"
  | ClassData => "Dati"
  | ClassAi => "Assistente"
  | ClassViews => "Viste"
  | ClassValues => "Valori"
  | ClassStatus => "Stato"
  | ClassControls => "Controlli"
  | ClassNavigation => "Navigazione"
  | ClassLayout => "Impaginazione"
  | ClassOverlays => "Sovrapposizioni"
  | ClassColour => "Colore"
  | ClassTableParts => "Parti di tabella"
  | ShareApp => "Condividi questa app"
  | ShareLinkLabel => "Chi ha il link riceve una copia dell'app — non dei suoi dati."
  | ShareInvitation => "apri questa app"
  | BrokenShareLink => "Quel link è incompleto: fattelo rimandare."
  | ShareTooBig => "Questa app è troppo grande per un link. Salvala in un file."
  | ShareByEmail => "E-mail"
  | ShareNative => "Condividi…"
  | CopyAction => "Copia"
  | ShowCode => "Mostra il codice"
  | HideCode => "Nascondi il codice"
  | PythonRunning => "In esecuzione…"
  | PythonLoading => "Avvio di Python…"
  | ShareShortInfo => "Cifrato — il server non può leggerlo. Scade 120 giorni dopo l'ultima apertura."
  | ShareLongInfo => "Link completo, senza server"
  | ShareExpired => "Questo link è scaduto o è stato rimosso: fattelo rimandare."
  | AccountLabel => "Account"
  | SignInAction => "Accedi"
  | SignOutAction => "Esci"
  | CreateAccountAction => "Crea account"
  | UsernameLabel => "Nome utente"
  | PasswordLabel => "Password"
  | UsernameHint => "Da 3 a 32 caratteri: minuscole, cifre, trattini."
  | PasswordHint => "Almeno 8 caratteri."
  | AccountIntro => "Un account serve solo a sincronizzare i dati condivisi con altre persone — tutto il resto resta in questo browser. Niente email, niente nome: un nome utente e una password."
  | RecoveryCodeTitle => "Codice di recupero"
  | RecoveryCodeInfo => "Scrivilo e conservalo in un posto sicuro. Se dimentichi la password, questo codice è l'unica via di ritorno ai tuoi dati condivisi: il server li custodisce cifrati e non può reimpostare ciò che non può leggere."
  | RecoveryCodeDone => "L'ho salvato"
  | AccountFailed => "Non ha funzionato. Controlla nome utente e password."
  | UsernameTaken => "Questo nome utente è già in uso."
  | SignedInAs => "Connesso come"
  | SyncPanel => "Sincronizzazione"
  | SyncNeedsAccount => "Accedi per sincronizzare i dati di questa app con altre persone."
  | SyncThisApp => "Sincronizza i dati di questa app"
  | SyncOnInfo => "I dati di questa app sono condivisi: si sincronizzano, cifrati, con tutte le persone invitate."
  | InviteAction => "Invita"
  | InviteLinkInfo => "Chi apre questo link entra con il ruolo che indica. Funziona una volta sola."
  | RoleOwner => "Proprietario"
  | RoleEditor => "Può modificare"
  | RoleReader => "Sola lettura"
  | MembersHeading => "Membri"
  | RemoveMember => "Rimuovi"
  | LeaveSpace => "Esci dallo spazio"
  | JoinQuestion => "Questo link ti invita a un'app con dati condivisi. Entrare?"
  | JoinAction => "Entra"
  | InviteInvalid => "Questo invito è scaduto o è già stato usato."
  | SyncOffline => "Sincronizzazione in pausa: il server non è raggiungibile."
  | ChatPanel => "Chat"
  | ChatSend => "Invia"
  | ChatPlaceholder => "Scrivi un messaggio…"
  | ChatEmpty => "Ancora nessun messaggio."
  | ChatGuest => "Ospite"
  | ChatAttach => "Allega un file"
  | ChatFileTooBig => "Un allegato può pesare al massimo 700 kB."
  | OdLoading => "Caricamento dei dati aperti…"
  | OdRows => "righe"
  | OdStale => "il servizio non risponde — si mostrano gli ultimi dati ricevuti"
  | OdUnreachable => "Il servizio dati aperti non è raggiungibile."
  | OdRefused => "La query è stata rifiutata:"
  | MlEngineNeeded => "Per questo modello va scaricato il motore di calcolo."
  | OdSearchAction => "Cerca"
  | RemoveFilter => "Togli il filtro"
  | ApiRefresh => "Aggiorna i dati"
  | FileTooBig => "Il file supera il limite di {n} kB."
  | RunAction => "Esegui"
  | PreviousWeek => "Settimana precedente"
  | NextWeek => "Settimana successiva"
  | TodayAction => "Oggi"
  | StopAction => "Interrompi"
  | InProgress => "In corso…"
  | CellBlocked => "Questa casella non è disponibile."
  | PinnedRow => "Fissata: non si può spostare"
  | PrintAction => "Stampa"
  | PrintEach => "Stampa una pagina per riga"
  | AiPanel => "Assistente"
  | AiPlaceholder => "Descrivi l'app che vuoi"
  | AiStop => "Ferma"
  | AiEmpty => "Chiedi un'app: viene scritta, controllata e aggiunta alla tua galleria."
  | AiSettingsAction => "Impostazioni dell'assistente"
  | AiClear => "Cancella la conversazione"
  | AiKeyLabel => "Chiave API"
  | AiKeyHelp => "Resta in questo browser, e viene inviata solo al fornitore che scegli."
  | AiModelLabel => "Modello"
  | AiEndpointLabel => "Indirizzo del servizio"
  | AiSaveSettings => "Salva"
  | AiNeedsKey => "Inserisci la tua chiave API, oppure scegli un modello installato su questo computer."
  | AiNeedsHttps => "L'indirizzo deve essere https, oppure http su localhost."
  | AiThinking => "Sto pensando…"
  | AiWorking => "In elaborazione…"
  | AiUsedTool => "Strumento usato"
  | AiCreated => "App creata"
  | AiProposal => "Modifica proposta"
  | AiApply => "Applica"
  | AiDiscard => "Scarta"
  | AiStalled => "L'assistente si è fermato dopo troppi passaggi. Richiedilo in modo più semplice."
  | AiMcpOffline => "Il server della documentazione non risponde, quindi l'assistente non può consultare le direttive né controllare quello che scrive. Avvialo con: bun run mcp"
  | AiNoModels => "Nessun modello su questo computer. Installane uno, per esempio: ollama pull qwen3.5:4b"
  | AiModelNoTools => "non sa usare gli strumenti"
  | AiFailed => "Non ha funzionato:"
  | AiNoAnswer => "Il modello ha finito senza rispondere. Richiedilo, oppure prova un modello più grande."
  | AiNotConfigured => "Nessun modello configurato: aprine le impostazioni dell'assistente e scegline uno. Senza, l'app continua a funzionare."
  | AiAsk => "Chiedi qualcosa…"
  | AiSend => "Invia"
  | AiConfirm => "Conferma"
  | AiIndexing => "Sto indicizzando…"
  | WorkflowRunNow => "Esegui ora"
  | WorkflowSteps => "Passi"
  | WorkflowWaiting => "in attesa"
  | WorkflowSkipped => "saltato — il passo prima non è riuscito"
  | WorkflowFailed => "non riuscito"
  | WorkflowLastRun => "Ultima esecuzione:"
  | WorkflowNextRun => "Prossima:"
  | WorkflowNever => "mai eseguito"
  | WorkflowCycle => "Questi passi si alimentano in cerchio, quindi nessuno può partire per primo. Dia a uno di loro una collection propria."
  | WorkflowNoSteps => "Questo workflow non ha nulla da eseguire: metta dentro le direttive che producono dati — ::od-query, ::sql, ::python, ml-*."
  | WorkflowWhileOpen => "Si aggiorna mentre l'app è aperta."
  | WorkflowLooped => "in cerchio"
  | CatalogUnreachable => "Il catalogo non ha risposto. Controlla la connessione e riprova."
  | CatalogMissing => "Il catalogo non ha quell'app."
  | CatalogueHeading => "Dal catalogo"
  | CatalogueLead => "App pubblicate che non hai ancora. Aprirne una la copia in questo browser, dove diventa tua da cambiare."
  | CatalogueAdd => "Aggiungila"
  | UpdateAvailable => "Aggiornamento disponibile"
  | UpdateApp => "Aggiorna"
  | UpdateQuestion => "Prendi la versione pubblicata?"
  | UpdateWarning => "Il documento di questa app viene sostituito con quello pubblicato nel catalogo. I dati salvati non si toccano — le righe stanno fuori dal documento — ma quello che hai cambiato nel documento stesso si perde."
  | UpdateDone => "Aggiornata dal catalogo."
  | UpdateFailed => "Il catalogo non ha risposto: l'app è rimasta com'era."
  | LegalNotices => "Note legali"
  }

let translate = (locale, key) =>
  switch locale {
  | Locale.En => english(key)
  | Locale.Fr => french(key)
  | Locale.De => german(key)
  | Locale.Es => spanish(key)
  | Locale.Pt => portuguese(key)
  | Locale.Zh => chinese(key)
  | Locale.It => italian(key)
  }

// Every key, for tests that need to sweep the catalogue. Kept next to the type so
// the two are edited together.
let allKeys = [
  EditorPane,
  PreviewPane,
  AppPane,
  MarkdownEditor,
  BlockEditor,
  PhoneWidth,
  FullWidth,
  PaletteLabel,
  DarkMode,
  LightMode,
  Language,
  LoadingBlockEditor,
  LinkRemoved,
  DocumentInfo,
  NoDocumentInfo,
  Directives,
  NoDirectives,
  RemoveDirective,
  ScrollableTable,
  DataPanel,
  NoCollections,
  ImportIntoCollection,
  CollectionName,
  BackupAction,
  RestoreAction,
  DeleteData,
  BackupFromOtherApp,
  NoAppId,
  Gallery,
  NewApp,
  OpenApp,
  EditApp,
  DeleteApp,
  NoApps,
  BackToGallery,
  AppsHeading,
  Untitled,
  SavedJustNow,
  CopyLink,
  LinkCopied,
  ViewApp,
  SearchApps,
  NoMatches,
  DeleteAppQuestion,
  DeleteAppWarning,
  CancelAction,
  DeleteDataQuestion,
  DeleteDataWarning,
  DeleteRow,
  EditRow,
  DeleteRowQuestion,
  DeleteRowWarning,
  Pages,
  ExportApp,
  ImportApp,
  ImportedAsCopy,
  NotADocument,
  SearchRows,
  PreviousPage,
  NextPage,
  SortedAscending,
  SortedDescending,
  AccountLabel,
  SignInAction,
  SignOutAction,
  CreateAccountAction,
  UsernameLabel,
  PasswordLabel,
  UsernameHint,
  PasswordHint,
  AccountIntro,
  RecoveryCodeTitle,
  RecoveryCodeInfo,
  RecoveryCodeDone,
  AccountFailed,
  UsernameTaken,
  SignedInAs,
  SyncPanel,
  SyncNeedsAccount,
  SyncThisApp,
  SyncOnInfo,
  InviteAction,
  InviteLinkInfo,
  RoleOwner,
  RoleEditor,
  RoleReader,
  MembersHeading,
  RemoveMember,
  LeaveSpace,
  JoinQuestion,
  JoinAction,
  InviteInvalid,
  SyncOffline,
  ChatPanel,
  ChatSend,
  ChatPlaceholder,
  ChatEmpty,
  ChatGuest,
  ChatAttach,
  ChatFileTooBig,
  OdLoading,
  OdRows,
  OdStale,
  OdUnreachable,
  OdRefused,
  MlEngineNeeded,
  OdSearchAction,
  RemoveFilter,
  ApiRefresh,
  FileTooBig,
  RunAction,
  PreviousWeek,
  NextWeek,
  TodayAction,
  StopAction,
  InProgress,
  CellBlocked,
  PinnedRow,
  PrintAction,
  PrintEach,
  AiPanel,
  AiPlaceholder,
  AiStop,
  AiEmpty,
  AiSettingsAction,
  AiClear,
  AiKeyLabel,
  AiKeyHelp,
  AiModelLabel,
  AiEndpointLabel,
  AiSaveSettings,
  AiNeedsKey,
  AiNeedsHttps,
  AiThinking,
  AiWorking,
  AiUsedTool,
  AiCreated,
  AiProposal,
  AiApply,
  AiDiscard,
  AiStalled,
  AiMcpOffline,
  AiNoModels,
  AiModelNoTools,
  AiFailed,
  AiNoAnswer,
  AiNotConfigured,
  AiAsk,
  AiSend,
  AiConfirm,
  AiIndexing,
  LegalNotices,
  CatalogUnreachable,
  CatalogMissing,
  CatalogueHeading,
  CatalogueLead,
  CatalogueAdd,
  WorkflowRunNow,
  WorkflowSteps,
  WorkflowWaiting,
  WorkflowSkipped,
  WorkflowFailed,
  WorkflowLastRun,
  WorkflowNextRun,
  WorkflowNever,
  WorkflowCycle,
  WorkflowNoSteps,
  WorkflowWhileOpen,
  WorkflowLooped,
]

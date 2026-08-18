# Security Policy

## Reporting a vulnerability

Please report vulnerabilities **privately** — do not open a public issue.

- Email: **info@reactivenet.ai** (subject: `security`)
- Or use GitHub's private vulnerability reporting on this repository, if
  enabled.

You will receive an acknowledgement within 7 days. Please include what is
needed to reproduce the issue; a proof of concept helps. Good-faith research
within these rules will not be met with legal action.

## Scope

The app (`src/`), the MCP server (`mcp/`), the open-data service (`data/`),
the PocketBase hooks (`pb/`) and the website (`site/`). The threat model the
app defends against — DOM XSS from documents, the CSP and Trusted Types
layering, what the sync server can and cannot read — is documented in
[CLAUDE.md](CLAUDE.md) (Security section) and in the published security
policy: <https://reactivenet.ai/note-legali/sicurezza/>
(English: <https://reactivenet.ai/en/note-legali/sicurezza/>).

## Supported versions

The deployed version at <https://app.reactivenet.ai> and the current `main`
branch. There are no maintained release branches.

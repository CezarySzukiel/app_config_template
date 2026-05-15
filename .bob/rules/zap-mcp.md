# OWASP ZAP MCP

Use the official `owaspZap` MCP server for local dynamic application security
testing. Only scan systems this project owns or has explicit permission to test.

For this template, the app target visible to the ZAP daemon is stored in `.env`
as `ZAP_MCP_TARGET`. Prefer the official `zap_baseline_scan` prompt first. Use
`zap_full_scan` and active-scan tools only when the user explicitly asks for
active testing.

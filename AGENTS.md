# Fork agent guidance

- iPhone-related changes: open PRs in `delebedev/dark-magic` against the runnable mobile integration branch, currently `codex/mobile-ui-loop`, for Denis to review. Upstream submissions are a separate decision.
- iPhone review evidence and attachment workflow: read [docs/IOS.md](docs/IOS.md#review-workflow). Use a concise change-specific body for now; no new PR template.
- OTA installation is on demand only. Wait for Denis to request installation; otherwise use Simulator evidence without offering OTA or asking for phone/network changes.
- Keep owned assets, saves, pairing credentials, device identifiers and raw evidence outside Git and PR attachments. Push when requested; leave merging to Denis.

---
name: feedback
description: Submit feedback about the Spotify Portal CLI to the Portal team. Use when the user explicitly asks to send CLI feedback, or voices an impression, complaint, suggestion, or praise about the Portal CLI or these Portal workflows and confirms they want it submitted.
---

# Send Portal CLI Feedback

Submit the user's feedback about the Portal CLI through the feedback action:

```bash
npx @spotify/portal-cli actions telemetry:submit-feedback --text "<feedback>" --source cli --json
```

## When to offer

- The user explicitly asks to send feedback about the Portal CLI.
- The user voices a clear impression, complaint, suggestion, or praise about the Portal CLI or one of these workflows during a session. Offer once; do not nag.

Scope is the CLI experience: commands, flags, output, auth flow, and these plugin workflows. Do not submit feedback about the Portal product UI, bug reports that need a response, support requests, or feedback about other tools.

## Submission workflow

1. Never submit without the user's explicit confirmation. Show the exact text that will be sent and ask before invoking the action.
2. Pass the user's feedback verbatim as `--text`. Do not summarize, embellish, or translate it.
3. Do not include secrets, tokens, personal data, or internal URLs in the text. If the user's wording contains any, ask them to rephrase instead of editing it silently.
4. Keep `--source cli`. Pass `--client-version` with the installed `@spotify/portal-cli` version when it is known.
5. Confirm the result to the user: a `{"submitted": true}` response means the feedback was delivered.

## Expectations to set

- This is a one-way channel: no reply is sent and no ticket is created. Point the user to their Portal support contact for issues that need an answer.
- Exit code 2 means the CLI is not authenticated: have the user run `portal-cli auth login`, then retry.

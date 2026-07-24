---
name: search
description: Search Spotify Portal's software catalog and technical documentation using natural language. Use when the user asks to find services, APIs, systems, components, owners, or Portal documentation and does not already know the exact entity reference.
---

# Search Spotify Portal

Use the Portal CLI search command as the source of truth:

```bash
npx @spotify/portal-cli search --help
npx @spotify/portal-cli search <query> --limit 10 --json
```

## Search workflow

1. Use the user's wording as the initial query.
2. Restrict the search with `--type software-catalog` or `--type techdocs` only when the request clearly targets one source.
3. Return a shortlist rather than the raw result document.
4. Preserve exact entity references, titles, locations, links, and result types.
5. If the first search is empty, retry once with fewer or broader terms.
6. Fetch another page only when the user asks or the first page is clearly insufficient.
7. Report the exact query and filters used.

Do not invent services or documentation when results are sparse.

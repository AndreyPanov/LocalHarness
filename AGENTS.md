# AGENTS.md

## Purpose

This repository is a Swift package for the Monthly Metal Crawler workflow.
The old generic agent-style loop has been removed; do not reintroduce an autonomous tool-calling loop.
The active product direction is the deterministic monthly metal release pipeline described in `Roadmap.md`.

## Repository Layout

- `Package.swift`: SwiftPM package definition
- `Sources/MetalCrawlerCore`: core library code
- `Sources/MetalCrawlerCLI`: executable entry point and `crawl-metal` command
- `Tests/MetalCrawlerTests`: Swift Testing test suite
- `Roadmap.md`: product and architecture direction for the metal crawling pipeline

## Current State

- The executable is `metal-crawler`.
- `crawl-metal` is the active command.
- The generic `run` command and its agent loop have been removed.

## Working Rules

- Prefer small, scoped edits over broad refactors.
- Follow the existing module split: CLI concerns in `MetalCrawlerCLI`, reusable logic in `MetalCrawlerCore`, tests in `Tests`.
- Keep roadmap-aligned work deterministic. Avoid introducing new autonomous tool-calling behavior for the metal crawler pipeline.
- Preserve source provenance and structured artifacts when implementing pipeline features.
- Treat unknown or missing data as `unknown`/not found instead of inventing values.

## Build And Test

Use SwiftPM from the repository root.

```bash
swift build
swift test
swift run metal-crawler crawl-metal --month 2026-05
```

## Implementation Guidance

When extending the planned metal release workflow:

- model the work as explicit stages with clear inputs and outputs
- keep integrations behind client/adapter boundaries
- persist run artifacts under `runs/`
- persist normalized knowledge under `knowledge/releases/`
- keep LLM usage deterministic and bounded to explicit extraction/summarization stages

Probable stage set, based on `Roadmap.md`:

- `ReleaseDiscoveryStage`
- `IdentityNormalizationStage`
- `MetalArchivesEnrichmentStage`
- `SpotifyLookupStage`
- `BandcampLookupStage`
- `CDAvailabilityStage`
- `SummaryGenerationStage`
- `ReportWritingStage`
- `KnowledgeWritingStage`

## Testing Expectations

- Add or update targeted tests for any non-trivial change in `MetalCrawlerCore`.
- Prefer focused unit tests over broad end-to-end coverage unless the change crosses module boundaries.
- For CLI changes, verify both parsing and user-visible behavior where practical.

## Notes For Future Agents

- Read `Roadmap.md` before implementing monthly metal work.
- Check `Package.swift` and `MetalCrawlerCLI.swift` before assuming a command is exposed.
- Keep documentation aligned with the actual code.

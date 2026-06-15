# AGENTS.md

## Purpose

This repository is a Swift package for `LocalHarness`, with two active directions:

1. the current agent-style harness exposed by `harness run <goal>`
2. a planned deterministic monthly metal release pipeline described in `Roadmap.md`

Agents working in this repo should preserve that distinction. Do not present the roadmap as already implemented.

## Repository Layout

- `Package.swift`: SwiftPM package definition
- `Sources/HarnessCore`: core library code
- `Sources/HarnessCLI`: executable entry point and subcommands
- `Tests/LocalHarnessTests`: Swift Testing test suite
- `Roadmap.md`: product and architecture direction for the metal scouting pipeline

## Current State

- The executable is `harness`.
- `run` is wired into the CLI today.
- `scout-metal` exists as a command type but is not currently registered in `HarnessCLI` and throws `ValidationError("scout-metal is not implemented yet.")`.
- The existing harness loop is centered on `Harness.run(goal:)`, `AgentReasoner`, and `ToolExecutor`.
- The roadmap explicitly calls for moving toward deterministic pipeline stages and source adapters.

## Working Rules

- Prefer small, scoped edits over broad refactors.
- Follow the existing module split: CLI concerns in `HarnessCLI`, reusable logic in `HarnessCore`, tests in `Tests`.
- Keep roadmap-aligned work deterministic. Avoid introducing new autonomous tool-calling behavior for the metal scout pipeline.
- Preserve source provenance and structured artifacts when implementing pipeline features.
- Treat unknown or missing data as `unknown`/not found instead of inventing values.

## Build And Test

Use SwiftPM from the repository root.

```bash
swift build
swift test
swift run harness run "your goal"
```

If you wire in `scout-metal`, also verify it with:

```bash
swift run harness scout-metal --month 2026-05
```

## Implementation Guidance

When extending the planned metal release workflow:

- model the work as explicit stages with clear inputs and outputs
- keep integrations behind client/adapter boundaries
- persist run artifacts under `runs/`
- persist normalized knowledge under `knowledge/releases/`
- keep LLM usage limited to summary generation from collected facts

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

- Add or update targeted tests for any non-trivial change in `HarnessCore`.
- Prefer focused unit tests over broad end-to-end coverage unless the change crosses module boundaries.
- For CLI changes, verify both parsing and user-visible behavior where practical.

## Notes For Future Agents

- Read `Roadmap.md` before implementing `scout-metal` work.
- Check `Package.swift` and `HarnessCLI.swift` before assuming a command is exposed.
- Keep documentation aligned with the actual code, especially while the repo is between the current harness design and the planned pipeline design.

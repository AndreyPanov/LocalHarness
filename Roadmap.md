# Monthly Metal Crawler Roadmap

## Project Concept

Monthly Metal Crawler is a deterministic research pipeline for finding metal albums released in a given month, enriching them from trusted sources, checking streaming and purchase availability, and producing a reusable monthly report.

This is not an autonomous agent loop. The system should not let an LLM decide which tools to call. Instead, each pipeline stage has explicit inputs, outputs, source adapters, retry behavior, and saved artifacts.

The LLM is used only near the end to write short summaries from already-collected facts.

## First MVP

Target command:

```bash
metal-crawler crawl-metal --month 2026-05

Expected artifacts:
runs/<run-id>/monthly-metal-releases.md
knowledge/releases/2026-05.json

Reported format
# May 2026 Metal Releases

1. Band — Album
   Release date: 2026-05-10
   Genre: Death metal
   Country: Finland
   Metal Archives: link
   Spotify: link / not found
   Bandcamp: link / not found
   CD: available / not found
   Bandcamp CD + digital: yes / no / unknown
   Summary: short paragraph
# Pipeline
Discover releases for the selected month.
Normalize band and album identity.
Enrich band and album metadata.
Check Spotify availability.
Check Bandcamp availability.
Check CD purchase availability.
Generate summaries from collected facts.
Write Markdown report.
Write structured JSON knowledge file.
Optionally add found albums to Spotify.

# Core Design Principles
Deterministic pipeline first.
LLM only summarizes facts; it does not control workflow.
Every external fact should keep source provenance.
Every lookup should be cacheable and replayable.
Failed enrichments should degrade gracefully.
Spotify write actions must be explicit and optional.
Source Strategy
Initial sources:

Source crawling: BangerTV YouTube videos and InfidelAmsterdam Instagram posts.
Context enrichment: Metal Archives after source candidates are extracted.
Album identity: MusicBrainz, Metal Archives, Spotify search.
Streaming: Spotify Web API.
Bandcamp: Bandcamp search / artist pages.
CD availability: Bandcamp, label stores, Discogs, artist stores where possible.
The MVP should support partial data. Unknown is better than invented.

# Roadmap
Phase 1: Local Pipeline Skeleton
Add a dedicated monthly metal crawler command.
Create deterministic pipeline stages.
Save per-run artifacts under runs/<run-id>/.
Save normalized monthly JSON under knowledge/releases/.
Support dry-run mode by default.
Phase 2: Source Adapters
Add a ReleaseDiscoverySource interface.
Add a BandMetadataSource interface.
Add a StreamingAvailabilitySource interface.
Add a PurchaseAvailabilitySource interface.
Start with one adapter per source type.
Phase 3: Identity Normalization
Normalize band names, album titles, release dates, and countries.
Deduplicate releases from multiple sources.
Track confidence and source provenance.
Preserve ambiguous matches for manual review.
Phase 4: Spotify Integration
Search Spotify by band and album.
Store Spotify album links.
Add optional playlist/library action.
Require explicit CLI flag for writes, for example --add-to-spotify.
Phase 5: Bandcamp And CD Availability
Search Bandcamp artist and album pages.
Detect digital availability.
Detect physical CD availability where possible.
Mark uncertain cases as unknown.
Phase 6: Summarization
Feed only collected facts into the LLM.
Generate short summaries.
Never ask the LLM to invent missing metadata.
Store summary separately from raw facts.
Phase 7: Reports And Review
Generate monthly Markdown report.
Add source links and unknown fields.
Optionally generate a review checklist for uncertain matches.
Later: export CSV, HTML, or playlist notes.
Non-Goals For MVP
No autonomous tool-calling loop.
No general-purpose agent planning.
No full RAG system yet.
No custom schema engine.
No automatic purchasing.
No silent Spotify mutations.

**Architecture Changes**

The old generic agent loop has been removed. The project is now centered on the deterministic `crawl-metal` workflow.

Keep:

- `LLMProvider`
- artifact persistence
- CLI entry point

Add:

```swift
protocol PipelineStage {
    associatedtype Input
    associatedtype Output

    func run(_ input: Input, context: PipelineContext) async throws -> Output
}
For MVP, you may avoid associatedtype complexity and use concrete stages:

ReleaseDiscoveryStage
IdentityNormalizationStage
MetalArchivesEnrichmentStage
SpotifyLookupStage
BandcampLookupStage
CDAvailabilityStage
SummaryGenerationStage
ReportWritingStage
KnowledgeWritingStage
SpotifyActionStage
Key domain models:

MonthlyReleaseRun
ReleaseCandidate
NormalizedRelease
EnrichedRelease
SourceReference
AvailabilityStatus
SpotifyMatch
BandcampMatch
PurchaseAvailability
The important design move: make integrations adapters, not “tools.”

MetalArchivesClient
SpotifyClient
BandcampClient
MusicBrainzClient
DiscogsClient
Then pipeline stages use clients directly. Later, if you still want MCPs, they can be wrapped as clients/adapters behind the same interfaces. That gives you future extensibility without making the MVP feel like an agent framework pretending to be a research app.

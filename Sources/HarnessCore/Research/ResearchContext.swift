import Foundation

struct ResearchContext: Sendable {
    let month: Date
    let runID: RunID
    let crawlClient: any CrawlClient
    let llmFallback: any LLMExtractionFallback
    let runsDirectory: URL
    let knowledgeDirectory: URL
}

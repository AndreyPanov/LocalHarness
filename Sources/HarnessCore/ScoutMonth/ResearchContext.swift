import Foundation

struct ResearchContext: Sendable {
    let month: ReleaseMonth
    let runID: String
    let crawlClient: any CrawlClient
    let llmFallback: any LLMExtractionFallback
    let runsDirectory: URL
    let knowledgeDirectory: URL
}

enum MonthlyMetalError: Error, Sendable {
    case llmRequestFailed(statusCode: Int?, body: String)
    case invalidOperation(String)
    case invalidMonth(String)
    case crawlClientNotImplemented(String)
    case invalidCrawlResponse(String)
    case crawlRequestFailed(url: String, statusCode: Int)
}

enum MonthlyMetalError: Error, Sendable {
    case invalidOperation(String)
    case invalidMonth(String)
    case invalidCrawlResponse(String)
    case crawlRequestFailed(url: String, statusCode: Int)
}

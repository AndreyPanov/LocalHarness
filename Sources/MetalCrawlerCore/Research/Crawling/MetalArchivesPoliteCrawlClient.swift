import Foundation

final class MetalArchivesPoliteCrawlClient: CrawlClient {
    private let wrapped: any CrawlClient
    private let gate: CrawlRequestGate
    private let retryDelayNanoseconds: UInt64
    private let maxRetryCount: Int

    init(
        wrapped: any CrawlClient,
        minimumDelay: TimeInterval = 2.5,
        retryDelay: TimeInterval = 30,
        maxRetryCount: Int = 2
    ) {
        self.wrapped = wrapped
        self.gate = CrawlRequestGate(minimumDelayNanoseconds: nanoseconds(from: minimumDelay))
        self.retryDelayNanoseconds = nanoseconds(from: retryDelay)
        self.maxRetryCount = max(0, maxRetryCount)
    }

    func fetch(_ request: CrawlRequest) async throws -> CrawledPage {
        guard request.source.rawValue.hasPrefix("metal_archives") else {
            return try await wrapped.fetch(request)
        }

        var retryCount = 0

        while true {
            try await gate.wait()

            do {
                return try await wrapped.fetch(request)
            } catch MonthlyMetalError.crawlRequestFailed(_, 429) where retryCount < maxRetryCount {
                retryCount += 1
                try await Task.sleep(nanoseconds: retryDelayNanoseconds)
            }
        }
    }
}

private actor CrawlRequestGate {
    private let minimumDelayNanoseconds: UInt64
    private var nextAllowedRequestAt: UInt64 = 0

    init(minimumDelayNanoseconds: UInt64) {
        self.minimumDelayNanoseconds = minimumDelayNanoseconds
    }

    func wait() async throws {
        guard minimumDelayNanoseconds > 0 else {
            return
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let scheduledRequestAt = max(now, nextAllowedRequestAt)
        nextAllowedRequestAt = scheduledRequestAt + minimumDelayNanoseconds

        guard scheduledRequestAt > now else {
            return
        }

        try await Task.sleep(nanoseconds: scheduledRequestAt - now)
    }
}

private func nanoseconds(from interval: TimeInterval) -> UInt64 {
    UInt64(max(0, interval) * 1_000_000_000)
}

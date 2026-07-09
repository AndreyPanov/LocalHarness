import Foundation

struct MonthlyMetalRecommendationHTMLRenderer: Sendable {
    func render(
        month: String,
        context: MonthlyMetalRecommendationContextArtifact,
        artifact: MonthlyMetalRecommendationArtifact
    ) -> String {
        let contextsByIdentity = Dictionary(
            uniqueKeysWithValues: context.candidates.map {
                (MonthlyMetalReleaseIdentity(bandName: $0.bandName, albumTitle: $0.albumTitle), $0)
            }
        )
        let cards = artifact.recommendations
            .sorted { $0.rank < $1.rank }
            .map { recommendation in
                card(
                    recommendation,
                    context: contextsByIdentity[MonthlyMetalReleaseIdentity(
                        bandName: recommendation.bandName,
                        albumTitle: recommendation.albumTitle
                    )]
                )
            }
            .joined(separator: "\n")
        let body = if artifact.recommendations.isEmpty {
            """
            <section class="empty">
              <h2>No recommendations generated</h2>
              <p>\(escape(artifact.errorMessage ?? "The recommendation model returned no validated suggestions."))</p>
            </section>
            """
        } else {
            cards
        }

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Monthly Metal Recommendations - \(escape(month))</title>
          <style>
            :root {
              color-scheme: dark;
              --bg: #111111;
              --panel: #1b1b1b;
              --panel-strong: #242424;
              --text: #f3f0ea;
              --muted: #b7b0a6;
              --line: #39332d;
              --accent: #e24632;
              --gold: #d7ae5f;
              --green: #79b56d;
            }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
              background: var(--bg);
              color: var(--text);
              line-height: 1.5;
            }
            header {
              padding: 32px max(24px, calc((100vw - 1120px) / 2)) 20px;
              border-bottom: 1px solid var(--line);
              background: #171717;
            }
            h1 {
              margin: 0 0 8px;
              font-size: 32px;
              letter-spacing: 0;
            }
            .subhead {
              color: var(--muted);
              margin: 0;
              max-width: 760px;
            }
            main {
              width: min(1120px, calc(100vw - 32px));
              margin: 24px auto 48px;
              display: grid;
              gap: 16px;
            }
            .card {
              display: grid;
              grid-template-columns: 180px 1fr;
              gap: 18px;
              padding: 16px;
              border: 1px solid var(--line);
              border-radius: 8px;
              background: var(--panel);
            }
            .cover,
            .cover-placeholder {
              width: 180px;
              aspect-ratio: 1;
              border-radius: 6px;
              object-fit: cover;
              background: var(--panel-strong);
              border: 1px solid var(--line);
            }
            .cover-placeholder {
              display: grid;
              place-items: center;
              padding: 16px;
              text-align: center;
              color: var(--muted);
              font-weight: 700;
            }
            .rank {
              color: var(--gold);
              font-weight: 800;
              font-size: 13px;
              text-transform: uppercase;
            }
            .title {
              margin: 4px 0 4px;
              font-size: 24px;
              letter-spacing: 0;
            }
            .meta {
              display: flex;
              flex-wrap: wrap;
              gap: 8px;
              margin: 8px 0 12px;
            }
            .pill {
              border: 1px solid var(--line);
              border-radius: 999px;
              color: var(--muted);
              padding: 3px 9px;
              font-size: 12px;
              background: #161616;
            }
            .decision {
              color: white;
              border-color: transparent;
              background: var(--accent);
            }
            .section-title {
              margin: 12px 0 4px;
              color: var(--muted);
              font-size: 13px;
              font-weight: 800;
              text-transform: uppercase;
            }
            ul {
              margin: 4px 0 0;
              padding-left: 20px;
            }
            a {
              color: var(--green);
              text-decoration: none;
            }
            a:hover { text-decoration: underline; }
            .links {
              display: flex;
              flex-wrap: wrap;
              gap: 12px;
              margin-top: 12px;
            }
            .empty {
              padding: 24px;
              border: 1px solid var(--line);
              border-radius: 8px;
              background: var(--panel);
            }
            @media (max-width: 720px) {
              .card {
                grid-template-columns: 1fr;
              }
              .cover,
              .cover-placeholder {
                width: 100%;
                max-width: 360px;
              }
            }
          </style>
        </head>
        <body>
          <header>
            <h1>Monthly Metal Recommendations - \(escape(month))</h1>
            <p class="subhead">Ranked from validated crawler facts using \(escape(artifact.model)). Recommendations: \(artifact.recommendations.count).</p>
          </header>
          <main>
            \(body)
          </main>
        </body>
        </html>
        """
    }

    private func card(
        _ recommendation: MonthlyMetalRecommendation,
        context: MonthlyMetalRecommendationCandidateContext?
    ) -> String {
        let cover = coverHTML(for: recommendation, context: context)
        let meta = metaPills(recommendation: recommendation, context: context)
        let caution = listSection(title: "Cautions", items: recommendation.cautionReasons)
        let purchase = recommendation.purchaseNotes.map {
            """
            <div class="section-title">Purchase Notes</div>
            <p>\(escape($0))</p>
            """
        } ?? ""
        let links = linksHTML(context: context)

        return """
        <article class="card">
          \(cover)
          <section>
            <div class="rank">#\(recommendation.rank) - \(escape(decisionLabel(recommendation.decision))) - \(Int(recommendation.confidence * 100))%</div>
            <h2 class="title">\(escape(recommendation.bandName)) - \(escape(recommendation.albumTitle))</h2>
            <div class="meta">\(meta)</div>
            \(listSection(title: "Why It Fits", items: recommendation.fitReasons))
            \(caution)
            \(purchase)
            \(listSection(title: "Evidence", items: recommendation.evidence))
            \(links)
          </section>
        </article>
        """
    }

    private func coverHTML(
        for recommendation: MonthlyMetalRecommendation,
        context: MonthlyMetalRecommendationCandidateContext?
    ) -> String {
        if let coverImageURL = context?.coverImageURL {
            return #"<img class="cover" src="\#(escapeAttribute(coverImageURL.absoluteString))" alt="\#(escapeAttribute(recommendation.bandName)) - \#(escapeAttribute(recommendation.albumTitle)) cover">"#
        }

        return """
        <div class="cover-placeholder">\(escape(recommendation.bandName))<br>\(escape(recommendation.albumTitle))</div>
        """
    }

    private func metaPills(
        recommendation: MonthlyMetalRecommendation,
        context: MonthlyMetalRecommendationCandidateContext?
    ) -> String {
        var values = [
            (decisionLabel(recommendation.decision), "pill decision")
        ]

        if let releaseType = context?.releaseType {
            values.append((releaseType, "pill"))
        }

        if let genre = context?.metalArchives?.genre {
            values.append((genre, "pill"))
        }

        if let labelName = context?.labelName {
            values.append((labelName, "pill"))
        }

        if let releaseDateText = context?.releaseDateText {
            values.append((releaseDateText, "pill"))
        }

        if context?.bandcamp?.isCDAvailable == true {
            values.append(("CD available", "pill"))
        }

        if context?.bandcamp?.hasDigital == true {
            values.append(("Digital", "pill"))
        }

        return values
            .map { #"<span class="\#($0.1)">\#(escape($0.0))</span>"# }
            .joined(separator: "\n")
    }

    private func listSection(title: String, items: [String]) -> String {
        guard !items.isEmpty else {
            return ""
        }

        return """
        <div class="section-title">\(escape(title))</div>
        <ul>
          \(items.map { "<li>\(escape($0))</li>" }.joined(separator: "\n"))
        </ul>
        """
    }

    private func linksHTML(context: MonthlyMetalRecommendationCandidateContext?) -> String {
        var links: [String] = []

        if let metalArchivesURL = context?.metalArchivesURL {
            links.append(#"<a href="\#(escapeAttribute(metalArchivesURL.absoluteString))">Metal Archives</a>"#)
        }

        if let bandcampURL = context?.bandcampURL {
            links.append(#"<a href="\#(escapeAttribute(bandcampURL.absoluteString))">Bandcamp</a>"#)
        }

        guard !links.isEmpty else {
            return ""
        }

        return #"<div class="links">\#(links.joined(separator: "\n"))</div>"#
    }

    private func decisionLabel(_ decision: MonthlyMetalRecommendationDecision) -> String {
        switch decision {
        case .mustCheck:
            return "Must check"
        case .likelyInteresting:
            return "Likely interesting"
        case .maybe:
            return "Maybe"
        case .skip:
            return "Skip"
        }
    }

    private func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func escapeAttribute(_ value: String) -> String {
        escape(value)
    }
}

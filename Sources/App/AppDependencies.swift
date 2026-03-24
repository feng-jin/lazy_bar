import Foundation

struct AppDependencies {
    let quoteProvider: any QuoteProviding

    static let live = AppDependencies(
        quoteProvider: MockQuoteProvider()
    )
}

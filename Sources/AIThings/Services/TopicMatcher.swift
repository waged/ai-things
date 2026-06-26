import Foundation
import NaturalLanguage

/// On-device semantic similarity for routing a message to the right chat and
/// finding near-duplicate chats. Uses Apple's word embeddings (averaged into a
/// sentence vector); falls back to keyword overlap when embeddings are absent.
final class TopicMatcher {
    private let embedding = NLEmbedding.wordEmbedding(for: .english)

    /// Cosine similarity in [0, 1] between two pieces of text.
    func similarity(_ a: String, _ b: String) -> Double {
        if let va = vector(for: a), let vb = vector(for: b) {
            return max(0, cosine(va, vb))
        }
        return jaccard(a, b)
    }

    // MARK: - Embedding

    private func vector(for text: String) -> [Double]? {
        guard let embedding else { return nil }
        let words = tokens(text)
        guard !words.isEmpty else { return nil }
        var sum: [Double]?
        var count = 0
        for word in words {
            guard let v = embedding.vector(for: word) else { continue }
            if sum == nil {
                sum = v
            } else {
                for i in 0..<v.count { sum![i] += v[i] }
            }
            count += 1
        }
        guard var mean = sum, count > 0 else { return nil }
        for i in 0..<mean.count { mean[i] /= Double(count) }
        return mean
    }

    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }

    // MARK: - Fallback

    private func jaccard(_ a: String, _ b: String) -> Double {
        let sa = Set(tokens(a)), sb = Set(tokens(b))
        guard !sa.isEmpty, !sb.isEmpty else { return 0 }
        let inter = sa.intersection(sb).count
        let union = sa.union(sb).count
        return union == 0 ? 0 : Double(inter) / Double(union)
    }

    private func tokens(_ text: String) -> [String] {
        text.lowercased()
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 2 }
    }
}

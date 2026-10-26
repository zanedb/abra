import Foundation

enum SongVersionMatcher {
    static func searchQuery(title: String, artist: String) -> String {
        "\(baseTitle(title)) \(artist)".trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isMatch(title: String, artist: String, originalTitle: String, originalArtist: String) -> Bool {
        let artistKey = normalized(originalArtist)
        let titleKey = normalized(baseTitle(originalTitle))
        guard !artistKey.isEmpty, !titleKey.isEmpty else { return false }
        return normalized(artist) == artistKey && normalized(baseTitle(title)) == titleKey
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init).joined()
    }

    private static func baseTitle(_ title: String) -> String {
        // Retain meaningful subtitles and featured artists; omit only version labels.
        let pattern = #"\s*(?:\(|\[| - )[^\(\)\[\]]*(?:remaster|version|mix|edit|live|mono|stereo|acoustic|instrumental|rerecord)[^\(\)\[\]]*[\)\]]?\s*$"#
        return title.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
    }
}

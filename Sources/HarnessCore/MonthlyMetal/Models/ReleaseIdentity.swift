public struct ReleaseIdentity: Codable, Hashable, Sendable {
    public let bandID: BandID?
    public let albumID: AlbumID?
    public let bandName: String
    public let albumTitle: String

    public init(bandID: BandID? = nil, albumID: AlbumID? = nil, bandName: String, albumTitle: String) {
        self.bandID = bandID
        self.albumID = albumID
        self.bandName = bandName
        self.albumTitle = albumTitle
    }
}

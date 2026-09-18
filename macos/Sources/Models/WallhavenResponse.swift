import Foundation

public struct WallhavenResponse: Codable {
    public let data: [WallhavenItem]?
    public let meta: WallhavenMeta?
}

public struct WallhavenItem: Codable, Identifiable {
    public let id: String
    public let url: String
    public let shortUrl: String?
    public let views: Int?
    public let favorites: Int?
    public let source: String?
    public let purity: String?
    public let category: String?
    public let dimensionX: Int?
    public let dimensionY: Int?
    public let resolution: String?
    public let ratio: String?
    public let fileSize: Int64?
    public let fileType: String?
    public let createdAt: String?
    public let colors: [String]?
    public let path: String
    public let thumbs: WallhavenThumbs?

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case shortUrl = "short_url"
        case views
        case favorites
        case source
        case purity
        case category
        case dimensionX = "dimension_x"
        case dimensionY = "dimension_y"
        case resolution
        case ratio
        case fileSize = "file_size"
        case fileType = "file_type"
        case createdAt = "created_at"
        case colors
        case path
        case thumbs
    }
}

public struct WallhavenThumbs: Codable {
    public let large: String?
    public let original: String?
    public let small: String?
}

public struct WallhavenMeta: Codable {
    public let currentPage: Int?
    public let lastPage: Int?
    public let perPage: Int?
    public let total: Int?

    enum CodingKeys: String, CodingKey {
        case currentPage = "current_page"
        case lastPage = "last_page"
        case perPage = "per_page"
        case total
    }
}

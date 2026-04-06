import Foundation

// MARK: - ENVI-0676 Product Offer Type

/// The category of a product or service a creator is selling.
enum OfferType: String, Codable, CaseIterable, Identifiable {
    case digital
    case physical
    case service

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .digital:  return "Digital"
        case .physical: return "Physical"
        case .service:  return "Service"
        }
    }

    var iconName: String {
        switch self {
        case .digital:  return "doc.fill"
        case .physical: return "shippingbox.fill"
        case .service:  return "person.crop.rectangle.fill"
        }
    }
}

// MARK: - ENVI-0677 Product Offer

/// A product, digital good, or service offered by a creator.
struct ProductOffer: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let price: Decimal
    let type: OfferType
    let description: String
    let imageURL: URL?
    let salesCount: Int

    /// Formatted price string, e.g. "$29.99".
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

// MARK: - ENVI-0678 Bio Link

/// A single link displayed in a creator's Link-in-Bio page.
struct BioLink: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var url: String
    var clicks: Int
    var isActive: Bool
}

// MARK: - ENVI-0679 Link-in-Bio Theme

/// Available visual themes for the Link-in-Bio page.
enum LinkInBioThemeName: String, Codable, CaseIterable, Identifiable {
    case minimal
    case bold
    case gradient
    case neon
    case mono

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal:  return "Minimal"
        case .bold:     return "Bold"
        case .gradient: return "Gradient"
        case .neon:     return "Neon"
        case .mono:     return "Mono"
        }
    }
}

// MARK: - ENVI-0680 Link-in-Bio

/// A creator's Link-in-Bio page configuration.
struct LinkInBio: Identifiable, Codable, Equatable {
    let id: String
    var links: [BioLink]
    var theme: LinkInBioThemeName
}

// MARK: - ENVI-0681 Sponsorship Deal Status

/// Status stages of a brand sponsorship deal.
enum DealStatus: String, Codable, CaseIterable, Identifiable {
    case inquiry
    case negotiation
    case accepted
    case inProgress = "in_progress"
    case delivered
    case completed
    case declined

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .inquiry:     return "Inquiry"
        case .negotiation: return "Negotiation"
        case .accepted:    return "Accepted"
        case .inProgress:  return "In Progress"
        case .delivered:   return "Delivered"
        case .completed:   return "Completed"
        case .declined:    return "Declined"
        }
    }

    var iconName: String {
        switch self {
        case .inquiry:     return "envelope.fill"
        case .negotiation: return "bubble.left.and.bubble.right.fill"
        case .accepted:    return "checkmark.seal.fill"
        case .inProgress:  return "arrow.triangle.2.circlepath"
        case .delivered:   return "paperplane.fill"
        case .completed:   return "star.fill"
        case .declined:    return "xmark.circle.fill"
        }
    }

    /// Pipeline ordering index.
    var sortOrder: Int {
        switch self {
        case .inquiry:     return 0
        case .negotiation: return 1
        case .accepted:    return 2
        case .inProgress:  return 3
        case .delivered:   return 4
        case .completed:   return 5
        case .declined:    return 6
        }
    }
}

// MARK: - ENVI-0682 Sponsorship Deal

/// A brand sponsorship deal tracked by the creator.
struct SponsorshipDeal: Identifiable, Codable, Equatable {
    let id: String
    let brandName: String
    let budget: Decimal
    let deliverables: [String]
    var status: DealStatus
    let deadline: Date

    /// Formatted budget string.
    var formattedBudget: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: budget as NSDecimalNumber) ?? "$\(budget)"
    }

    /// Days remaining until deadline.
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
    }
}

// MARK: - ENVI-0683 Marketplace Category

/// Categories for marketplace listings.
enum MarketplaceCategory: String, Codable, CaseIterable, Identifiable {
    case templates
    case presets
    case courses
    case ebooks
    case graphics
    case audio
    case consulting
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .templates:   return "Templates"
        case .presets:     return "Presets"
        case .courses:     return "Courses"
        case .ebooks:      return "E-Books"
        case .graphics:    return "Graphics"
        case .audio:       return "Audio"
        case .consulting:  return "Consulting"
        case .other:       return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .templates:   return "doc.on.doc.fill"
        case .presets:     return "slider.horizontal.3"
        case .courses:     return "play.rectangle.fill"
        case .ebooks:      return "book.fill"
        case .graphics:    return "paintbrush.fill"
        case .audio:       return "waveform"
        case .consulting:  return "person.2.fill"
        case .other:       return "ellipsis.circle.fill"
        }
    }
}

// MARK: - ENVI-0684 Marketplace Listing

/// A listing on the ENVI creator marketplace.
struct MarketplaceListing: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let category: MarketplaceCategory
    let price: Decimal
    let creatorName: String
    let rating: Double
    let downloads: Int
    let description: String
    let imageURL: URL?

    /// Formatted price string.
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: price as NSDecimalNumber) ?? "$\(price)"
    }
}

// MARK: - ENVI-0685 UGC Request Status

/// Status of a UGC (User-Generated Content) request from a brand.
enum UGCStatus: String, Codable, CaseIterable, Identifiable {
    case open
    case applied
    case accepted
    case inProgress = "in_progress"
    case submitted
    case approved
    case rejected

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .open:       return "Open"
        case .applied:    return "Applied"
        case .accepted:   return "Accepted"
        case .inProgress: return "In Progress"
        case .submitted:  return "Submitted"
        case .approved:   return "Approved"
        case .rejected:   return "Rejected"
        }
    }
}

// MARK: - ENVI-0686 UGC Request

/// A brand's request for user-generated content from creators.
struct UGCRequest: Identifiable, Codable, Equatable {
    let id: String
    let brandName: String
    let brief: String
    let compensation: Decimal
    let deadline: Date
    var status: UGCStatus

    /// Formatted compensation string.
    var formattedCompensation: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: compensation as NSDecimalNumber) ?? "$\(compensation)"
    }

    /// Days remaining until deadline.
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
    }
}

// MARK: - Mock Data

extension ProductOffer {
    static let mock: [ProductOffer] = [
        .init(id: "offer-1", name: "Content Strategy Guide", price: 29.99, type: .digital,
              description: "A comprehensive guide to building your content strategy from scratch.",
              imageURL: nil, salesCount: 142),
        .init(id: "offer-2", name: "Brand Kit Bundle", price: 49.99, type: .digital,
              description: "Professional templates, fonts, and color palettes for your brand.",
              imageURL: nil, salesCount: 87),
        .init(id: "offer-3", name: "1-on-1 Coaching Session", price: 99.00, type: .service,
              description: "60-minute personalized coaching call covering growth strategy.",
              imageURL: nil, salesCount: 34),
        .init(id: "offer-4", name: "Merch T-Shirt", price: 24.99, type: .physical,
              description: "Premium cotton tee with signature design.", imageURL: nil, salesCount: 256),
    ]
}

extension BioLink {
    static let mock: [BioLink] = [
        .init(id: "link-1", title: "My Website", url: "https://example.com", clicks: 1240, isActive: true),
        .init(id: "link-2", title: "Latest Video", url: "https://youtube.com/watch?v=abc", clicks: 890, isActive: true),
        .init(id: "link-3", title: "Free Guide", url: "https://example.com/guide", clicks: 562, isActive: true),
        .init(id: "link-4", title: "Discord Community", url: "https://discord.gg/xyz", clicks: 345, isActive: false),
    ]
}

extension LinkInBio {
    static let mock = LinkInBio(id: "bio-1", links: BioLink.mock, theme: .minimal)
}

extension SponsorshipDeal {
    static let mock: [SponsorshipDeal] = [
        .init(id: "deal-1", brandName: "Notion", budget: 5000, deliverables: ["1 Reel", "2 Stories", "1 Blog Post"],
              status: .inProgress, deadline: Date().addingTimeInterval(7 * 86400)),
        .init(id: "deal-2", brandName: "Figma", budget: 3500, deliverables: ["1 Tutorial Video", "1 Thread"],
              status: .negotiation, deadline: Date().addingTimeInterval(14 * 86400)),
        .init(id: "deal-3", brandName: "Linear", budget: 2000, deliverables: ["1 Reel", "1 Story"],
              status: .inquiry, deadline: Date().addingTimeInterval(21 * 86400)),
        .init(id: "deal-4", brandName: "Vercel", budget: 8000, deliverables: ["2 Videos", "3 Posts", "1 Newsletter"],
              status: .completed, deadline: Date().addingTimeInterval(-3 * 86400)),
    ]
}

extension MarketplaceListing {
    static let mock: [MarketplaceListing] = [
        .init(id: "mkt-1", title: "Social Media Calendar Template", category: .templates, price: 19.99,
              creatorName: "Sara Design", rating: 4.8, downloads: 1230,
              description: "Plan 3 months of content with this Notion template.", imageURL: nil),
        .init(id: "mkt-2", title: "Moody Lightroom Presets", category: .presets, price: 14.99,
              creatorName: "VisualLab", rating: 4.6, downloads: 3400,
              description: "10 premium presets for cinematic storytelling.", imageURL: nil),
        .init(id: "mkt-3", title: "Creator Economy 101", category: .courses, price: 49.99,
              creatorName: "Alex Growth", rating: 4.9, downloads: 890,
              description: "Learn to monetize your audience in 30 days.", imageURL: nil),
        .init(id: "mkt-4", title: "Instagram Story Frames", category: .graphics, price: 9.99,
              creatorName: "PixelPro", rating: 4.4, downloads: 2100,
              description: "50 customizable story frame templates.", imageURL: nil),
        .init(id: "mkt-5", title: "Podcast Intro Music Pack", category: .audio, price: 24.99,
              creatorName: "SoundWave", rating: 4.7, downloads: 670,
              description: "10 royalty-free intro tracks for podcasters.", imageURL: nil),
        .init(id: "mkt-6", title: "The Creator's Playbook", category: .ebooks, price: 12.99,
              creatorName: "ContentHQ", rating: 4.5, downloads: 1800,
              description: "200-page guide to building a creator business.", imageURL: nil),
    ]
}

extension UGCRequest {
    static let mock: [UGCRequest] = [
        .init(id: "ugc-1", brandName: "Glossier", brief: "Create a 30-second unboxing Reel featuring our new skincare line.",
              compensation: 500, deadline: Date().addingTimeInterval(10 * 86400), status: .open),
        .init(id: "ugc-2", brandName: "Athletic Greens", brief: "Morning routine TikTok showing AG1 preparation.",
              compensation: 750, deadline: Date().addingTimeInterval(5 * 86400), status: .applied),
        .init(id: "ugc-3", brandName: "Canva", brief: "Demo video showcasing the new Magic Write feature.",
              compensation: 1200, deadline: Date().addingTimeInterval(14 * 86400), status: .accepted),
        .init(id: "ugc-4", brandName: "Headspace", brief: "Share your meditation journey in a carousel post.",
              compensation: 400, deadline: Date().addingTimeInterval(3 * 86400), status: .inProgress),
    ]
}

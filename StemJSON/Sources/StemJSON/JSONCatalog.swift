import Foundation

/// Catalog of all Stem modules bundled with the examples.
///
/// Each case maps to a file in StemJSON/Resources/.
public enum JSONCatalog {

    public enum Module: String, CaseIterable, Identifiable {
        public var id: String { rawValue }

        /// Three-in-one math tool: calculator, tip split, unit converter
        case calculator = "calculator"
        /// Chat app with real-time messaging
        case messenger  = "messenger"
        /// Live weather search and forecasts via Open-Meteo
        case weather    = "weather"
        /// Product catalog with remote API, local persistence & search
        case shop       = "shop"
        /// Photo gallery with device library access, grid layout,
        /// double-tap to favorite, sort, and date formatting.
        case gallery    = "gallery"
        /// Multi-file zip recipe book: pdf, media, file:// navigation,
        /// EN/UK localization across separate JSON files.
        case recipes    = "recipes"
        /// Restaurant reservation form demonstrating form, section,
        /// datePicker, picker, toggle, textfield, onSubmit, and alert modal.
        case booking    = "booking"
        /// Developer reference: every component type rendered with its
        /// shimmer / loading variant side-by-side.
        case skeletons  = "skeletons"
        /// Instagram-like feed. Zip-packaged module bundling its own image
        /// asset (demonstrates `file://` sources), EN/UK localization, and a
        /// Pexels API integration via secured-storage + auth interceptor.
        case instagram  = "instagram"
        /// Live reference for every built-in expression function (§8.6).
        case functions  = "functions"
        /// Live readout of every #{…} system literal (§6.3).
        case system     = "system"
        /// Heavy-media components: video, pdf, map, universal `media`.
        case media      = "media"
        /// Two-column iPad split view (§4.5 `splitview`).
        case splitview  = "splitview"
        /// Absolute smallest "Hello, name" module (under 30 lines).
        case hello      = "hello"

        /// Modules displayed on the home grid.
        public static var allCases: [Module] {
            [.hello, .instagram, .calculator, .messenger, .weather, .shop, .gallery,
             .recipes, .booking, .skeletons,
             .functions, .system, .media, .splitview]
        }

        public var fileExtension: String {
            switch self {
            case .instagram, .recipes: return "zip"
            default:                  return "json"
            }
        }

        public var displayName: String {
            switch self {
            case .calculator: return "Smart Calculator"
            case .messenger:  return "Messenger"
            case .weather:    return "Weather"
            case .shop:       return "Shop"
            case .gallery:    return "Gallery"
            case .recipes:    return "Recipes"
            case .booking:    return "Booking"
            case .skeletons:  return "Component Reference"
            case .instagram:  return "Instagram"
            case .functions:  return "Functions"
            case .system:     return "System Literals"
            case .media:      return "Media Showcase"
            case .splitview:  return "Split View"
            case .hello:      return "Hello"
            }
        }

        /// SF Symbol name rendered on the home-grid tile.
        public var iconName: String {
            switch self {
            case .calculator: return "plus.forwardslash.minus"
            case .messenger:  return "bubble.left.and.bubble.right"
            case .weather:    return "cloud.sun.fill"
            case .shop:       return "bag.fill"
            case .gallery:    return "photo.on.rectangle.angled"
            case .recipes:    return "book.fill"
            case .booking:    return "calendar.badge.plus"
            case .skeletons:  return "text.redaction"
            case .instagram:  return "camera.aperture"
            case .functions:  return "function"
            case .system:     return "iphone.gen3"
            case .media:      return "play.rectangle.on.rectangle.fill"
            case .splitview:  return "sidebar.left"
            case .hello:      return "hand.wave.fill"
            }
        }

        /// Tint color for the tile icon.
        public var iconColor: String {
            switch self {
            case .calculator: return "orange"
            case .messenger:  return "teal"
            case .weather:    return "blue"
            case .shop:       return "green"
            case .gallery:    return "mint"
            case .recipes:    return "brown"
            case .booking:    return "indigo"
            case .skeletons:  return "purple"
            case .instagram:  return "pink"
            case .functions:  return "cyan"
            case .system:     return "gray"
            case .media:      return "red"
            case .splitview:  return "blue"
            case .hello:      return "yellow"
            }
        }

        /// Short description shown on the tile.
        public var subtitle: String {
            switch self {
            case .calculator: return "Calculator, tip split & unit converter"
            case .messenger:  return "Real-time chat with media"
            case .weather:    return "Live forecasts with Open-Meteo API"
            case .shop:       return "Product catalog with search & persistence"
            case .gallery:    return "Grid layout, photos repo, sort & format"
            case .recipes:    return "Multi-file zip with pdf, media & file:// nav"
            case .booking:    return "Form, datePicker, toggle & alert modal"
            case .skeletons:  return "Developer reference for every component and its loading state"
            case .instagram:  return "Zip + bundled asset + localization + API"
            case .functions:  return "Every expression function, live"
            case .system:     return "Every #{} system literal, live"
            case .media:      return "video, pdf, map & universal media"
            case .splitview:  return "Two-column iPad layout"
            case .hello:      return "The smallest possible module"
            }
        }
    }

    public static func data(for module: Module) throws -> Data {
        guard let url = Bundle.module.url(
            forResource: module.rawValue,
            withExtension: module.fileExtension
        ) else {
            throw CatalogError.moduleNotFound(module.rawValue)
        }
        return try Data(contentsOf: url)
    }

    public enum CatalogError: LocalizedError {
        case moduleNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .moduleNotFound(let name):
                return "Module not found in StemJSON bundle: \(name)"
            }
        }
    }
}

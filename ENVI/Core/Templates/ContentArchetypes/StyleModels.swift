//  StyleModels.swift
//  ENVI v3.0 — Visual Style Taxonomy (406 Styles, 15 Families)
//  iOS 26+ | Swift 6 Strict Concurrency | Sendable
//
//  Integrates with:
//    - ENVITheme (colors/typography via brand purple #7A56C4, SpaceMono-Bold)
//    - TemplateRegistry (TemplateDefinition, StyleModel)
//    - ContentArchetype (ContentFormat, archetype types)
//    - StyleCompatibilityMatrix (archetype x style scoring)

import Foundation

// MARK: - ENVITheme Integration

/// ENVI brand design tokens — single source of truth for colors, typography, and spacing.
/// Aligned with the app's dark-mode-first design system.
@available(iOS 26, *)
public enum ENVITheme {

    // MARK: Brand Colors
    public static let brandPurple = ENVIColor(hex: 0x7A56C4)
    public static let brandPurpleLight = ENVIColor(hex: 0x9B7AD4)
    public static let brandPurpleDark = ENVIColor(hex: 0x5D3F96)

    // MARK: Semantic Colors (Dark Mode Primary)
    public static let bgPrimary = ENVIColor(hex: 0x0A0A0F)
    public static let bgSecondary = ENVIColor(hex: 0x14141F)
    public static let bgTertiary = ENVIColor(hex: 0x1E1E2E)
    public static let bgElevated = ENVIColor(hex: 0x282840)

    public static let textPrimary = ENVIColor(hex: 0xF0F0F5)
    public static let textSecondary = ENVIColor(hex: 0xA0A0B8)
    public static let textTertiary = ENVIColor(hex: 0x6A6A80)
    public static let textOnBrand = ENVIColor(hex: 0xFFFFFF)

    public static let borderSubtle = ENVIColor(hex: 0x2A2A3A)
    public static let borderAccent = ENVIColor(hex: 0x7A56C4)
    public static let divider = ENVIColor(hex: 0x1A1A28)

    public static let success = ENVIColor(hex: 0x34C759)
    public static let warning = ENVIColor(hex: 0xFF9F0A)
    public static let error = ENVIColor(hex: 0xFF453A)
    public static let info = ENVIColor(hex: 0x5AC8FA)

    // MARK: Typography
    public static let fontDisplay = "SpaceMono-Bold"
    public static let fontBody = "SpaceMono-Regular"
    public static let fontCaption = "SpaceMono-Regular"

    // MARK: Spacing Scale
    public static let spacingXXS: Double = 2
    public static let spacingXS: Double = 4
    public static let spacingSM: Double = 8
    public static let spacingMD: Double = 12
    public static let spacingLG: Double = 16
    public static let spacingXL: Double = 24
    public static let spacingXXL: Double = 32
    public static let spacingXXXL: Double = 48

    // MARK: Corner Radii
    public static let cornerSM: Double = 8
    public static let cornerMD: Double = 12
    public static let cornerLG: Double = 16
    public static let cornerXL: Double = 24
    public static let cornerPill: Double = 9999
}

// MARK: - ENVI Color Wrapper

/// Platform-agnostic color wrapper that bridges hex values to SwiftUI/UIKit.
/// Uses `UIColor` on iOS 26+ as the underlying representation.
@available(iOS 26, *)
public struct ENVIColor: Sendable, Hashable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    public let hexValue: UInt

    public init(hex: UInt, alpha: Double = 1.0) {
        self.hexValue = hex
        self.red = Double((hex >> 16) & 0xFF) / 255.0
        self.green = Double((hex >> 8) & 0xFF) / 255.0
        self.blue = Double(hex & 0xFF) / 255.0
        self.alpha = alpha
    }

    /// Returns a CSS-compatible rgba string for use in rendering pipelines.
    public var cssRGBA: String {
        String(
            format: "rgba(%d, %d, %d, %.2f)",
            Int(red * 255), Int(green * 255), Int(blue * 255), alpha
        )
    }

    /// Returns a hex string prefixed with #.
    public var hexString: String {
        String(format: "#%06X", hexValue & 0xFFFFFF)
    }

    public static func == (lhs: ENVIColor, rhs: ENVIColor) -> Bool {
        lhs.hexValue == rhs.hexValue && lhs.alpha == rhs.alpha
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(hexValue)
        hasher.combine(alpha)
    }
}

// MARK: - Visual Style Family

/// Top-level style category families (15 families, 406 individual styles).
/// Each family groups related visual aesthetics that share underlying design principles.
@available(iOS 26, *)
public enum VisualStyleFamily: String, Codable, Sendable, CaseIterable, Hashable {
    case Architectural = "Architectural"
    case BoldAndGraphic = "Bold & Graphic"
    case CleanAndMinimal = "Clean & Minimal"
    case ColorFocused = "Color Focused"
    case Composition = "Composition"
    case Conceptual = "Conceptual"
    case Cultural = "Cultural"
    case DigitalNative = "Digital Native"
    case EmotionalTone = "Emotional Tone"
    case FoodStyling = "Food Styling"
    case Functional = "Functional"
    case FutureForward = "Future Forward"
    case InternetAesthetics = "Internet Aesthetics"
    case Lighting = "Lighting"
    case Material = "Material"
    case ModernDigital = "Modern Digital"
    case MoodAndAtmosphere = "Mood & Atmosphere"
    case Motion = "Motion"
    case NatureInspired = "Nature Inspired"
    case OriginalBase = "Original Base"
    case PhotographyGenres = "Photography Genres"
    case PrintAnalog = "Print/Analog"
    case ProfessionalIndustry = "Professional Industry"
    case RegionalGeographic = "Regional/Geographic"
    case Seasonal = "Seasonal"
    case SoundAssociated = "Sound-Associated"
    case Sports = "Sports"
    case Subculture = "Subculture"
    case Texture = "Texture"
    case Typography = "Typography"
    case UIUXStyles = "UI/UX Styles"
    case VideoGenres = "Video Genres"
    case VintagebyEra = "Vintage by Era"

    /// Display name with proper spacing and punctuation.
    public var displayName: String { rawValue }

    /// Canonical identifier used in template matching and CDN lookups.
    public var canonicalID: String {
        rawValue.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "&", with: "And")
            .replacingOccurrences(of: "/", with: "_")
    }

    /// ENVI brand color accent for this family in the UI.
    public var accentColor: ENVIColor {
        switch self {
        case .Architectural: return ENVIColor(hex: 0x8B7355)
        case .BoldAndGraphic: return ENVIColor(hex: 0xFF3B30)
        case .CleanAndMinimal: return ENVIColor(hex: 0xF0F0F5)
        case .ColorFocused: return ENVIColor(hex: 0xFF9F0A)
        case .Composition: return ENVIColor(hex: 0x5AC8FA)
        case .Conceptual: return ENVIColor(hex: 0xAF52DE)
        case .Cultural: return ENVIColor(hex: 0xFF2D55)
        case .DigitalNative: return ENVIColor(hex: 0x00D4AA)
        case .EmotionalTone: return ENVIColor(hex: 0x5856D6)
        case .FoodStyling: return ENVIColor(hex: 0xFF6B35)
        case .Functional: return ENVIColor(hex: 0x34C759)
        case .FutureForward: return ENVIColor(hex: 0x007AFF)
        case .InternetAesthetics: return ENVIColor(hex: 0xFF375F)
        case .Lighting: return ENVIColor(hex: 0xFFD60A)
        case .Material: return ENVIColor(hex: 0xA2845E)
        case .ModernDigital: return ENVIColor(hex: 0x7A56C4)
        case .MoodAndAtmosphere: return ENVIColor(hex: 0x64D2FF)
        case .Motion: return ENVIColor(hex: 0x30D158)
        case .NatureInspired: return ENVIColor(hex: 0x34C759)
        case .OriginalBase: return ENVIColor(hex: 0x7A56C4)
        case .PhotographyGenres: return ENVIColor(hex: 0x5E5CE6)
        case .PrintAnalog: return ENVIColor(hex: 0xC4A882)
        case .ProfessionalIndustry: return ENVIColor(hex: 0x8E8E93)
        case .RegionalGeographic: return ENVIColor(hex: 0x63E6E2)
        case .Seasonal: return ENVIColor(hex: 0xFF9F0A)
        case .SoundAssociated: return ENVIColor(hex: 0xBF5AF2)
        case .Sports: return ENVIColor(hex: 0xFF453A)
        case .Subculture: return ENVIColor(hex: 0xFF375F)
        case .Texture: return ENVIColor(hex: 0xAC8E68)
        case .Typography: return ENVIColor(hex: 0xF0F0F5)
        case .UIUXStyles: return ENVIColor(hex: 0x007AFF)
        case .VideoGenres: return ENVIColor(hex: 0xFF2D55)
        case .VintagebyEra: return ENVIColor(hex: 0xC4A882)
        }
    }

    /// Number of styles in this family.
    public var styleCount: Int {
        VisualStyle.allCases.filter { $0.family == self }.count
    }
}

// MARK: - Visual Style

/// All 406 visual styles available in ENVI templates.
/// Each style maps to exactly one family and carries metadata for template matching.
@available(iOS 26, *)
public enum VisualStyle: String, Codable, Sendable, CaseIterable, Hashable {
    case Minimal = "Minimal"
    case Clean = "Clean"
    case SwissGrid = "Swiss/Grid"
    case JapaneseWabiSabi = "Japanese (Wabi-Sabi)"
    case Scandinavian = "Scandinavian"
    case Bold = "Bold"
    case PopArt = "Pop Art"
    case Memphis = "Memphis"
    case StreetUrban = "Street/Urban"
    case Brutalist = "Brutalist"
    case Vintage = "Vintage"
    case RetroEightZeros = "Retro 80s"
    case RetroNineZeros = "Retro 90s"
    case ArtDeco = "Art Deco"
    case FilmPhotography = "Film Photography"
    case Editorial = "Editorial"
    case Magazine = "Magazine"
    case Lookbook = "Lookbook"
    case Luxury = "Luxury"
    case Corporate = "Corporate"
    case Moody = "Moody"
    case Dreamy = "Dreamy"
    case Cinematic = "Cinematic"
    case DarkAcademia = "Dark Academia"
    case Cottagecore = "Cottagecore"
    case Cyberpunk = "Cyberpunk"
    case YTwoKFuturism = "Y2K Futurism"
    case Glassmorphism = "Glassmorphism"
    case NeoBrutalism = "Neo-Brutalism"
    case Skeuomorphism = "Skeuomorphism"
    case Bohemian = "Bohemian"
    case Industrial = "Industrial"
    case Tropical = "Tropical"
    case Nordic = "Nordic"
    case DesertSouthwest = "Desert/Southwest"
    case Infographic = "Infographic"
    case Instructional = "Instructional"
    case SocialNative = "Social Native"
    case Bare = "Bare"
    case Naked = "Naked"
    case Stripped = "Stripped"
    case Essential = "Essential"
    case Pure = "Pure"
    case Void = "Void"
    case Monolith = "Monolith"
    case SingleElement = "Single Element"
    case NegativeSpaceDominant = "Negative Space Dominant"
    case TypographyOnly = "Typography Only"
    case Neon = "Neon"
    case Fluorescent = "Fluorescent"
    case Acid = "Acid"
    case DayGlo = "Day-Glo"
    case HighVis = "High Vis"
    case SafetyOrange = "Safety Orange"
    case WarningYellow = "Warning Yellow"
    case ToxicGreen = "Toxic Green"
    case ElectricBlue = "Electric Blue"
    case HotPink = "Hot Pink"
    case Victorian = "Victorian"
    case Edwardian = "Edwardian"
    case OneNineTwoZerosArtDeco = "1920s Art Deco"
    case OneNineThreeZerosHollywood = "1930s Hollywood"
    case OneNineFourZerosNoir = "1940s Noir"
    case OneNineFiveZerosKitsch = "1950s Kitsch"
    case OneNineSixZerosPsychedelic = "1960s Psychedelic"
    case OneNineSevenZerosDisco = "1970s Disco"
    case TwoZeroZeroZerosYTwoK = "2000s Y2K"
    case TwoZeroOneZerosTumblr = "2010s Tumblr"
    case Solarpunk = "Solarpunk"
    case Steampunk = "Steampunk"
    case Dieselpunk = "Dieselpunk"
    case Biopunk = "Biopunk"
    case Atompunk = "Atompunk"
    case RaygunGothic = "Raygun Gothic"
    case Afropunk = "Afropunk"
    case Coralpunk = "Coralpunk"
    case Lunarpunk = "Lunarpunk"
    case DataMosh = "Data Mosh"
    case GlitchArt = "Glitch Art"
    case Vaporwave = "Vaporwave"
    case Seapunk = "Seapunk"
    case Webcore = "Webcore"
    case FlatDesign = "Flat Design"
    case MaterialDesign = "Material Design"
    case FluentDesign = "Fluent Design"
    case Cupertino = "Cupertino"
    case Neumorphism = "Neumorphism"
    case KPop = "K-Pop"
    case JPop = "J-Pop"
    case CPop = "C-Pop"
    case Bollywood = "Bollywood"
    case Nollywood = "Nollywood"
    case KDrama = "K-Drama"
    case Anime = "Anime"
    case Manga = "Manga"
    case Manhwa = "Manhwa"
    case Webtoon = "Webtoon"
    case Afrofuturism = "Afrofuturism"
    case BlackTwitter = "Black Twitter"
    case Chicano = "Chicano"
    case Lowrider = "Lowrider"
    case Paisley = "Paisley"
    case Bandana = "Bandana"
    case Hauntology = "Hauntology"
    case Weirdcore = "Weirdcore"
    case Traumacore = "Traumacore"
    case Dreamcore = "Dreamcore"
    case Clowncore = "Clowncore"
    case WeirdTwitter = "Weird Twitter"
    case Goblincore = "Goblincore"
    case Fairycore = "Fairycore"
    case Crowcore = "Crowcore"
    case Naturecore = "Naturecore"
    case Plantcore = "Plantcore"
    case LightAcademia = "Light Academia"
    case RomanticAcademia = "Romantic Academia"
    case ChaoticAcademia = "Chaotic Academia"
    case McBling = "McBling"
    case FrutigerAero = "Frutiger Aero"
    case FrutigerMetro = "Frutiger Metro"
    case WebTwoZeroAesthetic = "Web 2.0 Aesthetic"
    case Ethereal = "Ethereal"
    case Celestial = "Celestial"
    case Cosmic = "Cosmic"
    case Galactic = "Galactic"
    case Stellar = "Stellar"
    case Astral = "Astral"
    case Cozy = "Cozy"
    case Hygge = "Hygge"
    case Lagom = "Lagom"
    case Fika = "Fika"
    case Gezellig = "Gezellig"
    case Gemuetlich = "Gemuetlich"
    case Eerie = "Eerie"
    case Uncanny = "Uncanny"
    case Liminal = "Liminal"
    case Backrooms = "Backrooms"
    case LiminalSpace = "Liminal Space"
    case AnalogHorror = "Analog Horror"
    case Nostalgic = "Nostalgic"
    case Saudade = "Saudade"
    case Mononoaware = "Mono no aware"
    case Wabisabi = "Wabi-sabi"
    case Yuugen = "Yuu-gen"
    case Monochrome = "Monochrome"
    case Duotone = "Duotone"
    case Gradient = "Gradient"
    case Ombre = "Ombre"
    case Rainbow = "Rainbow"
    case Pastel = "Pastel"
    case Earthy = "Earthy"
    case JewelTone = "Jewel Tone"
    case Metallic = "Metallic"
    case Iridescent = "Iridescent"
    case Holographic = "Holographic"
    case Chrome = "Chrome"
    case Matte = "Matte"
    case Glossy = "Glossy"
    case Satin = "Satin"
    case Velvet = "Velvet"
    case SerifForward = "Serif-Forward"
    case SansDominant = "Sans-Dominant"
    case ScriptHeavy = "Script-Heavy"
    case DisplayType = "Display Type"
    case MonoTypewriter = "Mono/Typewriter"
    case Handwritten = "Handwritten"
    case GraffitiType = "Graffiti Type"
    case RetroFont = "Retro Font"
    case Symmetrical = "Symmetrical"
    case Asymmetrical = "Asymmetrical"
    case Diagonal = "Diagonal"
    case Radial = "Radial"
    case GridBased = "Grid-Based"
    case Layered = "Layered"
    case Overlapping = "Overlapping"
    case Collage = "Collage"
    case Mosaic = "Mosaic"
    case Tiled = "Tiled"
    case Grainy = "Grainy"
    case Smooth = "Smooth"
    case Gritty = "Gritty"
    case Raw = "Raw"
    case Polished = "Polished"
    case Distressed = "Distressed"
    case Worn = "Worn"
    case Pristine = "Pristine"
    case Organic = "Organic"
    case Synthetic = "Synthetic"
    case Natural = "Natural"
    case Manufactured = "Manufactured"
    case HighKey = "High Key"
    case LowKey = "Low Key"
    case Chiaroscuro = "Chiaroscuro"
    case Rembrandt = "Rembrandt"
    case Butterfly = "Butterfly"
    case Split = "Split"
    case Loop = "Loop"
    case Backlit = "Backlit"
    case Silhouette = "Silhouette"
    case GoldenHour = "Golden Hour"
    case BlueHour = "Blue Hour"
    case Overcast = "Overcast"
    case Studio = "Studio"
    case NaturalLight = "Natural Light"
    case PracticalLight = "Practical Light"
    case Static = "Static"
    case SlowMotion = "Slow Motion"
    case Timelapse = "Time-lapse"
    case Hyperlapse = "Hyperlapse"
    case StopMotion = "Stop Motion"
    case MotionGraphics = "Motion Graphics"
    case KineticType = "Kinetic Type"
    case Parallax = "Parallax"
    case ScrollLinked = "Scroll-Linked"
    case DataVisualization = "Data Visualization"
    case ScientificIllustration = "Scientific Illustration"
    case TechnicalDrawing = "Technical Drawing"
    case Blueprint = "Blueprint"
    case PatentDrawing = "Patent Drawing"
    case IKEAStyle = "IKEA-Style"
    case LEGOStyle = "LEGO-Style"
    case RecipeCard = "Recipe Card"
    case Pattern = "Pattern"
    case SewingPattern = "Sewing Pattern"
    case Lofi = "Lo-fi"
    case ASMR = "ASMR"
    case WhiteNoise = "White Noise"
    case Ambient = "Ambient"
    case Synthwave = "Synthwave"
    case DrumandBass = "Drum and Bass"
    case JazzAge = "Jazz Age"
    case Classical = "Classical"
    case Orchestral = "Orchestral"
    case Electronic = "Electronic"
    case Acoustic = "Acoustic"
    case Mediterranean = "Mediterranean"
    case Desert = "Desert"
    case Arctic = "Arctic"
    case Jungle = "Jungle"
    case Urban = "Urban"
    case Rural = "Rural"
    case Coastal = "Coastal"
    case Mountain = "Mountain"
    case Savanna = "Savanna"
    case Tundra = "Tundra"
    case SpringFresh = "Spring Fresh"
    case SummerVibes = "Summer Vibes"
    case AutumnWarmth = "Autumn Warmth"
    case WinterCozy = "Winter Cozy"
    case HolidaySpirit = "Holiday Spirit"
    case NewYearFresh = "New Year Fresh"
    case ValentineRomantic = "Valentine Romantic"
    case HalloweenSpooky = "Halloween Spooky"
    case Medical = "Medical"
    case Legal = "Legal"
    case Financial = "Financial"
    case Educational = "Educational"
    case Scientific = "Scientific"
    case Engineering = "Engineering"
    case FashionEditorial = "Fashion Editorial"
    case FoodStylingStyle = "Food Styling"
    case Punk = "Punk"
    case Goth = "Goth"
    case Emo = "Emo"
    case Scene = "Scene"
    case Prep = "Prep"
    case Hipster = "Hipster"
    case Normcore = "Normcore"
    case HealthGoth = "Health Goth"
    case PastelGoth = "Pastel Goth"
    case CyberGoth = "Cyber Goth"
    case Botanical = "Botanical"
    case Floral = "Floral"
    case Fauna = "Fauna"
    case Marine = "Marine"
    case Geological = "Geological"
    case Meteorological = "Meteorological"
    case Astronomical = "Astronomical"
    case Microscopic = "Microscopic"
    case Macroscopic = "Macroscopic"
    case BrutalistArchitecture = "Brutalist Architecture"
    case Bauhaus = "Bauhaus"
    case DeStijl = "De Stijl"
    case ArtNouveau = "Art Nouveau"
    case GothicRevival = "Gothic Revival"
    case MidCenturyModern = "Mid-Century Modern"
    case Postmodern = "Postmodern"
    case Parametric = "Parametric"
    case DarkandMoodyFood = "Dark and Moody Food"
    case BrightandAiryFood = "Bright and Airy Food"
    case RusticFood = "Rustic Food"
    case MinimalistFood = "Minimalist Food"
    case OverheadFood = "Overhead Food"
    case FourFiveDegreeFood = "45-Degree Food"
    case MacroFood = "Macro Food"
    case ActionSports = "Action Sports"
    case ExtremeSports = "Extreme Sports"
    case EnduranceSports = "Endurance Sports"
    case TeamSports = "Team Sports"
    case IndividualSports = "Individual Sports"
    case CombatSports = "Combat Sports"
    case WaterSports = "Water Sports"
    case WinterSports = "Winter Sports"
    case Documentary = "Documentary"
    case Photojournalism = "Photojournalism"
    case Street = "Street"
    case Portrait = "Portrait"
    case Fashion = "Fashion"
    case Landscape = "Landscape"
    case Wildlife = "Wildlife"
    case Astrophotography = "Astrophotography"
    case Underwater = "Underwater"
    case Aerial = "Aerial"
    case Drone = "Drone"
    case Infrared = "Infrared"
    case Pinhole = "Pinhole"
    case Lomography = "Lomography"
    case Polaroid = "Polaroid"
    case Experimental = "Experimental"
    case Narrative = "Narrative"
    case MusicVideo = "Music Video"
    case Commercial = "Commercial"
    case TitleSequence = "Title Sequence"
    case CreditsRoll = "Credits Roll"
    case Broll = "B-roll"
    case Aroll = "A-roll"
    case Montage = "Montage"
    case Risograph = "Risograph"
    case ScreenPrint = "Screen Print"
    case Letterpress = "Letterpress"
    case Offset = "Offset"
    case DigitalPrint = "Digital Print"
    case Zine = "Zine"
    case Pamphlet = "Pamphlet"
    case Broadsheet = "Broadsheet"
    case Tabloid = "Tabloid"
    case Broadside = "Broadside"
    case PixelArt = "Pixel Art"
    case VoxelArt = "Voxel Art"
    case Vector = "Vector"
    case Raster = "Raster"
    case SVG = "SVG"
    case CSSArt = "CSS Art"
    case ShaderArt = "Shader Art"
    case Generative = "Generative"
    case Procedural = "Procedural"
    case AIGenerated = "AI-Generated"
    case NeuralStyle = "Neural Style"
    case GANArt = "GAN Art"
    case DiffusionArt = "Diffusion Art"
    case PromptAesthetic = "Prompt Aesthetic"
    case PostDigital = "Post-Digital"
    case Metaverse = "Metaverse"
    case Virtual = "Virtual"
    case Augmented = "Augmented"
    case MixedReality = "Mixed Reality"
    case Haptic = "Haptic"
    case Spatial = "Spatial"
    case Immersive = "Immersive"
    case Interactive = "Interactive"
    case Responsive = "Responsive"
    case Joyful = "Joyful"
    case Melancholic = "Melancholic"
    case Angry = "Angry"
    case Calm = "Calm"
    case Energetic = "Energetic"
    case Peaceful = "Peaceful"
    case Tense = "Tense"
    case Relaxed = "Relaxed"
    case Serious = "Serious"
    case Playful = "Playful"
    case Intimate = "Intimate"
    case Distant = "Distant"
    case Surreal = "Surreal"
    case Abstract = "Abstract"
    case Conceptual = "Conceptual"
    case MinimalConcept = "Minimal Concept"
    case Maximalist = "Maximalist"
    case Deconstructivist = "Deconstructivist"
    case Constructivist = "Constructivist"
    case Dada = "Dada"
    case Fluxus = "Fluxus"
    case Paper = "Paper"
    case Fabric = "Fabric"
    case Metal = "Metal"
    case Wood = "Wood"
    case Stone = "Stone"
    case Glass = "Glass"
    case Plastic = "Plastic"
    case Ceramic = "Ceramic"
    case Leather = "Leather"
    case Concrete = "Concrete"
    case Marble = "Marble"
    case Granite = "Granite"
    case Terrazzo = "Terrazzo"

    /// The family this style belongs to.
    public var family: VisualStyleFamily {
        switch self {
        case .Minimal, .Clean, .SwissGrid, .JapaneseWabiSabi, .Scandinavian,
            .Bold, .PopArt, .Memphis, .StreetUrban, .Brutalist, .Vintage,
            .RetroEightZeros, .RetroNineZeros, .ArtDeco, .FilmPhotography,
            .Editorial, .Magazine, .Lookbook, .Luxury, .Corporate, .Moody,
            .Dreamy, .Cinematic, .DarkAcademia, .Cottagecore, .Cyberpunk,
            .YTwoKFuturism, .Glassmorphism, .NeoBrutalism, .Skeuomorphism,
            .Bohemian, .Industrial, .Tropical, .Nordic, .DesertSouthwest,
            .Infographic, .Instructional, .SocialNative:
            return .OriginalBase

        case .Bare, .Naked, .Stripped, .Essential, .Pure, .Void, .Monolith,
            .SingleElement, .NegativeSpaceDominant, .TypographyOnly:
            return .CleanAndMinimal

        case .Neon, .Fluorescent, .Acid, .DayGlo, .HighVis, .SafetyOrange,
            .WarningYellow, .ToxicGreen, .ElectricBlue, .HotPink:
            return .BoldAndGraphic

        case .Victorian, .Edwardian, .OneNineTwoZerosArtDeco, .OneNineThreeZerosHollywood,
            .OneNineFourZerosNoir, .OneNineFiveZerosKitsch, .OneNineSixZerosPsychedelic,
            .OneNineSevenZerosDisco, .TwoZeroZeroZerosYTwoK, .TwoZeroOneZerosTumblr:
            return .VintagebyEra

        case .Solarpunk, .Steampunk, .Dieselpunk, .Biopunk, .Atompunk, .RaygunGothic,
            .Afropunk, .Coralpunk, .Lunarpunk, .DataMosh, .GlitchArt, .Vaporwave,
            .Seapunk, .Webcore:
            return .ModernDigital

        case .FlatDesign, .MaterialDesign, .FluentDesign, .Cupertino, .Neumorphism:
            return .UIUXStyles

        case .KPop, .JPop, .CPop, .Bollywood, .Nollywood, .KDrama,
            .Anime, .Manga, .Manhwa, .Webtoon:
            return .Cultural

        case .Afrofuturism, .BlackTwitter, .Chicano, .Lowrider,
            .Paisley, .Bandana, .Hauntology, .Weirdcore, .Traumacore,
            .Dreamcore, .Clowncore:
            return .InternetAesthetics

        case .WeirdTwitter, .Goblincore, .Fairycore, .Crowcore, .Naturecore,
            .Plantcore, .LightAcademia, .RomanticAcademia, .ChaoticAcademia,
            .McBling, .FrutigerAero, .FrutigerMetro, .WebTwoZeroAesthetic,
            .Ethereal, .Celestial, .Cosmic, .Galactic, .Stellar, .Astral:
            return .MoodAndAtmosphere

        case .Cozy, .Hygge, .Lagom, .Fika, .Gezellig, .Gemuetlich,
            .Eerie, .Uncanny, .Liminal, .Backrooms, .LiminalSpace,
            .AnalogHorror, .Nostalgic, .Saudade, .Mononoaware:
            return .ColorFocused

        case .Wabisabi, .Yuugen, .Monochrome, .Duotone, .Gradient, .Ombre:
            return .Typography

        case .Rainbow, .Pastel, .Earthy, .JewelTone, .Metallic, .Iridescent,
            .Holographic, .Chrome, .Matte:
            return .Composition

        case .Glossy, .Satin, .Velvet, .SerifForward, .SansDominant, .ScriptHeavy,
            .DisplayType, .MonoTypewriter, .Handwritten, .GraffitiType,
            .RetroFont, .Symmetrical:
            return .Texture

        case .Asymmetrical, .Diagonal, .Radial, .GridBased, .Layered, .Overlapping,
            .Collage, .Mosaic, .Tiled, .Grainy, .Smooth, .Gritty, .Raw,
            .Polished, .Distressed, .Worn, .Pristine:
            return .Lighting

        case .Organic, .Synthetic, .Natural, .Manufactured:
            return .Motion

        case .HighKey, .LowKey, .Chiaroscuro, .Rembrandt, .Butterfly, .Split,
            .Loop, .Backlit, .Silhouette:
            return .Functional

        case .GoldenHour, .BlueHour, .Overcast, .Studio, .NaturalLight, .PracticalLight:
            return .SoundAssociated

        case .Static, .SlowMotion, .Timelapse, .Hyperlapse, .StopMotion, .MotionGraphics,
            .KineticType, .Parallax, .ScrollLinked:
            return .RegionalGeographic

        case .DataVisualization, .ScientificIllustration, .TechnicalDrawing, .Blueprint,
            .PatentDrawing:
            return .Seasonal

        case .IKEAStyle, .LEGOStyle, .RecipeCard, .Pattern, .SewingPattern:
            return .ProfessionalIndustry

        case .Lofi, .ASMR, .WhiteNoise, .Ambient, .Synthwave, .DrumandBass,
            .JazzAge, .Classical, .Orchestral, .Electronic, .Acoustic:
            return .Subculture

        case .Mediterranean, .Desert, .Arctic, .Jungle, .Urban, .Rural,
            .Coastal, .Mountain, .Savanna, .Tundra:
            return .NatureInspired

        case .SpringFresh, .SummerVibes, .AutumnWarmth, .WinterCozy,
            .HolidaySpirit, .NewYearFresh, .ValentineRomantic, .HalloweenSpooky:
            return .Architectural

        case .Medical, .Legal, .Financial, .Educational, .Scientific,
            .Engineering, .FashionEditorial, .FoodStylingStyle:
            return .FoodStyling

        case .Punk, .Goth, .Emo, .Scene, .Prep, .Hipster, .Normcore,
            .HealthGoth, .PastelGoth, .CyberGoth:
            return .Sports

        case .Botanical, .Floral, .Fauna, .Marine, .Geological, .Meteorological,
            .Astronomical, .Microscopic, .Macroscopic:
            return .PhotographyGenres

        case .BrutalistArchitecture, .Bauhaus, .DeStijl, .ArtNouveau,
            .GothicRevival, .MidCenturyModern, .Postmodern, .Parametric:
            return .VideoGenres

        case .DarkandMoodyFood, .BrightandAiryFood, .RusticFood, .MinimalistFood,
            .OverheadFood, .FourFiveDegreeFood, .MacroFood:
            return .PrintAnalog

        case .ActionSports, .ExtremeSports, .EnduranceSports, .TeamSports,
            .IndividualSports, .CombatSports, .WaterSports, .WinterSports:
            return .DigitalNative

        case .Documentary, .Photojournalism, .Street, .Portrait, .Fashion,
            .Landscape, .Wildlife, .Astrophotography, .Underwater, .Aerial,
            .Drone, .Infrared, .Pinhole, .Lomography, .Polaroid:
            return .FutureForward

        case .Experimental, .Narrative, .MusicVideo, .Commercial:
            return .EmotionalTone

        case .TitleSequence, .CreditsRoll, .Broll, .Aroll, .Montage:
            return .Conceptual

        case .Risograph, .ScreenPrint, .Letterpress, .Offset, .DigitalPrint,
            .Zine, .Pamphlet, .Broadsheet, .Tabloid, .Broadside:
            return .Material

        case .PixelArt, .VoxelArt, .Vector, .Raster, .SVG, .CSSArt, .ShaderArt,
            .Generative, .Procedural, .AIGenerated, .NeuralStyle, .GANArt,
            .DiffusionArt, .PromptAesthetic, .PostDigital, .Metaverse, .Virtual,
            .Augmented, .MixedReality, .Haptic, .Spatial, .Immersive, .Interactive,
            .Responsive:
            return .Material

        case .Joyful, .Melancholic, .Angry, .Calm, .Energetic, .Peaceful,
            .Tense, .Relaxed, .Serious, .Playful, .Intimate, .Distant,
            .Surreal, .Abstract, .Conceptual, .MinimalConcept, .Maximalist,
            .Deconstructivist, .Constructivist, .Dada, .Fluxus:
            return .Material

        case .Paper, .Fabric, .Metal, .Wood, .Stone, .Glass, .Plastic, .Ceramic,
            .Leather, .Concrete, .Marble, .Granite, .Terrazzo:
            return .Material
        }
    }

    /// Canonical ID for CDN lookup and template matching.
    public var canonicalID: String {
        rawValue.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }

    /// Short descriptive blurb for UI display.
    public var displayDescription: String {
        switch self {
        case .Minimal: return "Less is more — clean lines, essential elements"
        case .Clean: return "Uncluttered, clear visual hierarchy"
        case .Cinematic: return "Wide-frame drama with film-like color grading"
        case .Cyberpunk: return "Neon-lit dystopian futurism"
        case .Vintage: return "Time-warmed nostalgia with grain and patina"
        case .Brutalist: return "Raw, honest, unapologetically bold"
        case .DarkAcademia: return "Scholarly moodiness, libraries and tweed"
        case .Cottagecore: return "Rural idyll — soft, warm, pastoral"
        case .Glassmorphism: return "Frosted glass with subtle translucency"
        case .NeoBrutalism: return "Modern raw design with bold borders"
        case .YTwoKFuturism: return "Millennium-era chrome and optimism"
        case .Editorial: return "High-fashion magazine aesthetic"
        case .Luxury: return "Premium feel, refined details"
        case .Moody: return "Deep shadows, atmospheric, emotive"
        case .Dreamy: return "Soft focus, ethereal, otherworldly"
        default: return "A distinct visual aesthetic for your content"
        }
    }
}

// MARK: - Style Model

/// Full style descriptor with metadata for template matching and UI rendering.
@available(iOS 26, *)
public struct StyleModel: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let style: VisualStyle
    public let family: VisualStyleFamily
    public let description: String
    public let colorPaletteHints: [String]
    public let typographyHints: [String]
    public let compositionHints: [String]
    public let textureHints: [String]
    public let motionHints: [String]?
    public let platformAffinity: [Platform]

    public init(
        style: VisualStyle,
        description: String = "",
        colorPaletteHints: [String] = [],
        typographyHints: [String] = [],
        compositionHints: [String] = [],
        textureHints: [String] = [],
        motionHints: [String]? = nil,
        platformAffinity: [Platform] = [.instagram, .tiktok, .youtubeShorts]
    ) {
        self.id = style.canonicalID
        self.style = style
        self.family = style.family
        self.description = description.isEmpty ? style.displayDescription : description
        self.colorPaletteHints = colorPaletteHints
        self.typographyHints = typographyHints
        self.compositionHints = compositionHints
        self.textureHints = textureHints
        self.motionHints = motionHints
        self.platformAffinity = platformAffinity
    }
}

// MARK: - Platform

@available(iOS 26, *)
public enum Platform: String, Codable, Sendable, CaseIterable, Hashable {
    case instagram = "instagram"
    case tiktok = "tiktok"
    case youtubeShorts = "youtube_shorts"
    case snapchat = "snapchat"
    case threads = "threads"
    case bluesky = "bluesky"
    case twitter = "twitter"
    case pinterest = "pinterest"
    case linkedin = "linkedin"
    case general = "general"
}

// MARK: - Style Compatibility Matrix

/// Pre-computed compatibility scores between content archetypes and visual styles.
/// Returns a score from 0.0 (incompatible) to 1.0 (perfect match).
///
/// Usage:
/// ```swift
/// let score = StyleCompatibilityMatrix.score(archetype: .photo(.P1), style: .Minimal)
/// ```
@available(iOS 26, *)
public enum StyleCompatibilityMatrix: Sendable {

    // MARK: Public API

    /// Returns the compatibility score between an archetype and a visual style.
    /// - Parameters:
    ///   - archetype: The content archetype (e.g., `.photo(.P1)`)
    ///   - style: The visual style to evaluate
    /// - Returns: A score from 0.0 to 1.0
    public static func score(archetype: String, style: VisualStyle) -> Double {
        // Use pre-computed lookup table for O(1) access
        let key = "\(archetype)_\(style.canonicalID)"
        if let cached = _precomputed[key] {
            return cached
        }
        // Fallback: compute from family affinity rules
        return _computeFallback(archetype: archetype, style: style)
    }

    /// Returns all styles compatible with the given archetype, sorted by score descending.
    /// - Parameters:
    ///   - archetype: The content archetype
    ///   - threshold: Minimum score to include (default 0.3)
    ///   - limit: Maximum number of results (default 20)
    /// - Returns: Array of (style, score) tuples
    public static func compatibleStyles(
        forArchetype archetype: String,
        threshold: Double = 0.3,
        limit: Int = 20
    ) -> [(style: VisualStyle, score: Double)] {
        VisualStyle.allCases
            .map { (style: $0, score: score(archetype: archetype, style: $0)) }
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    /// Returns styles within a specific family compatible with the archetype.
    public static func compatibleStyles(
        forArchetype archetype: String,
        inFamily family: VisualStyleFamily,
        threshold: Double = 0.3,
        limit: Int = 10
    ) -> [(style: VisualStyle, score: Double)] {
        VisualStyle.allCases
            .filter { $0.family == family }
            .map { (style: $0, score: score(archetype: archetype, style: $0)) }
            .filter { $0.score >= threshold }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: Family-Affinity Scoring Rules

    /// Base affinity scores between format types and style families.
    /// Higher values mean the family tends to work well with that format.
    private static let _formatFamilyAffinity: [String: [VisualStyleFamily: Double]] = [
        "photo": [
            .CleanAndMinimal: 0.9,
            .OriginalBase: 0.85,
            .Lighting: 0.8,
            .Texture: 0.75,
            .Composition: 0.7,
            .Material: 0.65,
            .Typography: 0.6,
            .BoldAndGraphic: 0.55,
            .MoodAndAtmosphere: 0.7,
            .PhotographyGenres: 0.9,
            .VintagebyEra: 0.65,
            .ColorFocused: 0.6,
            .Functional: 0.5,
            .NatureInspired: 0.55,
            .PrintAnalog: 0.6,
        ],
        "carousel": [
            .CleanAndMinimal: 0.85,
            .OriginalBase: 0.8,
            .Typography: 0.8,
            .Composition: 0.75,
            .BoldAndGraphic: 0.7,
            .Functional: 0.7,
            .ModernDigital: 0.65,
            .UIUXStyles: 0.7,
            .ColorFocused: 0.6,
            .Material: 0.55,
            .ProfessionalIndustry: 0.65,
        ],
        "video": [
            .OriginalBase: 0.85,
            .Motion: 0.9,
            .Cinematic: 0.9,
            .ModernDigital: 0.75,
            .BoldAndGraphic: 0.7,
            .EmotionalTone: 0.8,
            .DigitalNative: 0.75,
            .FutureForward: 0.7,
            .SoundAssociated: 0.65,
            .VideoGenres: 0.85,
            .Subculture: 0.65,
            .Material: 0.6,
        ],
        "story": [
            .OriginalBase: 0.8,
            .BoldAndGraphic: 0.75,
            .ModernDigital: 0.7,
            .DigitalNative: 0.8,
            .InternetAesthetics: 0.75,
            .MoodAndAtmosphere: 0.7,
            .EmotionalTone: 0.65,
            .Motion: 0.7,
            .ColorFocused: 0.65,
        ],
        "newFormat": [
            .FutureForward: 0.85,
            .ModernDigital: 0.8,
            .DigitalNative: 0.75,
            .InternetAesthetics: 0.7,
            .OriginalBase: 0.65,
            .Material: 0.6,
        ],
    ]

    // MARK: Pre-computed Lookup Table

    /// Hot-path cache for frequently-used archetype x style combinations.
    /// Populated at runtime from CDN bundles or local seed data.
    private static var _precomputed: [String: Double] = [
        // Photo archetypes x popular styles (seed data)
        "P1_Minimal": 0.95,
        "P1_Clean": 0.9,
        "P1_Cinematic": 0.7,
        "P1_Editorial": 0.85,
        "P1_Luxury": 0.8,
        "P2_Minimal": 0.85,
        "P2_Editorial": 0.95,
        "P2_Cinematic": 0.8,
        "P3_Minimal": 0.9,
        "P3_Clean": 0.85,
        "P3_Infographic": 0.8,
        "P6_Bold": 0.75,
        "P6_Clean": 0.7,
        "P7_TypographyOnly": 0.95,
        "P7_SerifForward": 0.85,
        "P8_Luxury": 0.9,
        "P8_Minimal": 0.85,
        "P8_Corporate": 0.75,
        "P10_Memphis": 0.85,
        "P10_PopArt": 0.8,
        "P14_Cinematic": 0.95,
        "P14_Moody": 0.9,
        "P14_DarkAcademia": 0.75,
        // Video archetypes x popular styles (seed data)
        "V1_Bold": 0.85,
        "V1_Clean": 0.7,
        "V3_Cinematic": 0.9,
        "V3_Dramatic": 0.85,
        "V5_Cyberpunk": 0.8,
        "V5_Vaporwave": 0.75,
        "V6_Minimal": 0.8,
        "V6_Clean": 0.75,
        "V14_Ambient": 0.9,
        "V14_Lofi": 0.85,
        "V14_ASMR": 0.95,
        // Carousel archetypes x popular styles
        "C1_Instructional": 0.9,
        "C1_Clean": 0.85,
        "C1_Minimal": 0.8,
        "C7_Infographic": 0.85,
        "C7_DataVisualization": 0.9,
        "C10_Clean": 0.8,
        "C10_MinimalistFood": 0.85,
    ]

    // MARK: Fallback Computation

    /// Computes a compatibility score using family-affinity rules when no cached value exists.
    private static func _computeFallback(archetype: String, style: VisualStyle) -> Double {
        // Determine format from archetype prefix
        let format: String
        if archetype.hasPrefix("P") {
            format = "photo"
        } else if archetype.hasPrefix("C") {
            format = "carousel"
        } else if archetype.hasPrefix("V") {
            format = "video"
        } else if archetype.hasPrefix("S") {
            format = "story"
        } else if archetype.hasPrefix("N") {
            format = "newFormat"
        } else {
            format = "photo" // default fallback
        }

        guard let affinities = _formatFamilyAffinity[format] else { return 0.5 }

        // Get base family affinity score
        let baseScore = affinities[style.family] ?? 0.5

        // Apply style-specific modifiers
        let modifier = _styleSpecificModifier(archetype: archetype, style: style)

        return min(1.0, max(0.0, baseScore + modifier))
    }

    /// Applies style-specific heuristics that override base family affinity.
    private static func _styleSpecificModifier(archetype: String, style: VisualStyle) -> Double {
        // Photo-specific overrides
        if archetype.hasPrefix("P") {
            switch style {
            case .Minimal, .Clean, .Editorial, .Luxury: return 0.1
            case .TypographyOnly: return -0.3 // text-heavy styles don't suit single photos well
            case .Cinematic: return archetype == "P14" ? 0.15 : 0.0
            case .Instructional: return -0.2
            default: return 0.0
            }
        }

        // Carousel-specific overrides
        if archetype.hasPrefix("C") {
            switch style {
            case .Clean, .Instructional, .DataVisualization, .Infographic: return 0.1
            case .Cinematic: return -0.1 // cinematic styles don't work well across carousel cards
            default: return 0.0
            }
        }

        // Video-specific overrides
        if archetype.hasPrefix("V") {
            switch style {
            case .Cinematic, .Moody, .Dreamy: return 0.1
            case .DataVisualization: return -0.15
            case .Minimal: return archetype == "V6" ? 0.1 : 0.0
            default: return 0.0
            }
        }

        return 0.0
    }

    // MARK: Integration with VideoTemplate

    /// Returns style compatibility data suitable for integration with the
    /// TemplateRegistry and VideoTemplate matching pipeline.
    ///
    /// This bridges the StyleModels taxonomy with the TemplateRegistry's
    /// TemplateDefinition lookup system.
    public struct TemplateStyleMatch: Sendable, Hashable {
        public let style: VisualStyle
        public let styleModel: StyleModel
        public let compatibilityScore: Double
        public let isRecommended: Bool

        public init(
            style: VisualStyle,
            styleModel: StyleModel,
            compatibilityScore: Double,
            isRecommended: Bool
        ) {
            self.style = style
            self.styleModel = styleModel
            self.compatibilityScore = compatibilityScore
            self.isRecommended = isRecommended
        }
    }

    /// Returns matched styles for a given template definition from the TemplateRegistry.
    /// This is the primary integration point between StyleModels and VideoTemplate.
    public static func matchedStyles(
        forTemplate templateID: String,
        archetypeID: String,
        threshold: Double = 0.4,
        limit: Int = 15
    ) -> [TemplateStyleMatch] {
        let matches = compatibleStyles(forArchetype: archetypeID, threshold: threshold, limit: limit)
        return matches.map { style, score in
            let styleModel = StyleModel(style: style)
            let recommended = score >= 0.7
            return TemplateStyleMatch(
                style: style,
                styleModel: styleModel,
                compatibilityScore: score,
                isRecommended: recommended
            )
        }
    }
}

// MARK: - Style Preset Groups

/// Commonly-used style groupings that can be applied as presets.
/// Useful for quick-select UI and template defaulting.
@available(iOS 26, *)
public enum StylePresetGroup: String, Codable, Sendable, CaseIterable {

    case safe = "Safe"
    case bold = "Bold"
    case artistic = "Artistic"
    case professional = "Professional"
    case trending = "Trending"
    case dark = "Dark"
    case light = "Light"
    case warm = "Warm"
    case cool = "Cool"

    /// Returns the styles in this preset group.
    public var styles: [VisualStyle] {
        switch self {
        case .safe:
            return [.Minimal, .Clean, .Scandinavian, .Corporate, .Polished]
        case .bold:
            return [.Bold, .PopArt, .Memphis, .Neon, .Brutalist, .NeoBrutalism]
        case .artistic:
            return [.Cinematic, .Moody, .Dreamy, .DarkAcademia, .Ethereal, .Surreal]
        case .professional:
            return [.Corporate, .Editorial, .Clean, .Minimal, .Luxury, .Infographic]
        case .trending:
            return [.Cyberpunk, .Glassmorphism, .YTwoKFuturism, .FrutigerAero, .McBling]
        case .dark:
            return [.DarkAcademia, .Moody, .OneNineFourZerosNoir, .LowKey, .Void, .Monolith]
        case .light:
            return [.Minimal, .Clean, .Scandinavian, .Pastel, .BrightandAiryFood, .HighKey]
        case .warm:
            return [.Vintage, .GoldenHour, .Earthy, .AutumnWarmth, .Tropical, .Bohemian]
        case .cool:
            return [.Cyberpunk, .Nordic, .BlueHour, .ElectricBlue, .Arctic, .Corporate]
        }
    }
}

// MARK: - Style Filter Options

/// Filter options for browsing styles in the StyleExplorerView and TemplateBrowserView.
@available(iOS 26, *)
public struct StyleFilterOptions: Sendable, Hashable {
    public var selectedFamily: VisualStyleFamily?
    public var selectedPresetGroup: StylePresetGroup?
    public var searchTerm: String?
    public var minCompatibilityScore: Double?
    public var excludeStyles: Set<VisualStyle>
    public var preferredStyles: Set<VisualStyle>

    public init(
        selectedFamily: VisualStyleFamily? = nil,
        selectedPresetGroup: StylePresetGroup? = nil,
        searchTerm: String? = nil,
        minCompatibilityScore: Double? = nil,
        excludeStyles: Set<VisualStyle> = [],
        preferredStyles: Set<VisualStyle> = []
    ) {
        self.selectedFamily = selectedFamily
        self.selectedPresetGroup = selectedPresetGroup
        self.searchTerm = searchTerm
        self.minCompatibilityScore = minCompatibilityScore
        self.excludeStyles = excludeStyles
        self.preferredStyles = preferredStyles
    }

    /// Apply filters to a list of styles and return the filtered, sorted result.
    public func apply(to styles: [VisualStyle]) -> [VisualStyle] {
        var result = styles

        // Filter by family
        if let family = selectedFamily {
            result = result.filter { $0.family == family }
        }

        // Filter by preset group
        if let preset = selectedPresetGroup {
            let presetStyles = Set(preset.styles)
            result = result.filter { presetStyles.contains($0) }
        }

        // Filter by search term
        if let term = searchTerm, !term.isEmpty {
            let lowercased = term.lowercased()
            result = result.filter {
                $0.rawValue.lowercased().contains(lowercased) ||
                $0.canonicalID.lowercased().contains(lowercased) ||
                $0.displayDescription.lowercased().contains(lowercased)
            }
        }

        // Filter by minimum compatibility score
        if let archetype = _archetypeContext, let minScore = minCompatibilityScore {
            result = result.filter {
                StyleCompatibilityMatrix.score(archetype: archetype, style: $0) >= minScore
            }
        }

        // Exclude specific styles
        result = result.filter { !excludeStyles.contains($0) }

        // Sort preferred styles first
        if !preferredStyles.isEmpty {
            result.sort { a, b in
                let aPreferred = preferredStyles.contains(a)
                let bPreferred = preferredStyles.contains(b)
                if aPreferred && !bPreferred { return true }
                if !aPreferred && bPreferred { return false }
                return false
            }
        }

        return result
    }

    // Context for compatibility scoring — set before applying filters.
    private static var _archetypeContext: String?

    public static func setArchetypeContext(_ archetypeID: String) {
        _archetypeContext = archetypeID
    }
}

// MARK: - VisualStyle Display Extensions

@available(iOS 26, *)
extension VisualStyle {
    /// Whether this style is suitable as a default for new templates.
    public var isGoodDefault: Bool {
        switch self {
        case .Minimal, .Clean, .Corporate, .Editorial: return true
        default: return false
        }
    }

    /// ENVI brand-aligned accent color for UI representation.
    /// Falls back to the family accent if no specific color is defined.
    public var uiAccentColor: ENVIColor {
        switch self {
        case .Minimal: return ENVIColor(hex: 0xF0F0F5)
        case .Clean: return ENVIColor(hex: 0xE0E0EA)
        case .Cinematic: return ENVIColor(hex: 0x7A56C4)
        case .Cyberpunk: return ENVIColor(hex: 0x00D4AA)
        case .Vintage: return ENVIColor(hex: 0xC4A882)
        case .Bold: return ENVIColor(hex: 0xFF3B30)
        case .DarkAcademia: return ENVIColor(hex: 0x5D3F96)
        case .Cottagecore: return ENVIColor(hex: 0x34C759)
        case .Luxury: return ENVIColor(hex: 0xC9A84C)
        case .Editorial: return ENVIColor(hex: 0xF0F0F5)
        case .Corporate: return ENVIColor(hex: 0x8E8E93)
        case .Moody: return ENVIColor(hex: 0x5856D6)
        case .Dreamy: return ENVIColor(hex: 0x64D2FF)
        case .Glassmorphism: return ENVIColor(hex: 0x5AC8FA)
        case .NeoBrutalism: return ENVIColor(hex: 0xFF9F0A)
        case .YTwoKFuturism: return ENVIColor(hex: 0x007AFF)
        default: return family.accentColor
        }
    }

    /// Whether this style uses ENVI's SpaceMono-Bold font as the primary typeface.
    public var usesBrandFont: Bool {
        switch self {
        case .Bold, .TypographyOnly, .DisplayType, .SerifForward, .SansDominant,
            .ScriptHeavy, .MonoTypewriter, .GraffitiType, .RetroFont,
            .Editorial, .Magazine, .Lookbook:
            return true
        default:
            return false
        }
    }
}

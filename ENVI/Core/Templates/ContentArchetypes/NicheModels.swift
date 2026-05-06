import Foundation

// MARK: - Content Niche Category
/// Top-level niche categories (40 categories, 1,235 individual niches)
public enum ContentNicheCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case Additional = "Additional"
    case ArtAndDesignExpanded = "Art & Design Expanded"
    case Automotive = "Automotive"
    case BeautyExpanded = "Beauty Expanded"
    case BusinessAndMarketing = "Business & Marketing"
    case CollectingAndHobbies = "Collecting & Hobbies"
    case CraftsAndMaking = "Crafts & Making"
    case EducationAndLearning = "Education & Learning"
    case EngineeringAndManufacturing = "Engineering & Manufacturing"
    case EventPlanning = "Event Planning"
    case FashionExpanded = "Fashion Expanded"
    case FinanceExpanded = "Finance Expanded"
    case FitnessExpanded = "Fitness Expanded"
    case FoodExpanded = "Food Expanded"
    case GamingAndEntertainment = "Gaming & Entertainment"
    case GamingExpanded = "Gaming Expanded"
    case HealthAndWellness = "Health & Wellness"
    case MediaAndBroadcasting = "Media & Broadcasting"
    case MentalHealthAndSpirituality = "Mental Health & Spirituality"
    case MilitaryAndEmergency = "Military & Emergency"
    case MusicExpanded = "Music Expanded"
    case OriginalBase = "Original Base"
    case ParentingExpanded = "Parenting Expanded"
    case PerformingArtsAndFilm = "Performing Arts & Film"
    case PetsExpanded = "Pets Expanded"
    case PoliticsAndEconomics = "Politics & Economics"
    case RealEstateAndHome = "Real Estate & Home"
    case ScienceAndNature = "Science & Nature"
    case SocialJusticeAndActivism = "Social Justice & Activism"
    case Sports = "Sports"
    case TechExpanded = "Tech Expanded"
    case TravelExpanded = "Travel Expanded"
    case WritingAndJournalism = "Writing & Journalism"
}

// MARK: - Content Niche
/// All 1,235 content niches available in ENVI templates
public enum ContentNiche: String, Codable, Sendable, CaseIterable, Hashable {
    case GeneralLifestyle = "General Lifestyle"
    case HomeAndInterior = "Home & Interior"
    case OrganizationAndProductivity = "Organization & Productivity"
    case Minimalism = "Minimalism"
    case SelfCareAndWellness = "Self-Care & Wellness"
    case Fashion = "Fashion"
    case Streetwear = "Streetwear"
    case BeautyAndMakeup = "Beauty & Makeup"
    case Skincare = "Skincare"
    case HairAndNails = "Hair & Nails"
    case FitnessAndGym = "Fitness & Gym"
    case YogaAndPilates = "Yoga & Pilates"
    case RunningAndCardio = "Running & Cardio"
    case NutritionAndDiet = "Nutrition & Diet"
    case MentalHealth = "Mental Health"
    case RecipesAndCooking = "Recipes & Cooking"
    case BakingAndDesserts = "Baking & Desserts"
    case HealthyEating = "Healthy Eating"
    case RestaurantReviews = "Restaurant Reviews"
    case CocktailsAndDrinks = "Cocktails & Drinks"
    case Travel = "Travel"
    case BudgetTravel = "Budget Travel"
    case LuxuryTravel = "Luxury Travel"
    case AdventureAndOutdoors = "Adventure & Outdoors"
    case VanLifeRV = "Van Life / RV"
    case TechnologyAndGadgets = "Technology & Gadgets"
    case SoftwareAndApps = "Software & Apps"
    case PersonalFinance = "Personal Finance"
    case Entrepreneurship = "Entrepreneurship"
    case Freelancing = "Freelancing"
    case Gaming = "Gaming"
    case MoviesAndTV = "Movies & TV"
    case Music = "Music"
    case BooksAndLiterature = "Books & Literature"
    case ComedyAndMemes = "Comedy & Memes"
    case EducationAndLearning = "Education & Learning"
    case ScienceAndFacts = "Science & Facts"
    case HistoryAndCulture = "History & Culture"
    case DIYAndCrafts = "DIY & Crafts"
    case ArtAndDesign = "Art & Design"
    case ParentingAndFamily = "Parenting & Family"
    case PetCare = "Pet Care"
    case CrossFit = "CrossFit"
    case Powerlifting = "Powerlifting"
    case OlympicLifting = "Olympic Lifting"
    case Bodybuilding = "Bodybuilding"
    case Calisthenics = "Calisthenics"
    case StreetWorkout = "Street Workout"
    case HathaYoga = "Hatha Yoga"
    case VinyasaYoga = "Vinyasa Yoga"
    case AshtangaYoga = "Ashtanga Yoga"
    case BikramYoga = "Bikram Yoga"
    case YinYoga = "Yin Yoga"
    case RestorativeYoga = "Restorative Yoga"
    case AerialYoga = "Aerial Yoga"
    case PilatesMat = "Pilates Mat"
    case ReformerPilates = "Reformer Pilates"
    case BarreFitness = "Barre Fitness"
    case HIIT = "HIIT"
    case Tabata = "Tabata"
    case CircuitTraining = "Circuit Training"
    case FunctionalFitness = "Functional Fitness"
    case MobilityTraining = "Mobility Training"
    case FlexibilityTraining = "Flexibility Training"
    case SprintTraining = "Sprint Training"
    case MarathonRunning = "Marathon Running"
    case TrailRunning = "Trail Running"
    case UltraRunning = "Ultra Running"
    case TrackAndField = "Track & Field"
    case OpenWaterSwimming = "Open Water Swimming"
    case PoolSwimming = "Pool Swimming"
    case RoadCycling = "Road Cycling"
    case MountainBiking = "Mountain Biking"
    case BMX = "BMX"
    case SpinClass = "Spin Class"
    case BrazilianJiuJitsu = "Brazilian Jiu-Jitsu"
    case MuayThai = "Muay Thai"
    case Boxing = "Boxing"
    case MMA = "MMA"
    case Karate = "Karate"
    case Taekwondo = "Taekwondo"
    case Judo = "Judo"
    case Capoeira = "Capoeira"
    case Zumba = "Zumba"
    case HipHopDanceFitness = "Hip-Hop Dance Fitness"
    case BalletFitness = "Ballet Fitness"
    case PostpartumFitness = "Postpartum Fitness"
    case SeniorFitness = "Senior Fitness"
    case AdaptiveFitness = "Adaptive Fitness"
    case YouthAthletics = "Youth Athletics"
    case SoccerTraining = "Soccer Training"
    case BasketballTraining = "Basketball Training"
    case TennisTraining = "Tennis Training"
    case GolfFitness = "Golf Fitness"
    case VolleyballTraining = "Volleyball Training"
    case RecoveryAndStretching = "Recovery & Stretching"
    case FoamRolling = "Foam Rolling"
    case SportsMassage = "Sports Massage"
    case Cryotherapy = "Cryotherapy"
    case SupplementReviews = "Supplement Reviews"
    case CompetitionPrep = "Competition Prep"
    case PhysiqueCoaching = "Physique Coaching"
    case WeightLoss = "Weight Loss"
    case MuscleGain = "Muscle Gain"
    case BodyRecomposition = "Body Recomposition"
    case MealPrepping = "Meal Prepping"
    case MacroTracking = "Macro Tracking"
    case ItalianCuisine = "Italian Cuisine"
    case FrenchCuisine = "French Cuisine"
    case JapaneseCuisine = "Japanese Cuisine"
    case KoreanCuisine = "Korean Cuisine"
    case ChineseCuisine = "Chinese Cuisine"
    case ThaiCuisine = "Thai Cuisine"
    case VietnameseCuisine = "Vietnamese Cuisine"
    case MexicanCuisine = "Mexican Cuisine"
    case IndianCuisine = "Indian Cuisine"
    case MiddleEasternCuisine = "Middle Eastern Cuisine"
    case MediterraneanCuisine = "Mediterranean Cuisine"
    case BBQAndSmoking = "BBQ & Smoking"
    case BreadBaking = "Bread Baking"
    case PastryMaking = "Pastry Making"
    case CakeDecorating = "Cake Decorating"
    case CookieBaking = "Cookie Baking"
    case PieMaking = "Pie Making"
    case VeganCooking = "Vegan Cooking"
    case VegetarianRecipes = "Vegetarian Recipes"
    case KetoRecipes = "Keto Recipes"
    case PaleoRecipes = "Paleo Recipes"
    case GlutenFreeBaking = "Gluten-Free Baking"
    case DairyFreeCooking = "Dairy-Free Cooking"
    case LowCarbMeals = "Low-Carb Meals"
    case MealPrep = "Meal Prep"
    case BatchCooking = "Batch Cooking"
    case OnePotMeals = "One-Pot Meals"
    case SheetPanDinners = "Sheet Pan Dinners"
    case AirFryerRecipes = "Air Fryer Recipes"
    case InstantPotRecipes = "Instant Pot Recipes"
    case SousVideCooking = "Sous Vide Cooking"
    case MolecularGastronomy = "Molecular Gastronomy"
    case Fermentation = "Fermentation"
    case CanningAndPreserving = "Canning & Preserving"
    case Foraging = "Foraging"
    case Butchery = "Butchery"
    case Charcuterie = "Charcuterie"
    case CheeseMaking = "Cheese Making"
    case WineTasting = "Wine Tasting"
    case MixologyAndCocktails = "Mixology & Cocktails"
    case CoffeeBrewing = "Coffee Brewing"
    case TeaCulture = "Tea Culture"
    case FoodPhotography = "Food Photography"
    case FoodStyling = "Food Styling"
    case RestaurantReviews = "Restaurant Reviews"
    case StreetFood = "Street Food"
    case FoodChallenges = "Food Challenges"
    case Mukbang = "Mukbang"
    case ASMREating = "ASMR Eating"
    case FoodScience = "Food Science"
    case NutritionScience = "Nutrition Science"
    case Dietetics = "Dietetics"
    case IntuitiveEating = "Intuitive Eating"
    case IntermittentFasting = "Intermittent Fasting"
    case PlantBasedDiet = "Plant-Based Diet"
    case HauteCouture = "Haute Couture"
    case ReadytoWear = "Ready-to-Wear"
    case FastFashion = "Fast Fashion"
    case SustainableFashion = "Sustainable Fashion"
    case ThriftAndVintage = "Thrift & Vintage"
    case StreetwearCulture = "Streetwear Culture"
    case Athleisure = "Athleisure"
    case Workwear = "Workwear"
    case BusinessCasual = "Business Casual"
    case FormalWear = "Formal Wear"
    case EveningWear = "Evening Wear"
    case BridalFashion = "Bridal Fashion"
    case MaternityFashion = "Maternity Fashion"
    case PlusSizeFashion = "Plus-Size Fashion"
    case PetiteFashion = "Petite Fashion"
    case TallFashion = "Tall Fashion"
    case GenderNeutralFashion = "Gender-Neutral Fashion"
    case KidsFashion = "Kids Fashion"
    case FashionAccessories = "Fashion Accessories"
    case JewelryDesign = "Jewelry Design"
    case WatchCollecting = "Watch Collecting"
    case HandbagReviews = "Handbag Reviews"
    case SneakerCulture = "Sneaker Culture"
    case HighHeels = "High Heels"
    case Boots = "Boots"
    case Sandals = "Sandals"
    case EyewearFashion = "Eyewear Fashion"
    case HatDesign = "Hat Design"
    case SeasonalFashion = "Seasonal Fashion"
    case TrendForecasting = "Trend Forecasting"
    case RunwayReviews = "Runway Reviews"
    case DesignerProfiles = "Designer Profiles"
    case FashionWeekCoverage = "Fashion Week Coverage"
    case ModelLifestyle = "Model Lifestyle"
    case StylingTips = "Styling Tips"
    case ColorTheoryinFashion = "Color Theory in Fashion"
    case WardrobePlanning = "Wardrobe Planning"
    case CapsuleWardrobe = "Capsule Wardrobe"
    case PersonalShopping = "Personal Shopping"
    case CustomTailoring = "Custom Tailoring"
    case DIYFashion = "DIY Fashion"
    case UpcyclingClothing = "Upcycling Clothing"
    case FashionIllustration = "Fashion Illustration"
    case FashionPhotography = "Fashion Photography"
    case FashionHistory = "Fashion History"
    case SubcultureFashion = "Subculture Fashion"
    case GothFashion = "Goth Fashion"
    case PunkFashion = "Punk Fashion"
    case PreppyStyle = "Preppy Style"
    case GrungeRevival = "Grunge Revival"
    case SkincareRoutines = "Skincare Routines"
    case AcneTreatment = "Acne Treatment"
    case AntiAgingSkincare = "Anti-Aging Skincare"
    case HyperpigmentationSolutions = "Hyperpigmentation Solutions"
    case SensitiveSkinCare = "Sensitive Skin Care"
    case OilySkinManagement = "Oily Skin Management"
    case DrySkinRemedies = "Dry Skin Remedies"
    case CombinationSkin = "Combination Skin"
    case KBeauty = "K-Beauty"
    case JBeauty = "J-Beauty"
    case CleanBeautyProducts = "Clean Beauty Products"
    case IndieBeautyBrands = "Indie Beauty Brands"
    case LuxuryBeauty = "Luxury Beauty"
    case DrugstoreBeauty = "Drugstore Beauty"
    case NaturalMakeup = "Natural Makeup"
    case GlamMakeup = "Glam Makeup"
    case EditorialMakeup = "Editorial Makeup"
    case BridalMakeup = "Bridal Makeup"
    case SpecialEffectsMakeup = "Special Effects Makeup"
    case EyeshadowTutorials = "Eyeshadow Tutorials"
    case ContouringTechniques = "Contouring Techniques"
    case HighlightingTips = "Highlighting Tips"
    case BrowGrooming = "Brow Grooming"
    case LashExtensions = "Lash Extensions"
    case LipstickReviews = "Lipstick Reviews"
    case NailArtDesign = "Nail Art Design"
    case GelNails = "Gel Nails"
    case AcrylicNails = "Acrylic Nails"
    case DipPowderNails = "Dip Powder Nails"
    case PressOnNails = "Press-On Nails"
    case HairCareRoutines = "Hair Care Routines"
    case HairColoring = "Hair Coloring"
    case Balayage = "Balayage"
    case Highlights = "Highlights"
    case HairExtensions = "Hair Extensions"
    case WigReviews = "Wig Reviews"
    case BraidingHairstyles = "Braiding Hairstyles"
    case LocsCare = "Locs Care"
    case NaturalHairJourney = "Natural Hair Journey"
    case CurlyHairCare = "Curly Hair Care"
    case StraightHairTips = "Straight Hair Tips"
    case WavyHairStyling = "Wavy Hair Styling"
    case ThinningHairSolutions = "Thinning Hair Solutions"
    case ScalpCare = "Scalp Care"
    case FragranceReviews = "Fragrance Reviews"
    case BodyCare = "Body Care"
    case SelfTanning = "Self-Tanning"
    case HairRemoval = "Hair Removal"
    case WellnessBeauty = "Wellness Beauty"
    case InnerBeauty = "Inner Beauty"
    case SoloTravel = "Solo Travel"
    case CouplesTravel = "Couples Travel"
    case FamilyTravel = "Family Travel"
    case GroupTravel = "Group Travel"
    case BudgetBackpacking = "Budget Backpacking"
    case LuxuryTravel = "Luxury Travel"
    case AdventureTravel = "Adventure Travel"
    case CulturalImmersion = "Cultural Immersion"
    case FoodTourism = "Food Tourism"
    case WellnessRetreats = "Wellness Retreats"
    case DigitalNomadLife = "Digital Nomad Life"
    case VanLife = "Van Life"
    case RVLiving = "RV Living"
    case SailboatLiving = "Sailboat Living"
    case HouseSitting = "House Sitting"
    case WorkExchange = "Work Exchange"
    case TeachingAbroad = "Teaching Abroad"
    case ExpatLife = "Expat Life"
    case RoadTrips = "Road Trips"
    case TrainJourneys = "Train Journeys"
    case CruiseTravel = "Cruise Travel"
    case Camping = "Camping"
    case Glamping = "Glamping"
    case Backpacking = "Backpacking"
    case HikingAndTrekking = "Hiking & Trekking"
    case Mountaineering = "Mountaineering"
    case ScubaDiving = "Scuba Diving"
    case Snorkeling = "Snorkeling"
    case Surfing = "Surfing"
    case SkiingAndSnowboarding = "Skiing & Snowboarding"
    case SafariTours = "Safari Tours"
    case WildlifeWatching = "Wildlife Watching"
    case NationalParks = "National Parks"
    case UNESCOSites = "UNESCO Sites"
    case HiddenGems = "Hidden Gems"
    case OfftheBeatenPath = "Off the Beaten Path"
    case CityGuides = "City Guides"
    case NeighborhoodGuides = "Neighborhood Guides"
    case HotelReviews = "Hotel Reviews"
    case AirbnbReviews = "Airbnb Reviews"
    case HostelLife = "Hostel Life"
    case FlightDeals = "Flight Deals"
    case TravelHacking = "Travel Hacking"
    case TravelInsurance = "Travel Insurance"
    case TravelSafety = "Travel Safety"
    case TravelPhotography = "Travel Photography"
    case TravelVlogging = "Travel Vlogging"
    case TravelPlanning = "Travel Planning"
    case ItineraryDesign = "Itinerary Design"
    case TravelBudgeting = "Travel Budgeting"
    case PackingGuides = "Packing Guides"
    case TravelGearReviews = "Travel Gear Reviews"
    case PassportAndVisas = "Passport & Visas"
    case LanguageforTravel = "Language for Travel"
    case SustainableTravel = "Sustainable Travel"
    case AppleEcosystem = "Apple Ecosystem"
    case AndroidDevices = "Android Devices"
    case WindowsPC = "Windows PC"
    case Linux = "Linux"
    case SmartHomeSetup = "Smart Home Setup"
    case IoTDevices = "IoT Devices"
    case WearableTech = "Wearable Tech"
    case DroneFlying = "Drone Flying"
    case CameraReviews = "Camera Reviews"
    case AudioEquipment = "Audio Equipment"
    case GamingPCs = "Gaming PCs"
    case ConsoleGaming = "Console Gaming"
    case MobileGaming = "Mobile Gaming"
    case CloudComputing = "Cloud Computing"
    case Cybersecurity = "Cybersecurity"
    case PrivacyTools = "Privacy Tools"
    case VPNReviews = "VPN Reviews"
    case OpenSourceSoftware = "Open Source Software"
    case CodingAndProgramming = "Coding & Programming"
    case WebDevelopment = "Web Development"
    case AppDevelopment = "App Development"
    case AIAndMachineLearning = "AI & Machine Learning"
    case DataScience = "Data Science"
    case BlockchainTechnology = "Blockchain Technology"
    case Cryptocurrency = "Cryptocurrency"
    case NFTMarket = "NFT Market"
    case TechNews = "Tech News"
    case ProductReviews = "Product Reviews"
    case UnboxingVideos = "Unboxing Videos"
    case SetupTours = "Setup Tours"
    case DeskSetup = "Desk Setup"
    case CableManagement = "Cable Management"
    case MinimalistTech = "Minimalist Tech"
    case RetroTech = "Retro Tech"
    case RighttoRepair = "Right to Repair"
    case SustainableTech = "Sustainable Tech"
    case AccessibilityTech = "Accessibility Tech"
    case AssistiveTechnology = "Assistive Technology"
    case EdTech = "EdTech"
    case HealthTech = "HealthTech"
    case FinTech = "FinTech"
    case LegalTech = "LegalTech"
    case PropTech = "PropTech"
    case AdTech = "AdTech"
    case MarTech = "MarTech"
    case PersonalBudgeting = "Personal Budgeting"
    case ExpenseTracking = "Expense Tracking"
    case SavingStrategies = "Saving Strategies"
    case EmergencyFunds = "Emergency Funds"
    case DebtSnowball = "Debt Snowball"
    case DebtAvalanche = "Debt Avalanche"
    case CreditCardHacking = "Credit Card Hacking"
    case CreditScoreBuilding = "Credit Score Building"
    case CreditRepair = "Credit Repair"
    case StudentLoans = "Student Loans"
    case MortgageAdvice = "Mortgage Advice"
    case Refinancing = "Refinancing"
    case InvestingBasics = "Investing Basics"
    case StockMarket = "Stock Market"
    case ETFInvesting = "ETF Investing"
    case IndexFunds = "Index Funds"
    case MutualFunds = "Mutual Funds"
    case BondsInvesting = "Bonds Investing"
    case OptionsTrading = "Options Trading"
    case DayTrading = "Day Trading"
    case SwingTrading = "Swing Trading"
    case ForexTrading = "Forex Trading"
    case Commodities = "Commodities"
    case RealEstateInvesting = "Real Estate Investing"
    case REITs = "REITs"
    case Crowdfunding = "Crowdfunding"
    case AngelInvesting = "Angel Investing"
    case VentureCapital = "Venture Capital"
    case RetirementPlanning = "Retirement Planning"
    case FourZeroOnekOptimization = "401k Optimization"
    case IRAStrategies = "IRA Strategies"
    case RothIRA = "Roth IRA"
    case PensionPlanning = "Pension Planning"
    case SocialSecurity = "Social Security"
    case TaxPlanning = "Tax Planning"
    case TaxOptimization = "Tax Optimization"
    case SideHustles = "Side Hustles"
    case PassiveIncomeStreams = "Passive Income Streams"
    case DividendInvesting = "Dividend Investing"
    case FIREMovement = "FIRE Movement"
    case LeanFIRE = "Lean FIRE"
    case FatFIRE = "Fat FIRE"
    case CoastFIRE = "Coast FIRE"
    case WealthManagement = "Wealth Management"
    case EstatePlanning = "Estate Planning"
    case LifeInsurance = "Life Insurance"
    case HealthInsurance = "Health Insurance"
    case CryptoInvesting = "Crypto Investing"
    case DeFiYields = "DeFi Yields"
    case NFTInvesting = "NFT Investing"
    case CollectiblesInvesting = "Collectibles Investing"
    case ArtInvesting = "Art Investing"
    case WineInvesting = "Wine Investing"
    case WatchInvesting = "Watch Investing"
    case CarFlipping = "Car Flipping"
    case AmazonFBA = "Amazon FBA"
    case Dropshipping = "Dropshipping"
    case AffiliateMarketing = "Affiliate Marketing"
    case ContentMonetization = "Content Monetization"
    case CoachingBusiness = "Coaching Business"
    case Consulting = "Consulting"
    case FreelanceFinance = "Freelance Finance"
    case BusinessFinance = "Business Finance"
    case StartupFunding = "Startup Funding"
    case PitchDecks = "Pitch Decks"
    case Valuation = "Valuation"
    case DueDiligence = "Due Diligence"
    case MAndA = "M&A"
    case IPOs = "IPOs"
    case SPACs = "SPACs"
    case PCGaming = "PC Gaming"
    case PlayStation = "PlayStation"
    case Xbox = "Xbox"
    case Nintendo = "Nintendo"
    case MobileGaming = "Mobile Gaming"
    case CloudGaming = "Cloud Gaming"
    case VRGaming = "VR Gaming"
    case ARGaming = "AR Gaming"
    case LeagueofLegends = "League of Legends"
    case DotaTwo = "Dota 2"
    case CSGO = "CS:GO"
    case Valorant = "Valorant"
    case Overwatch = "Overwatch"
    case Fortnite = "Fortnite"
    case RocketLeague = "Rocket League"
    case FIFA = "FIFA"
    case NBATwoK = "NBA 2K"
    case CallofDuty = "Call of Duty"
    case TwitchStreaming = "Twitch Streaming"
    case YouTubeGaming = "YouTube Gaming"
    case KickStreaming = "Kick Streaming"
    case Speedrunning = "Speedrunning"
    case GameReviews = "Game Reviews"
    case GameLore = "Game Lore"
    case Walkthroughs = "Walkthroughs"
    case GuidesAndTips = "Guides & Tips"
    case BossStrategies = "Boss Strategies"
    case BuildGuides = "Build Guides"
    case WeaponGuides = "Weapon Guides"
    case CharacterGuides = "Character Guides"
    case TierLists = "Tier Lists"
    case PatchNotes = "Patch Notes"
    case MetaAnalysis = "Meta Analysis"
    case GameDevelopment = "Game Development"
    case IndieGames = "Indie Games"
    case AAAGames = "AAA Games"
    case EarlyAccess = "Early Access"
    case CrowdfundingGames = "Crowdfunding Games"
    case GameJams = "Game Jams"
    case Modding = "Modding"
    case CustomContent = "Custom Content"
    case LevelDesign = "Level Design"
    case GameArt = "Game Art"
    case GameMusic = "Game Music"
    case GameWriting = "Game Writing"
    case NarrativeDesign = "Narrative Design"
    case QATesting = "QA Testing"
    case GameJournalism = "Game Journalism"
    case GamePreservation = "Game Preservation"
    case RetroGaming = "Retro Gaming"
    case Emulation = "Emulation"
    case Arcade = "Arcade"
    case Pinball = "Pinball"
    case BoardGames = "Board Games"
    case TabletopRPGs = "Tabletop RPGs"
    case DAndD = "D&D"
    case Pathfinder = "Pathfinder"
    case CallofCthulhu = "Call of Cthulhu"
    case CardGames = "Card Games"
    case MTG = "MTG"
    case PokemonCards = "Pokemon Cards"
    case YuGiOh = "Yu-Gi-Oh"
    case Chess = "Chess"
    case Go = "Go"
    case StrategyGames = "Strategy Games"
    case SimulationGames = "Simulation Games"
    case RPGs = "RPGs"
    case MMOs = "MMOs"
    case SandboxGames = "Sandbox Games"
    case SurvivalGames = "Survival Games"
    case HorrorGames = "Horror Games"
    case PuzzleGames = "Puzzle Games"
    case Platformers = "Platformers"
    case FightingGames = "Fighting Games"
    case RacingGames = "Racing Games"
    case SportsGames = "Sports Games"
    case RhythmGames = "Rhythm Games"
    case VisualNovels = "Visual Novels"
    case DatingSims = "Dating Sims"
    case GachaGames = "Gacha Games"
    case IdleGames = "Idle Games"
    case ClickerGames = "Clicker Games"
    case Hypercasual = "Hypercasual"
    case PartyGames = "Party Games"
    case CoopGames = "Co-op Games"
    case PvPGames = "PvP Games"
    case BattleRoyale = "Battle Royale"
    case TacticalShooters = "Tactical Shooters"
    case MOBA = "MOBA"
    case RTS = "RTS"
    case ClassicalMusic = "Classical Music"
    case Opera = "Opera"
    case BaroqueMusic = "Baroque Music"
    case Jazz = "Jazz"
    case Blues = "Blues"
    case RockMusic = "Rock Music"
    case Metal = "Metal"
    case PopMusic = "Pop Music"
    case ElectronicMusic = "Electronic Music"
    case HipHop = "Hip-Hop"
    case Reggaeton = "Reggaeton"
    case Dancehall = "Dancehall"
    case Afrobeats = "Afrobeats"
    case KPop = "K-Pop"
    case JPop = "J-Pop"
    case BollywoodMusic = "Bollywood Music"
    case CountryMusic = "Country Music"
    case FolkMusic = "Folk Music"
    case WorldMusic = "World Music"
    case MusicProduction = "Music Production"
    case BeatMaking = "Beat Making"
    case Sampling = "Sampling"
    case SoundDesign = "Sound Design"
    case DJing = "DJing"
    case Turntablism = "Turntablism"
    case LivePerformance = "Live Performance"
    case ConcertPhotography = "Concert Photography"
    case MusicTheory = "Music Theory"
    case Composition = "Composition"
    case Songwriting = "Songwriting"
    case MusicBusiness = "Music Business"
    case Streaming = "Streaming"
    case PlaylistCuration = "Playlist Curation"
    case Radio = "Radio"
    case PodcastMusic = "Podcast Music"
    case FineArt = "Fine Art"
    case OilPainting = "Oil Painting"
    case AcrylicPainting = "Acrylic Painting"
    case Watercolor = "Watercolor"
    case DigitalArt = "Digital Art"
    case ThreeDModeling = "3D Modeling"
    case Animation = "Animation"
    case MotionGraphics = "Motion Graphics"
    case GraphicDesign = "Graphic Design"
    case Typography = "Typography"
    case UIDesign = "UI Design"
    case UXDesign = "UX Design"
    case WebDesign = "Web Design"
    case AppDesign = "App Design"
    case Illustration = "Illustration"
    case ConceptArt = "Concept Art"
    case CharacterDesign = "Character Design"
    case PixelArt = "Pixel Art"
    case VoxelArt = "Voxel Art"
    case GenerativeArt = "Generative Art"
    case CreativeCoding = "Creative Coding"
    case Photography = "Photography"
    case FilmPhotography = "Film Photography"
    case StreetPhotography = "Street Photography"
    case PortraitPhotography = "Portrait Photography"
    case FashionPhotography = "Fashion Photography"
    case LandscapePhotography = "Landscape Photography"
    case DocumentaryPhotography = "Documentary Photography"
    case Pregnancy = "Pregnancy"
    case Fertility = "Fertility"
    case Birth = "Birth"
    case NewbornCare = "Newborn Care"
    case InfantSleep = "Infant Sleep"
    case Breastfeeding = "Breastfeeding"
    case StartingSolids = "Starting Solids"
    case ToddlerYears = "Toddler Years"
    case Preschool = "Preschool"
    case KOneTwoEducation = "K-12 Education"
    case Homeschooling = "Homeschooling"
    case GentleParenting = "Gentle Parenting"
    case AttachmentParenting = "Attachment Parenting"
    case PositiveDiscipline = "Positive Discipline"
    case ScreenTime = "Screen Time"
    case MentalHealthforKids = "Mental Health for Kids"
    case SpecialNeedsParenting = "Special Needs Parenting"
    case GiftedChildren = "Gifted Children"
    case SiblingRelationships = "Sibling Relationships"
    case SingleParenting = "Single Parenting"
    case WorkingParents = "Working Parents"
    case TeenParenting = "Teen Parenting"
    case CollegePrep = "College Prep"
    case EmptyNest = "Empty Nest"
    case DogCare = "Dog Care"
    case CatCare = "Cat Care"
    case BirdCare = "Bird Care"
    case ReptileCare = "Reptile Care"
    case FishKeeping = "Fish Keeping"
    case SmallMammals = "Small Mammals"
    case HorseCare = "Horse Care"
    case PetTraining = "Pet Training"
    case PetBehavior = "Pet Behavior"
    case PetNutrition = "Pet Nutrition"
    case PetGrooming = "Pet Grooming"
    case PetHealth = "Pet Health"
    case PetInsurance = "Pet Insurance"
    case PetPhotography = "Pet Photography"
    case DogAgility = "Dog Agility"
    case ServiceAnimals = "Service Animals"
    case PetTech = "Pet Tech"
    case RawFeeding = "Raw Feeding"
    case PetAdoption = "Pet Adoption"
    case PetRescue = "Pet Rescue"
    case PetFoster = "Pet Foster"
    case MentalHealthAndTherapy = "Mental Health & Therapy"
    case Psychology = "Psychology"
    case SelfImprovement = "Self-Improvement"
    case Mindfulness = "Mindfulness"
    case Meditation = "Meditation"
    case Spirituality = "Spirituality"
    case Astrology = "Astrology"
    case Tarot = "Tarot"
    case Witchcraft = "Witchcraft"
    case Paganism = "Paganism"
    case Christianity = "Christianity"
    case Islam = "Islam"
    case Judaism = "Judaism"
    case Buddhism = "Buddhism"
    case Hinduism = "Hinduism"
    case Atheism = "Atheism"
    case Philosophy = "Philosophy"
    case Ethics = "Ethics"
    case CriticalThinking = "Critical Thinking"
    case Debate = "Debate"
    case Environmentalism = "Environmentalism"
    case ClimateAction = "Climate Action"
    case ZeroWaste = "Zero Waste"
    case Sustainability = "Sustainability"
    case Conservation = "Conservation"
    case SocialJustice = "Social Justice"
    case Activism = "Activism"
    case HumanRights = "Human Rights"
    case Feminism = "Feminism"
    case LGBTQPlus = "LGBTQ+"
    case RacialJustice = "Racial Justice"
    case DisabilityRights = "Disability Rights"
    case AnimalRights = "Animal Rights"
    case Veganism = "Veganism"
    case EthicalConsumerism = "Ethical Consumerism"
    case Politics = "Politics"
    case CivicEngagement = "Civic Engagement"
    case Voting = "Voting"
    case PolicyAnalysis = "Policy Analysis"
    case Economics = "Economics"
    case MilitaryLife = "Military Life"
    case Veterans = "Veterans"
    case LawEnforcement = "Law Enforcement"
    case Firefighting = "Firefighting"
    case EMS = "EMS"
    case RealEstate = "Real Estate"
    case InteriorDesign = "Interior Design"
    case Architecture = "Architecture"
    case HomeRenovation = "Home Renovation"
    case Gardening = "Gardening"
    case Automotive = "Automotive"
    case CarReviews = "Car Reviews"
    case CarMaintenance = "Car Maintenance"
    case Motorcycles = "Motorcycles"
    case ElectricVehicles = "Electric Vehicles"
    case EventPlanning = "Event Planning"
    case WeddingPlanning = "Wedding Planning"
    case PartyPlanning = "Party Planning"
    case CorporateEvents = "Corporate Events"
    case Festivals = "Festivals"
    case Writing = "Writing"
    case FictionWriting = "Fiction Writing"
    case NonFictionWriting = "Non-Fiction Writing"
    case Poetry = "Poetry"
    case Screenwriting = "Screenwriting"
    case Journalism = "Journalism"
    case Blogging = "Blogging"
    case Copywriting = "Copywriting"
    case TechnicalWriting = "Technical Writing"
    case Editing = "Editing"
    case PerformingArts = "Performing Arts"
    case Theater = "Theater"
    case Dance = "Dance"
    case Circus = "Circus"
    case StandUpComedy = "Stand-Up Comedy"
    case Improv = "Improv"
    case Magic = "Magic"
    case Puppetry = "Puppetry"
    case VoiceActing = "Voice Acting"
    case Acting = "Acting"
    case FilmMaking = "Film Making"
    case Cinematography = "Cinematography"
    case Directing = "Directing"
    case Producing = "Producing"
    case FilmEditing = "Film Editing"
    case SoundDesign = "Sound Design"
    case ColorGrading = "Color Grading"
    case VFX = "VFX"
    case Stunts = "Stunts"
    case CostumeDesign = "Costume Design"
    case Sports = "Sports"
    case Soccer = "Soccer"
    case Basketball = "Basketball"
    case Football = "Football"
    case Baseball = "Baseball"
    case Hockey = "Hockey"
    case Tennis = "Tennis"
    case Golf = "Golf"
    case Swimming = "Swimming"
    case Gymnastics = "Gymnastics"
    case Skateboarding = "Skateboarding"
    case Snowboarding = "Snowboarding"
    case Surfing = "Surfing"
    case RockClimbing = "Rock Climbing"
    case MartialArts = "Martial Arts"
    case Boxing = "Boxing"
    case Wrestling = "Wrestling"
    case FormulaOne = "Formula 1"
    case NASCAR = "NASCAR"
    case Motorsports = "Motorsports"
    case Collecting = "Collecting"
    case StampCollecting = "Stamp Collecting"
    case CoinCollecting = "Coin Collecting"
    case CardCollecting = "Card Collecting"
    case ToyCollecting = "Toy Collecting"
    case AntiqueCollecting = "Antique Collecting"
    case SneakerCollecting = "Sneaker Collecting"
    case WatchCollecting = "Watch Collecting"
    case ArtCollecting = "Art Collecting"
    case BookCollecting = "Book Collecting"
    case VintageComputing = "Vintage Computing"
    case MechanicalKeyboards = "Mechanical Keyboards"
    case Audiophile = "Audiophile"
    case HiFi = "Hi-Fi"
    case VinylRecords = "Vinyl Records"
    case CassetteTapes = "Cassette Tapes"
    case FilmPhotographyGear = "Film Photography Gear"
    case CameraCollecting = "Camera Collecting"
    case LensReviews = "Lens Reviews"
    case DronePiloting = "Drone Piloting"
    case HamRadio = "Ham Radio"
    case AmateurRadio = "Amateur Radio"
    case Scanning = "Scanning"
    case SatelliteTracking = "Satellite Tracking"
    case Astronomy = "Astronomy"
    case Stargazing = "Stargazing"
    case Astrophotography = "Astrophotography"
    case TelescopeReviews = "Telescope Reviews"
    case SpaceExploration = "Space Exploration"
    case NASA = "NASA"
    case SpaceX = "SpaceX"
    case Aviation = "Aviation"
    case PlaneSpotting = "Plane Spotting"
    case FlightSimulators = "Flight Simulators"
    case PilotLife = "Pilot Life"
    case Boating = "Boating"
    case Sailing = "Sailing"
    case Yachting = "Yachting"
    case Fishing = "Fishing"
    case Hunting = "Hunting"
    case Camping = "Camping"
    case Hiking = "Hiking"
    case Backpacking = "Backpacking"
    case SurvivalSkills = "Survival Skills"
    case Bushcraft = "Bushcraft"
    case Foraging = "Foraging"
    case WildEdibles = "Wild Edibles"
    case MushroomHunting = "Mushroom Hunting"
    case Herbalism = "Herbalism"
    case NaturalRemedies = "Natural Remedies"
    case Homesteading = "Homesteading"
    case Farming = "Farming"
    case Permaculture = "Permaculture"
    case RegenerativeAgriculture = "Regenerative Agriculture"
    case UrbanFarming = "Urban Farming"
    case Hydroponics = "Hydroponics"
    case Aquaponics = "Aquaponics"
    case Composting = "Composting"
    case Beekeeping = "Beekeeping"
    case ChickenKeeping = "Chicken Keeping"
    case Knitting = "Knitting"
    case Crocheting = "Crocheting"
    case Sewing = "Sewing"
    case Quilting = "Quilting"
    case Embroidery = "Embroidery"
    case CrossStitch = "Cross-Stitch"
    case Macrame = "Macrame"
    case Weaving = "Weaving"
    case Spinning = "Spinning"
    case Dyeing = "Dyeing"
    case Pottery = "Pottery"
    case Ceramics = "Ceramics"
    case Sculpture = "Sculpture"
    case Woodworking = "Woodworking"
    case Carpentry = "Carpentry"
    case Metalworking = "Metalworking"
    case Blacksmithing = "Blacksmithing"
    case JewelryMaking = "Jewelry Making"
    case LeatherCraft = "Leather Craft"
    case GlassBlowing = "Glass Blowing"
    case Origami = "Origami"
    case PaperCraft = "Paper Craft"
    case Bookbinding = "Bookbinding"
    case Printmaking = "Printmaking"
    case ScreenPrinting = "Screen Printing"
    case Calligraphy = "Calligraphy"
    case HandLettering = "Hand Lettering"
    case SignPainting = "Sign Painting"
    case MuralArt = "Mural Art"
    case Graffiti = "Graffiti"
    case TattooArt = "Tattoo Art"
    case TattooDesign = "Tattoo Design"
    case Piercing = "Piercing"
    case BodyModification = "Body Modification"
    case CosplayMaking = "Cosplay Making"
    case LARP = "LARP"
    case RenaissanceFaire = "Renaissance Faire"
    case SteampunkCrafting = "Steampunk Crafting"
    case PropMaking = "Prop Making"
    case ModelBuilding = "Model Building"
    case RCVehicles = "RC Vehicles"
    case ModelTrains = "Model Trains"
    case Diorama = "Diorama"
    case MiniaturePainting = "Miniature Painting"
    case Warhammer = "Warhammer"
    case DungeonsAndDragons = "Dungeons & Dragons"
    case TabletopWargaming = "Tabletop Wargaming"
    case BoardGameDesign = "Board Game Design"
    case PuzzleDesign = "Puzzle Design"
    case EscapeRooms = "Escape Rooms"
    case TrueCrime = "True Crime"
    case ConspiracyTheories = "Conspiracy Theories"
    case Paranormal = "Paranormal"
    case UFOs = "UFOs"
    case Cryptozoology = "Cryptozoology"
    case UrbanExploration = "Urban Exploration"
    case AbandonedPlaces = "Abandoned Places"
    case GhostHunting = "Ghost Hunting"
    case ASMR = "ASMR"
    case Mukbang = "Mukbang"
    case ReactionVideos = "Reaction Videos"
    case Commentary = "Commentary"
    case Drama = "Drama"
    case Tea = "Tea"
    case StanCulture = "Stan Culture"
    case Fandom = "Fandom"
    case Shipping = "Shipping"
    case FanFiction = "Fan Fiction"
    case FanArt = "Fan Art"
    case Cosplay = "Cosplay"
    case MemeCulture = "Meme Culture"
    case InternetCulture = "Internet Culture"
    case TikTokTrends = "TikTok Trends"
    case ViralChallenges = "Viral Challenges"
    case DanceTrends = "Dance Trends"
    case LanguageLearning = "Language Learning"
    case SignLanguage = "Sign Language"
    case Esperanto = "Esperanto"
    case Conlanging = "Conlanging"
    case Translation = "Translation"
    case Linguistics = "Linguistics"
    case Etymology = "Etymology"
    case Dialects = "Dialects"
    case Accents = "Accents"
    case SpeechTherapy = "Speech Therapy"
    case PublicSpeaking = "Public Speaking"
    case Debate = "Debate"
    case Negotiation = "Negotiation"
    case Sales = "Sales"
    case Marketing = "Marketing"
    case SEO = "SEO"
    case ContentMarketing = "Content Marketing"
    case SocialMediaMarketing = "Social Media Marketing"
    case EmailMarketing = "Email Marketing"
    case InfluencerMarketing = "Influencer Marketing"
    case BrandBuilding = "Brand Building"
    case PersonalBranding = "Personal Branding"
    case Networking = "Networking"
    case PublicRelations = "Public Relations"
    case CrisisManagement = "Crisis Management"
    case HumanResources = "Human Resources"
    case Recruiting = "Recruiting"
    case TalentManagement = "Talent Management"
    case EmployeeEngagement = "Employee Engagement"
    case RemoteWork = "Remote Work"
    case DigitalNomad = "Digital Nomad"
    case Coworking = "Coworking"
    case Freelancing = "Freelancing"
    case SideHustle = "Side Hustle"
    case PassiveIncome = "Passive Income"
    case Entrepreneurship = "Entrepreneurship"
    case Startups = "Startups"
    case VentureCapital = "Venture Capital"
    case AngelInvesting = "Angel Investing"
    case BusinessStrategy = "Business Strategy"
    case Management = "Management"
    case Leadership = "Leadership"
    case TeamBuilding = "Team Building"
    case ProjectManagement = "Project Management"
    case Agile = "Agile"
    case Scrum = "Scrum"
    case Kanban = "Kanban"
    case Lean = "Lean"
    case SixSigma = "Six Sigma"
    case ProcessImprovement = "Process Improvement"
    case SupplyChain = "Supply Chain"
    case Logistics = "Logistics"
    case Operations = "Operations"
    case QualityControl = "Quality Control"
    case Manufacturing = "Manufacturing"
    case IndustrialDesign = "Industrial Design"
    case ProductDesign = "Product Design"
    case PackagingDesign = "Packaging Design"
    case UXResearch = "UX Research"
    case UserTesting = "User Testing"
    case DataAnalysis = "Data Analysis"
    case BusinessIntelligence = "Business Intelligence"
    case DataVisualization = "Data Visualization"
    case DashboardDesign = "Dashboard Design"
    case KPITracking = "KPI Tracking"
    case Accounting = "Accounting"
    case Bookkeeping = "Bookkeeping"
    case Auditing = "Auditing"
    case TaxPreparation = "Tax Preparation"
    case FinancialPlanning = "Financial Planning"
    case Insurance = "Insurance"
    case RiskManagement = "Risk Management"
    case Compliance = "Compliance"
    case LegalAnalysis = "Legal Analysis"
    case ContractLaw = "Contract Law"
    case IntellectualProperty = "Intellectual Property"
    case Copyright = "Copyright"
    case Trademark = "Trademark"
    case Patents = "Patents"
    case Licensing = "Licensing"
    case RealEstateInvesting = "Real Estate Investing"
    case PropertyManagement = "Property Management"
    case HouseFlipping = "House Flipping"
    case RentalProperties = "Rental Properties"
    case CommercialRealEstate = "Commercial Real Estate"
    case MortgageBrokering = "Mortgage Brokering"
    case InteriorStaging = "Interior Staging"
    case HomeInspection = "Home Inspection"
    case Architecture = "Architecture"
    case LandscapeDesign = "Landscape Design"
    case Construction = "Construction"
    case CivilEngineering = "Civil Engineering"
    case StructuralEngineering = "Structural Engineering"
    case MechanicalEngineering = "Mechanical Engineering"
    case ElectricalEngineering = "Electrical Engineering"
    case SoftwareEngineering = "Software Engineering"
    case DevOps = "DevOps"
    case SRE = "SRE"
    case CloudArchitecture = "Cloud Architecture"
    case SystemDesign = "System Design"
    case DatabaseAdministration = "Database Administration"
    case NetworkEngineering = "Network Engineering"
    case Cybersecurity = "Cybersecurity"
    case EthicalHacking = "Ethical Hacking"
    case PenetrationTesting = "Penetration Testing"
    case IncidentResponse = "Incident Response"
    case DigitalForensics = "Digital Forensics"
    case ThreatIntelligence = "Threat Intelligence"
    case Compliance = "Compliance"
    case GDPR = "GDPR"
    case Accessibility = "Accessibility"
    case WCAG = "WCAG"
    case InclusiveDesign = "Inclusive Design"
    case UniversalDesign = "Universal Design"
    case AssistiveTechnology = "Assistive Technology"
    case Neurodiversity = "Neurodiversity"
    case ADHD = "ADHD"
    case Autism = "Autism"
    case Dyslexia = "Dyslexia"
    case Anxiety = "Anxiety"
    case Depression = "Depression"
    case Bipolar = "Bipolar"
    case OCD = "OCD"
    case PTSD = "PTSD"
    case EatingDisorders = "Eating Disorders"
    case AddictionRecovery = "Addiction Recovery"
    case SubstanceAbuse = "Substance Abuse"
    case OneTwoStep = "12 Step"
    case HarmReduction = "Harm Reduction"
    case SoberLiving = "Sober Living"
    case PhysicalTherapy = "Physical Therapy"
    case OccupationalTherapy = "Occupational Therapy"
    case SpeechTherapy = "Speech Therapy"
    case MassageTherapy = "Massage Therapy"
    case Chiropractic = "Chiropractic"
    case Acupuncture = "Acupuncture"
    case TraditionalChineseMedicine = "Traditional Chinese Medicine"
    case Ayurveda = "Ayurveda"
    case Homeopathy = "Homeopathy"
    case Naturopathy = "Naturopathy"
    case FunctionalMedicine = "Functional Medicine"
    case IntegrativeMedicine = "Integrative Medicine"
    case HolisticHealth = "Holistic Health"
    case WellnessCoaching = "Wellness Coaching"
    case LifeCoaching = "Life Coaching"
    case CareerCoaching = "Career Coaching"
    case ExecutiveCoaching = "Executive Coaching"
    case RelationshipCoaching = "Relationship Coaching"
    case DatingAdvice = "Dating Advice"
    case MarriageCounseling = "Marriage Counseling"
    case DivorceRecovery = "Divorce Recovery"
    case CoParenting = "Co-Parenting"
    case BlendedFamilies = "Blended Families"
    case Adoption = "Adoption"
    case FosterCare = "Foster Care"
    case SeniorCare = "Senior Care"
    case ElderCare = "Elder Care"
    case DementiaCare = "Dementia Care"
    case Alzheimers = "Alzheimer's"
    case Parkinsons = "Parkinson's"
    case Hospice = "Hospice"
    case EndofLife = "End of Life"
    case GriefSupport = "Grief Support"
    case Bereavement = "Bereavement"
    case DeathPositivity = "Death Positivity"
    case LegacyPlanning = "Legacy Planning"
    case Genealogy = "Genealogy"
    case DNATesting = "DNA Testing"
    case Ancestry = "Ancestry"
    case FamilyHistory = "Family History"
    case MilitaryHistory = "Military History"
    case WarHistory = "War History"
    case AncientHistory = "Ancient History"
    case MedievalHistory = "Medieval History"
    case Renaissance = "Renaissance"
    case Enlightenment = "Enlightenment"
    case IndustrialRevolution = "Industrial Revolution"
    case WorldWarI = "World War I"
    case WorldWarII = "World War II"
    case ColdWar = "Cold War"
    case Decolonization = "Decolonization"
    case CivilRightsMovement = "Civil Rights Movement"
    case WomensSuffrage = "Women's Suffrage"
    case LaborHistory = "Labor History"
    case EconomicHistory = "Economic History"
    case HistoryofScience = "History of Science"
    case HistoryofTechnology = "History of Technology"
    case HistoryofArt = "History of Art"
    case HistoryofMusic = "History of Music"
    case HistoryofFashion = "History of Fashion"
    case Archaeology = "Archaeology"
    case Anthropology = "Anthropology"
    case CulturalStudies = "Cultural Studies"
    case Sociology = "Sociology"
    case SocialPsychology = "Social Psychology"
    case CognitivePsychology = "Cognitive Psychology"
    case DevelopmentalPsychology = "Developmental Psychology"
    case ClinicalPsychology = "Clinical Psychology"
    case ForensicPsychology = "Forensic Psychology"
    case SportsPsychology = "Sports Psychology"
    case PositivePsychology = "Positive Psychology"
    case BehavioralEconomics = "Behavioral Economics"
    case GameTheory = "Game Theory"
    case DecisionScience = "Decision Science"
    case RiskAssessment = "Risk Assessment"
    case ForensicScience = "Forensic Science"
    case CriminalJustice = "Criminal Justice"
    case LawEnforcement = "Law Enforcement"
    case PrivateInvestigation = "Private Investigation"
    case Security = "Security"
    case FireSafety = "Fire Safety"
    case EmergencyManagement = "Emergency Management"
    case DisasterPreparedness = "Disaster Preparedness"
    case FirstAid = "First Aid"
    case CPR = "CPR"
    case SearchandRescue = "Search and Rescue"
    case KNineUnits = "K9 Units"
    case MountedPolice = "Mounted Police"
    case CoastGuard = "Coast Guard"
    case BorderPatrol = "Border Patrol"
    case Customs = "Customs"
    case Immigration = "Immigration"
    case Diplomacy = "Diplomacy"
    case InternationalRelations = "International Relations"
    case Geopolitics = "Geopolitics"
    case ConflictResolution = "Conflict Resolution"
    case Peacekeeping = "Peacekeeping"
    case HumanitarianAid = "Humanitarian Aid"
    case NGOWork = "NGO Work"
    case NonprofitManagement = "Nonprofit Management"
    case Fundraising = "Fundraising"
    case GrantWriting = "Grant Writing"
    case VolunteerManagement = "Volunteer Management"
    case CommunityOrganizing = "Community Organizing"
    case SocialWork = "Social Work"
    case SchoolCounseling = "School Counseling"
    case CollegeCounseling = "College Counseling"
    case CareerServices = "Career Services"
    case VocationalTraining = "Vocational Training"
    case Apprenticeships = "Apprenticeships"
    case TradeSkills = "Trade Skills"
    case Electrician = "Electrician"
    case Plumber = "Plumber"
    case HVAC = "HVAC"
    case Carpentry = "Carpentry"
    case Masonry = "Masonry"
    case Welding = "Welding"
    case AutoMechanics = "Auto Mechanics"
    case DieselMechanics = "Diesel Mechanics"
    case AviationMechanics = "Aviation Mechanics"
    case MarineMechanics = "Marine Mechanics"
    case Machining = "Machining"
    case CNC = "CNC"
    case ThreeDPrinting = "3D Printing"
    case LaserCutting = "Laser Cutting"
    case Robotics = "Robotics"
    case Automation = "Automation"
    case IndustrialIoT = "Industrial IoT"
    case SmartManufacturing = "Smart Manufacturing"
    case PredictiveMaintenance = "Predictive Maintenance"
    case QualityAssurance = "Quality Assurance"
    case SixSigma = "Six Sigma"
    case LeanManufacturing = "Lean Manufacturing"
    case Kaizen = "Kaizen"
    case TotalQualityManagement = "Total Quality Management"
    case SupplyChainOptimization = "Supply Chain Optimization"
    case InventoryManagement = "Inventory Management"
    case WarehouseOperations = "Warehouse Operations"
    case Distribution = "Distribution"
    case LastMileDelivery = "Last Mile Delivery"
    case FleetManagement = "Fleet Management"
    case RouteOptimization = "Route Optimization"
    case Telematics = "Telematics"
    case AutonomousVehicles = "Autonomous Vehicles"
    case Drones = "Drones"
    case SpaceIndustry = "Space Industry"
    case SatelliteTechnology = "Satellite Technology"
    case Aerospace = "Aerospace"
    case Defense = "Defense"
    case NationalSecurity = "National Security"
    case IntelligenceAnalysis = "Intelligence Analysis"
    case Counterterrorism = "Counterterrorism"
    case CyberWarfare = "Cyber Warfare"
    case InformationWarfare = "Information Warfare"
    case PropagandaAnalysis = "Propaganda Analysis"
    case Disinformation = "Disinformation"
    case FactChecking = "Fact Checking"
    case MediaLiteracy = "Media Literacy"
    case JournalismEthics = "Journalism Ethics"
    case InvestigativeJournalism = "Investigative Journalism"
    case DataJournalism = "Data Journalism"
    case Photojournalism = "Photojournalism"
    case BroadcastJournalism = "Broadcast Journalism"
    case SportsJournalism = "Sports Journalism"
    case EntertainmentJournalism = "Entertainment Journalism"
    case FashionJournalism = "Fashion Journalism"
    case FoodWriting = "Food Writing"
    case TravelWriting = "Travel Writing"
    case ScienceWriting = "Science Writing"
    case TechnicalWriting = "Technical Writing"
    case MedicalWriting = "Medical Writing"
    case GrantWriting = "Grant Writing"
    case SpeechWriting = "Speech Writing"
    case GhostWriting = "Ghost Writing"
    case ResumeWriting = "Resume Writing"
    case Translation = "Translation"
    case Interpretation = "Interpretation"
    case Localization = "Localization"
    case Subtitling = "Subtitling"
    case Dubbing = "Dubbing"
    case VoiceOver = "Voice Over"
    case Narration = "Narration"
    case Audiobooks = "Audiobooks"
    case Podcasting = "Podcasting"
    case RadioBroadcasting = "Radio Broadcasting"
    case TVBroadcasting = "TV Broadcasting"
    case Streaming = "Streaming"
    case ContentCreation = "Content Creation"
    case YouTube = "YouTube"
    case TikTok = "TikTok"
    case Instagram = "Instagram"
    case TwitterX = "Twitter/X"
    case LinkedIn = "LinkedIn"
    case Pinterest = "Pinterest"
    case Snapchat = "Snapchat"
    case Reddit = "Reddit"
    case Discord = "Discord"
    case Twitch = "Twitch"
    case Kick = "Kick"
    case Patreon = "Patreon"
    case OnlyFans = "OnlyFans"
    case Substack = "Substack"
    case Medium = "Medium"
    case Devto = "Dev.to"
    case GitHub = "GitHub"
    case StackOverflow = "Stack Overflow"
    case HackerNews = "Hacker News"
    case ProductHunt = "Product Hunt"
    case IndieHackers = "Indie Hackers"
    case BetaList = "BetaList"
    case AngelList = "AngelList"
    case Crunchbase = "Crunchbase"
    case PitchBook = "PitchBook"
    case Bloomberg = "Bloomberg"
    case Reuters = "Reuters"
    case AssociatedPress = "Associated Press"
    case BBC = "BBC"
    case CNN = "CNN"
    case FoxNews = "Fox News"
    case MSNBC = "MSNBC"
    case AlJazeera = "Al Jazeera"
    case RT = "RT"
    case CGTN = "CGTN"
    case NHK = "NHK"
    case FranceTwoFour = "France 24"
    case DeutscheWelle = "Deutsche Welle"
    case VoiceofAmerica = "Voice of America"
    case RadioFreeEurope = "Radio Free Europe"
    case BBCWorldService = "BBC World Service"
    case Podcasts = "Podcasts"

    /// The category this niche belongs to
    public var category: ContentNicheCategory {
        switch self {
        case .GeneralLifestyle: return .OriginalBase
        case .HomeAndInterior: return .OriginalBase
        case .OrganizationAndProductivity: return .OriginalBase
        case .Minimalism: return .OriginalBase
        case .SelfCareAndWellness: return .OriginalBase
        case .Fashion: return .OriginalBase
        case .Streetwear: return .OriginalBase
        case .BeautyAndMakeup: return .OriginalBase
        case .Skincare: return .OriginalBase
        case .HairAndNails: return .OriginalBase
        case .FitnessAndGym: return .OriginalBase
        case .YogaAndPilates: return .OriginalBase
        case .RunningAndCardio: return .OriginalBase
        case .NutritionAndDiet: return .OriginalBase
        case .MentalHealth: return .OriginalBase
        case .RecipesAndCooking: return .OriginalBase
        case .BakingAndDesserts: return .OriginalBase
        case .HealthyEating: return .OriginalBase
        case .RestaurantReviews: return .OriginalBase
        case .CocktailsAndDrinks: return .OriginalBase
        case .Travel: return .OriginalBase
        case .BudgetTravel: return .OriginalBase
        case .LuxuryTravel: return .OriginalBase
        case .AdventureAndOutdoors: return .OriginalBase
        case .VanLifeRV: return .OriginalBase
        case .TechnologyAndGadgets: return .OriginalBase
        case .SoftwareAndApps: return .OriginalBase
        case .PersonalFinance: return .OriginalBase
        case .Entrepreneurship: return .OriginalBase
        case .Freelancing: return .OriginalBase
        case .Gaming: return .OriginalBase
        case .MoviesAndTV: return .OriginalBase
        case .Music: return .OriginalBase
        case .BooksAndLiterature: return .OriginalBase
        case .ComedyAndMemes: return .OriginalBase
        case .EducationAndLearning: return .OriginalBase
        case .ScienceAndFacts: return .OriginalBase
        case .HistoryAndCulture: return .OriginalBase
        case .DIYAndCrafts: return .OriginalBase
        case .ArtAndDesign: return .OriginalBase
        case .ParentingAndFamily: return .OriginalBase
        case .PetCare: return .OriginalBase
        case .CrossFit: return .FitnessExpanded
        case .Powerlifting: return .FitnessExpanded
        case .OlympicLifting: return .FitnessExpanded
        case .Bodybuilding: return .FitnessExpanded
        case .Calisthenics: return .FitnessExpanded
        case .StreetWorkout: return .FitnessExpanded
        case .HathaYoga: return .FitnessExpanded
        case .VinyasaYoga: return .FitnessExpanded
        case .AshtangaYoga: return .FitnessExpanded
        case .BikramYoga: return .FitnessExpanded
        case .YinYoga: return .FitnessExpanded
        case .RestorativeYoga: return .FitnessExpanded
        case .AerialYoga: return .FitnessExpanded
        case .PilatesMat: return .FitnessExpanded
        case .ReformerPilates: return .FitnessExpanded
        case .BarreFitness: return .FitnessExpanded
        case .HIIT: return .FitnessExpanded
        case .Tabata: return .FitnessExpanded
        case .CircuitTraining: return .FitnessExpanded
        case .FunctionalFitness: return .FitnessExpanded
        case .MobilityTraining: return .FitnessExpanded
        case .FlexibilityTraining: return .FitnessExpanded
        case .SprintTraining: return .FitnessExpanded
        case .MarathonRunning: return .FitnessExpanded
        case .TrailRunning: return .FitnessExpanded
        case .UltraRunning: return .FitnessExpanded
        case .TrackAndField: return .FitnessExpanded
        case .OpenWaterSwimming: return .FitnessExpanded
        case .PoolSwimming: return .FitnessExpanded
        case .RoadCycling: return .FitnessExpanded
        case .MountainBiking: return .FitnessExpanded
        case .BMX: return .FitnessExpanded
        case .SpinClass: return .FitnessExpanded
        case .BrazilianJiuJitsu: return .FitnessExpanded
        case .MuayThai: return .FitnessExpanded
        case .Boxing: return .FitnessExpanded
        case .MMA: return .FitnessExpanded
        case .Karate: return .FitnessExpanded
        case .Taekwondo: return .FitnessExpanded
        case .Judo: return .FitnessExpanded
        case .Capoeira: return .FitnessExpanded
        case .Zumba: return .FitnessExpanded
        case .HipHopDanceFitness: return .FitnessExpanded
        case .BalletFitness: return .FitnessExpanded
        case .PostpartumFitness: return .FitnessExpanded
        case .SeniorFitness: return .FitnessExpanded
        case .AdaptiveFitness: return .FitnessExpanded
        case .YouthAthletics: return .FitnessExpanded
        case .SoccerTraining: return .FitnessExpanded
        case .BasketballTraining: return .FitnessExpanded
        case .TennisTraining: return .FitnessExpanded
        case .GolfFitness: return .FitnessExpanded
        case .VolleyballTraining: return .FitnessExpanded
        case .RecoveryAndStretching: return .FitnessExpanded
        case .FoamRolling: return .FitnessExpanded
        case .SportsMassage: return .FitnessExpanded
        case .Cryotherapy: return .FoodExpanded
        case .SupplementReviews: return .FoodExpanded
        case .CompetitionPrep: return .FoodExpanded
        case .PhysiqueCoaching: return .FoodExpanded
        case .WeightLoss: return .FoodExpanded
        case .MuscleGain: return .FoodExpanded
        case .BodyRecomposition: return .FoodExpanded
        case .MealPrepping: return .FoodExpanded
        case .MacroTracking: return .FoodExpanded
        case .ItalianCuisine: return .FoodExpanded
        case .FrenchCuisine: return .FoodExpanded
        case .JapaneseCuisine: return .FoodExpanded
        case .KoreanCuisine: return .FoodExpanded
        case .ChineseCuisine: return .FoodExpanded
        case .ThaiCuisine: return .FoodExpanded
        case .VietnameseCuisine: return .FoodExpanded
        case .MexicanCuisine: return .FoodExpanded
        case .IndianCuisine: return .FoodExpanded
        case .MiddleEasternCuisine: return .FoodExpanded
        case .MediterraneanCuisine: return .FoodExpanded
        case .BBQAndSmoking: return .FoodExpanded
        case .BreadBaking: return .FoodExpanded
        case .PastryMaking: return .FoodExpanded
        case .CakeDecorating: return .FoodExpanded
        case .CookieBaking: return .FoodExpanded
        case .PieMaking: return .FoodExpanded
        case .VeganCooking: return .FoodExpanded
        case .VegetarianRecipes: return .FoodExpanded
        case .KetoRecipes: return .FoodExpanded
        case .PaleoRecipes: return .FoodExpanded
        case .GlutenFreeBaking: return .FoodExpanded
        case .DairyFreeCooking: return .FoodExpanded
        case .LowCarbMeals: return .FoodExpanded
        case .MealPrep: return .FoodExpanded
        case .BatchCooking: return .FoodExpanded
        case .OnePotMeals: return .FoodExpanded
        case .SheetPanDinners: return .FoodExpanded
        case .AirFryerRecipes: return .FoodExpanded
        case .InstantPotRecipes: return .FoodExpanded
        case .SousVideCooking: return .FoodExpanded
        case .MolecularGastronomy: return .FoodExpanded
        case .Fermentation: return .FoodExpanded
        case .CanningAndPreserving: return .FoodExpanded
        case .Foraging: return .FoodExpanded
        case .Butchery: return .FoodExpanded
        case .Charcuterie: return .FoodExpanded
        case .CheeseMaking: return .FoodExpanded
        case .WineTasting: return .FoodExpanded
        case .MixologyAndCocktails: return .FoodExpanded
        case .CoffeeBrewing: return .FoodExpanded
        case .TeaCulture: return .FoodExpanded
        case .FoodPhotography: return .FashionExpanded
        case .FoodStyling: return .FashionExpanded
        case .RestaurantReviews: return .FashionExpanded
        case .StreetFood: return .FashionExpanded
        case .FoodChallenges: return .FashionExpanded
        case .Mukbang: return .FashionExpanded
        case .ASMREating: return .FashionExpanded
        case .FoodScience: return .FashionExpanded
        case .NutritionScience: return .FashionExpanded
        case .Dietetics: return .FashionExpanded
        case .IntuitiveEating: return .FashionExpanded
        case .IntermittentFasting: return .FashionExpanded
        case .PlantBasedDiet: return .FashionExpanded
        case .HauteCouture: return .FashionExpanded
        case .ReadytoWear: return .FashionExpanded
        case .FastFashion: return .FashionExpanded
        case .SustainableFashion: return .FashionExpanded
        case .ThriftAndVintage: return .FashionExpanded
        case .StreetwearCulture: return .FashionExpanded
        case .Athleisure: return .FashionExpanded
        case .Workwear: return .FashionExpanded
        case .BusinessCasual: return .FashionExpanded
        case .FormalWear: return .FashionExpanded
        case .EveningWear: return .FashionExpanded
        case .BridalFashion: return .FashionExpanded
        case .MaternityFashion: return .FashionExpanded
        case .PlusSizeFashion: return .FashionExpanded
        case .PetiteFashion: return .FashionExpanded
        case .TallFashion: return .FashionExpanded
        case .GenderNeutralFashion: return .FashionExpanded
        case .KidsFashion: return .FashionExpanded
        case .FashionAccessories: return .FashionExpanded
        case .JewelryDesign: return .FashionExpanded
        case .WatchCollecting: return .FashionExpanded
        case .HandbagReviews: return .FashionExpanded
        case .SneakerCulture: return .FashionExpanded
        case .HighHeels: return .FashionExpanded
        case .Boots: return .FashionExpanded
        case .Sandals: return .FashionExpanded
        case .EyewearFashion: return .FashionExpanded
        case .HatDesign: return .FashionExpanded
        case .SeasonalFashion: return .FashionExpanded
        case .TrendForecasting: return .FashionExpanded
        case .RunwayReviews: return .FashionExpanded
        case .DesignerProfiles: return .FashionExpanded
        case .FashionWeekCoverage: return .FashionExpanded
        case .ModelLifestyle: return .FashionExpanded
        case .StylingTips: return .FashionExpanded
        case .ColorTheoryinFashion: return .FashionExpanded
        case .WardrobePlanning: return .FashionExpanded
        case .CapsuleWardrobe: return .FashionExpanded
        case .PersonalShopping: return .BeautyExpanded
        case .CustomTailoring: return .BeautyExpanded
        case .DIYFashion: return .BeautyExpanded
        case .UpcyclingClothing: return .BeautyExpanded
        case .FashionIllustration: return .BeautyExpanded
        case .FashionPhotography: return .BeautyExpanded
        case .FashionHistory: return .BeautyExpanded
        case .SubcultureFashion: return .BeautyExpanded
        case .GothFashion: return .BeautyExpanded
        case .PunkFashion: return .BeautyExpanded
        case .PreppyStyle: return .BeautyExpanded
        case .GrungeRevival: return .BeautyExpanded
        case .SkincareRoutines: return .BeautyExpanded
        case .AcneTreatment: return .BeautyExpanded
        case .AntiAgingSkincare: return .BeautyExpanded
        case .HyperpigmentationSolutions: return .BeautyExpanded
        case .SensitiveSkinCare: return .BeautyExpanded
        case .OilySkinManagement: return .BeautyExpanded
        case .DrySkinRemedies: return .BeautyExpanded
        case .CombinationSkin: return .BeautyExpanded
        case .KBeauty: return .BeautyExpanded
        case .JBeauty: return .BeautyExpanded
        case .CleanBeautyProducts: return .BeautyExpanded
        case .IndieBeautyBrands: return .BeautyExpanded
        case .LuxuryBeauty: return .BeautyExpanded
        case .DrugstoreBeauty: return .BeautyExpanded
        case .NaturalMakeup: return .BeautyExpanded
        case .GlamMakeup: return .BeautyExpanded
        case .EditorialMakeup: return .BeautyExpanded
        case .BridalMakeup: return .BeautyExpanded
        case .SpecialEffectsMakeup: return .BeautyExpanded
        case .EyeshadowTutorials: return .BeautyExpanded
        case .ContouringTechniques: return .BeautyExpanded
        case .HighlightingTips: return .BeautyExpanded
        case .BrowGrooming: return .BeautyExpanded
        case .LashExtensions: return .BeautyExpanded
        case .LipstickReviews: return .BeautyExpanded
        case .NailArtDesign: return .BeautyExpanded
        case .GelNails: return .BeautyExpanded
        case .AcrylicNails: return .BeautyExpanded
        case .DipPowderNails: return .BeautyExpanded
        case .PressOnNails: return .BeautyExpanded
        case .HairCareRoutines: return .BeautyExpanded
        case .HairColoring: return .BeautyExpanded
        case .Balayage: return .BeautyExpanded
        case .Highlights: return .BeautyExpanded
        case .HairExtensions: return .BeautyExpanded
        case .WigReviews: return .BeautyExpanded
        case .BraidingHairstyles: return .BeautyExpanded
        case .LocsCare: return .BeautyExpanded
        case .NaturalHairJourney: return .BeautyExpanded
        case .CurlyHairCare: return .TravelExpanded
        case .StraightHairTips: return .TravelExpanded
        case .WavyHairStyling: return .TravelExpanded
        case .ThinningHairSolutions: return .TravelExpanded
        case .ScalpCare: return .TravelExpanded
        case .FragranceReviews: return .TravelExpanded
        case .BodyCare: return .TravelExpanded
        case .SelfTanning: return .TravelExpanded
        case .HairRemoval: return .TravelExpanded
        case .WellnessBeauty: return .TravelExpanded
        case .InnerBeauty: return .TravelExpanded
        case .SoloTravel: return .TravelExpanded
        case .CouplesTravel: return .TravelExpanded
        case .FamilyTravel: return .TravelExpanded
        case .GroupTravel: return .TravelExpanded
        case .BudgetBackpacking: return .TravelExpanded
        case .LuxuryTravel: return .TravelExpanded
        case .AdventureTravel: return .TravelExpanded
        case .CulturalImmersion: return .TravelExpanded
        case .FoodTourism: return .TravelExpanded
        case .WellnessRetreats: return .TravelExpanded
        case .DigitalNomadLife: return .TravelExpanded
        case .VanLife: return .TravelExpanded
        case .RVLiving: return .TravelExpanded
        case .SailboatLiving: return .TravelExpanded
        case .HouseSitting: return .TravelExpanded
        case .WorkExchange: return .TravelExpanded
        case .TeachingAbroad: return .TravelExpanded
        case .ExpatLife: return .TravelExpanded
        case .RoadTrips: return .TravelExpanded
        case .TrainJourneys: return .TravelExpanded
        case .CruiseTravel: return .TravelExpanded
        case .Camping: return .TravelExpanded
        case .Glamping: return .TravelExpanded
        case .Backpacking: return .TravelExpanded
        case .HikingAndTrekking: return .TravelExpanded
        case .Mountaineering: return .TravelExpanded
        case .ScubaDiving: return .TravelExpanded
        case .Snorkeling: return .TravelExpanded
        case .Surfing: return .TravelExpanded
        case .SkiingAndSnowboarding: return .TravelExpanded
        case .SafariTours: return .TravelExpanded
        case .WildlifeWatching: return .TravelExpanded
        case .NationalParks: return .TravelExpanded
        case .UNESCOSites: return .TravelExpanded
        case .HiddenGems: return .TravelExpanded
        case .OfftheBeatenPath: return .TravelExpanded
        case .CityGuides: return .TravelExpanded
        case .NeighborhoodGuides: return .TravelExpanded
        case .HotelReviews: return .TravelExpanded
        case .AirbnbReviews: return .TravelExpanded
        case .HostelLife: return .TechExpanded
        case .FlightDeals: return .TechExpanded
        case .TravelHacking: return .TechExpanded
        case .TravelInsurance: return .TechExpanded
        case .TravelSafety: return .TechExpanded
        case .TravelPhotography: return .TechExpanded
        case .TravelVlogging: return .TechExpanded
        case .TravelPlanning: return .TechExpanded
        case .ItineraryDesign: return .TechExpanded
        case .TravelBudgeting: return .TechExpanded
        case .PackingGuides: return .TechExpanded
        case .TravelGearReviews: return .TechExpanded
        case .PassportAndVisas: return .TechExpanded
        case .LanguageforTravel: return .TechExpanded
        case .SustainableTravel: return .TechExpanded
        case .AppleEcosystem: return .TechExpanded
        case .AndroidDevices: return .TechExpanded
        case .WindowsPC: return .TechExpanded
        case .Linux: return .TechExpanded
        case .SmartHomeSetup: return .TechExpanded
        case .IoTDevices: return .TechExpanded
        case .WearableTech: return .TechExpanded
        case .DroneFlying: return .TechExpanded
        case .CameraReviews: return .TechExpanded
        case .AudioEquipment: return .TechExpanded
        case .GamingPCs: return .TechExpanded
        case .ConsoleGaming: return .TechExpanded
        case .MobileGaming: return .TechExpanded
        case .CloudComputing: return .TechExpanded
        case .Cybersecurity: return .TechExpanded
        case .PrivacyTools: return .TechExpanded
        case .VPNReviews: return .TechExpanded
        case .OpenSourceSoftware: return .TechExpanded
        case .CodingAndProgramming: return .TechExpanded
        case .WebDevelopment: return .TechExpanded
        case .AppDevelopment: return .TechExpanded
        case .AIAndMachineLearning: return .TechExpanded
        case .DataScience: return .TechExpanded
        case .BlockchainTechnology: return .TechExpanded
        case .Cryptocurrency: return .TechExpanded
        case .NFTMarket: return .TechExpanded
        case .TechNews: return .TechExpanded
        case .ProductReviews: return .TechExpanded
        case .UnboxingVideos: return .TechExpanded
        case .SetupTours: return .TechExpanded
        case .DeskSetup: return .TechExpanded
        case .CableManagement: return .TechExpanded
        case .MinimalistTech: return .TechExpanded
        case .RetroTech: return .TechExpanded
        case .RighttoRepair: return .TechExpanded
        case .SustainableTech: return .TechExpanded
        case .AccessibilityTech: return .FinanceExpanded
        case .AssistiveTechnology: return .FinanceExpanded
        case .EdTech: return .FinanceExpanded
        case .HealthTech: return .FinanceExpanded
        case .FinTech: return .FinanceExpanded
        case .LegalTech: return .FinanceExpanded
        case .PropTech: return .FinanceExpanded
        case .AdTech: return .FinanceExpanded
        case .MarTech: return .FinanceExpanded
        case .PersonalBudgeting: return .FinanceExpanded
        case .ExpenseTracking: return .FinanceExpanded
        case .SavingStrategies: return .FinanceExpanded
        case .EmergencyFunds: return .FinanceExpanded
        case .DebtSnowball: return .FinanceExpanded
        case .DebtAvalanche: return .FinanceExpanded
        case .CreditCardHacking: return .FinanceExpanded
        case .CreditScoreBuilding: return .FinanceExpanded
        case .CreditRepair: return .FinanceExpanded
        case .StudentLoans: return .FinanceExpanded
        case .MortgageAdvice: return .FinanceExpanded
        case .Refinancing: return .FinanceExpanded
        case .InvestingBasics: return .FinanceExpanded
        case .StockMarket: return .FinanceExpanded
        case .ETFInvesting: return .FinanceExpanded
        case .IndexFunds: return .FinanceExpanded
        case .MutualFunds: return .FinanceExpanded
        case .BondsInvesting: return .FinanceExpanded
        case .OptionsTrading: return .FinanceExpanded
        case .DayTrading: return .FinanceExpanded
        case .SwingTrading: return .FinanceExpanded
        case .ForexTrading: return .FinanceExpanded
        case .Commodities: return .FinanceExpanded
        case .RealEstateInvesting: return .FinanceExpanded
        case .REITs: return .FinanceExpanded
        case .Crowdfunding: return .FinanceExpanded
        case .AngelInvesting: return .FinanceExpanded
        case .VentureCapital: return .FinanceExpanded
        case .RetirementPlanning: return .FinanceExpanded
        case .FourZeroOnekOptimization: return .FinanceExpanded
        case .IRAStrategies: return .FinanceExpanded
        case .RothIRA: return .FinanceExpanded
        case .PensionPlanning: return .FinanceExpanded
        case .SocialSecurity: return .FinanceExpanded
        case .TaxPlanning: return .FinanceExpanded
        case .TaxOptimization: return .FinanceExpanded
        case .SideHustles: return .FinanceExpanded
        case .PassiveIncomeStreams: return .FinanceExpanded
        case .DividendInvesting: return .FinanceExpanded
        case .FIREMovement: return .FinanceExpanded
        case .LeanFIRE: return .FinanceExpanded
        case .FatFIRE: return .FinanceExpanded
        case .CoastFIRE: return .FinanceExpanded
        case .WealthManagement: return .FinanceExpanded
        case .EstatePlanning: return .FinanceExpanded
        case .LifeInsurance: return .FinanceExpanded
        case .HealthInsurance: return .FinanceExpanded
        case .CryptoInvesting: return .GamingExpanded
        case .DeFiYields: return .GamingExpanded
        case .NFTInvesting: return .GamingExpanded
        case .CollectiblesInvesting: return .GamingExpanded
        case .ArtInvesting: return .GamingExpanded
        case .WineInvesting: return .GamingExpanded
        case .WatchInvesting: return .GamingExpanded
        case .CarFlipping: return .GamingExpanded
        case .AmazonFBA: return .GamingExpanded
        case .Dropshipping: return .GamingExpanded
        case .AffiliateMarketing: return .GamingExpanded
        case .ContentMonetization: return .GamingExpanded
        case .CoachingBusiness: return .GamingExpanded
        case .Consulting: return .GamingExpanded
        case .FreelanceFinance: return .GamingExpanded
        case .BusinessFinance: return .GamingExpanded
        case .StartupFunding: return .GamingExpanded
        case .PitchDecks: return .GamingExpanded
        case .Valuation: return .GamingExpanded
        case .DueDiligence: return .GamingExpanded
        case .MAndA: return .GamingExpanded
        case .IPOs: return .GamingExpanded
        case .SPACs: return .GamingExpanded
        case .PCGaming: return .GamingExpanded
        case .PlayStation: return .GamingExpanded
        case .Xbox: return .GamingExpanded
        case .Nintendo: return .GamingExpanded
        case .MobileGaming: return .GamingExpanded
        case .CloudGaming: return .GamingExpanded
        case .VRGaming: return .GamingExpanded
        case .ARGaming: return .GamingExpanded
        case .LeagueofLegends: return .GamingExpanded
        case .DotaTwo: return .GamingExpanded
        case .CSGO: return .GamingExpanded
        case .Valorant: return .GamingExpanded
        case .Overwatch: return .GamingExpanded
        case .Fortnite: return .GamingExpanded
        case .RocketLeague: return .GamingExpanded
        case .FIFA: return .GamingExpanded
        case .NBATwoK: return .GamingExpanded
        case .CallofDuty: return .GamingExpanded
        case .TwitchStreaming: return .GamingExpanded
        case .YouTubeGaming: return .GamingExpanded
        case .KickStreaming: return .GamingExpanded
        case .Speedrunning: return .GamingExpanded
        case .GameReviews: return .GamingExpanded
        case .GameLore: return .GamingExpanded
        case .Walkthroughs: return .GamingExpanded
        case .GuidesAndTips: return .GamingExpanded
        case .BossStrategies: return .GamingExpanded
        case .BuildGuides: return .GamingExpanded
        case .WeaponGuides: return .GamingExpanded
        case .CharacterGuides: return .GamingExpanded
        case .TierLists: return .GamingExpanded
        case .PatchNotes: return .GamingExpanded
        case .MetaAnalysis: return .GamingExpanded
        case .GameDevelopment: return .MusicExpanded
        case .IndieGames: return .MusicExpanded
        case .AAAGames: return .MusicExpanded
        case .EarlyAccess: return .MusicExpanded
        case .CrowdfundingGames: return .MusicExpanded
        case .GameJams: return .MusicExpanded
        case .Modding: return .MusicExpanded
        case .CustomContent: return .MusicExpanded
        case .LevelDesign: return .MusicExpanded
        case .GameArt: return .MusicExpanded
        case .GameMusic: return .MusicExpanded
        case .GameWriting: return .MusicExpanded
        case .NarrativeDesign: return .MusicExpanded
        case .QATesting: return .MusicExpanded
        case .GameJournalism: return .MusicExpanded
        case .GamePreservation: return .MusicExpanded
        case .RetroGaming: return .MusicExpanded
        case .Emulation: return .MusicExpanded
        case .Arcade: return .MusicExpanded
        case .Pinball: return .MusicExpanded
        case .BoardGames: return .MusicExpanded
        case .TabletopRPGs: return .MusicExpanded
        case .DAndD: return .MusicExpanded
        case .Pathfinder: return .MusicExpanded
        case .CallofCthulhu: return .MusicExpanded
        case .CardGames: return .MusicExpanded
        case .MTG: return .MusicExpanded
        case .PokemonCards: return .MusicExpanded
        case .YuGiOh: return .MusicExpanded
        case .Chess: return .MusicExpanded
        case .Go: return .MusicExpanded
        case .StrategyGames: return .ArtAndDesignExpanded
        case .SimulationGames: return .ArtAndDesignExpanded
        case .RPGs: return .ArtAndDesignExpanded
        case .MMOs: return .ArtAndDesignExpanded
        case .SandboxGames: return .ArtAndDesignExpanded
        case .SurvivalGames: return .ArtAndDesignExpanded
        case .HorrorGames: return .ArtAndDesignExpanded
        case .PuzzleGames: return .ArtAndDesignExpanded
        case .Platformers: return .ArtAndDesignExpanded
        case .FightingGames: return .ArtAndDesignExpanded
        case .RacingGames: return .ArtAndDesignExpanded
        case .SportsGames: return .ArtAndDesignExpanded
        case .RhythmGames: return .ArtAndDesignExpanded
        case .VisualNovels: return .ArtAndDesignExpanded
        case .DatingSims: return .ArtAndDesignExpanded
        case .GachaGames: return .ArtAndDesignExpanded
        case .IdleGames: return .ArtAndDesignExpanded
        case .ClickerGames: return .ArtAndDesignExpanded
        case .Hypercasual: return .ArtAndDesignExpanded
        case .PartyGames: return .ArtAndDesignExpanded
        case .CoopGames: return .ArtAndDesignExpanded
        case .PvPGames: return .ParentingExpanded
        case .BattleRoyale: return .ParentingExpanded
        case .TacticalShooters: return .ParentingExpanded
        case .MOBA: return .ParentingExpanded
        case .RTS: return .ParentingExpanded
        case .ClassicalMusic: return .ParentingExpanded
        case .Opera: return .ParentingExpanded
        case .BaroqueMusic: return .ParentingExpanded
        case .Jazz: return .ParentingExpanded
        case .Blues: return .ParentingExpanded
        case .RockMusic: return .ParentingExpanded
        case .Metal: return .ParentingExpanded
        case .PopMusic: return .ParentingExpanded
        case .ElectronicMusic: return .ParentingExpanded
        case .HipHop: return .ParentingExpanded
        case .Reggaeton: return .ParentingExpanded
        case .Dancehall: return .ParentingExpanded
        case .Afrobeats: return .ParentingExpanded
        case .KPop: return .ParentingExpanded
        case .JPop: return .ParentingExpanded
        case .BollywoodMusic: return .ParentingExpanded
        case .CountryMusic: return .ParentingExpanded
        case .FolkMusic: return .ParentingExpanded
        case .WorldMusic: return .ParentingExpanded
        case .MusicProduction: return .PetsExpanded
        case .BeatMaking: return .PetsExpanded
        case .Sampling: return .PetsExpanded
        case .SoundDesign: return .PetsExpanded
        case .DJing: return .PetsExpanded
        case .Turntablism: return .PetsExpanded
        case .LivePerformance: return .PetsExpanded
        case .ConcertPhotography: return .PetsExpanded
        case .MusicTheory: return .PetsExpanded
        case .Composition: return .PetsExpanded
        case .Songwriting: return .PetsExpanded
        case .MusicBusiness: return .PetsExpanded
        case .Streaming: return .PetsExpanded
        case .PlaylistCuration: return .PetsExpanded
        case .Radio: return .PetsExpanded
        case .PodcastMusic: return .PetsExpanded
        case .FineArt: return .PetsExpanded
        case .OilPainting: return .PetsExpanded
        case .AcrylicPainting: return .PetsExpanded
        case .Watercolor: return .PetsExpanded
        case .DigitalArt: return .PetsExpanded
        case .ThreeDModeling: return .MentalHealthAndSpirituality
        case .Animation: return .MentalHealthAndSpirituality
        case .MotionGraphics: return .MentalHealthAndSpirituality
        case .GraphicDesign: return .MentalHealthAndSpirituality
        case .Typography: return .MentalHealthAndSpirituality
        case .UIDesign: return .MentalHealthAndSpirituality
        case .UXDesign: return .MentalHealthAndSpirituality
        case .WebDesign: return .MentalHealthAndSpirituality
        case .AppDesign: return .MentalHealthAndSpirituality
        case .Illustration: return .MentalHealthAndSpirituality
        case .ConceptArt: return .MentalHealthAndSpirituality
        case .CharacterDesign: return .MentalHealthAndSpirituality
        case .PixelArt: return .MentalHealthAndSpirituality
        case .VoxelArt: return .MentalHealthAndSpirituality
        case .GenerativeArt: return .MentalHealthAndSpirituality
        case .CreativeCoding: return .MentalHealthAndSpirituality
        case .Photography: return .MentalHealthAndSpirituality
        case .FilmPhotography: return .MentalHealthAndSpirituality
        case .StreetPhotography: return .MentalHealthAndSpirituality
        case .PortraitPhotography: return .MentalHealthAndSpirituality
        case .FashionPhotography: return .SocialJusticeAndActivism
        case .LandscapePhotography: return .SocialJusticeAndActivism
        case .DocumentaryPhotography: return .SocialJusticeAndActivism
        case .Pregnancy: return .SocialJusticeAndActivism
        case .Fertility: return .SocialJusticeAndActivism
        case .Birth: return .SocialJusticeAndActivism
        case .NewbornCare: return .SocialJusticeAndActivism
        case .InfantSleep: return .SocialJusticeAndActivism
        case .Breastfeeding: return .SocialJusticeAndActivism
        case .StartingSolids: return .SocialJusticeAndActivism
        case .ToddlerYears: return .SocialJusticeAndActivism
        case .Preschool: return .SocialJusticeAndActivism
        case .KOneTwoEducation: return .SocialJusticeAndActivism
        case .Homeschooling: return .SocialJusticeAndActivism
        case .GentleParenting: return .SocialJusticeAndActivism
        case .AttachmentParenting: return .SocialJusticeAndActivism
        case .PositiveDiscipline: return .SocialJusticeAndActivism
        case .ScreenTime: return .SocialJusticeAndActivism
        case .MentalHealthforKids: return .SocialJusticeAndActivism
        case .SpecialNeedsParenting: return .SocialJusticeAndActivism
        case .GiftedChildren: return .PoliticsAndEconomics
        case .SiblingRelationships: return .PoliticsAndEconomics
        case .SingleParenting: return .PoliticsAndEconomics
        case .WorkingParents: return .PoliticsAndEconomics
        case .TeenParenting: return .PoliticsAndEconomics
        case .CollegePrep: return .PoliticsAndEconomics
        case .EmptyNest: return .PoliticsAndEconomics
        case .DogCare: return .PoliticsAndEconomics
        case .CatCare: return .PoliticsAndEconomics
        case .BirdCare: return .PoliticsAndEconomics
        case .ReptileCare: return .PoliticsAndEconomics
        case .FishKeeping: return .PoliticsAndEconomics
        case .SmallMammals: return .PoliticsAndEconomics
        case .HorseCare: return .PoliticsAndEconomics
        case .PetTraining: return .PoliticsAndEconomics
        case .PetBehavior: return .MilitaryAndEmergency
        case .PetNutrition: return .MilitaryAndEmergency
        case .PetGrooming: return .MilitaryAndEmergency
        case .PetHealth: return .MilitaryAndEmergency
        case .PetInsurance: return .MilitaryAndEmergency
        case .PetPhotography: return .MilitaryAndEmergency
        case .DogAgility: return .MilitaryAndEmergency
        case .ServiceAnimals: return .MilitaryAndEmergency
        case .PetTech: return .MilitaryAndEmergency
        case .RawFeeding: return .MilitaryAndEmergency
        case .PetAdoption: return .MilitaryAndEmergency
        case .PetRescue: return .MilitaryAndEmergency
        case .PetFoster: return .MilitaryAndEmergency
        case .MentalHealthAndTherapy: return .MilitaryAndEmergency
        case .Psychology: return .MilitaryAndEmergency
        case .SelfImprovement: return .RealEstateAndHome
        case .Mindfulness: return .RealEstateAndHome
        case .Meditation: return .RealEstateAndHome
        case .Spirituality: return .RealEstateAndHome
        case .Astrology: return .RealEstateAndHome
        case .Tarot: return .RealEstateAndHome
        case .Witchcraft: return .RealEstateAndHome
        case .Paganism: return .RealEstateAndHome
        case .Christianity: return .RealEstateAndHome
        case .Islam: return .RealEstateAndHome
        case .Judaism: return .RealEstateAndHome
        case .Buddhism: return .RealEstateAndHome
        case .Hinduism: return .RealEstateAndHome
        case .Atheism: return .RealEstateAndHome
        case .Philosophy: return .RealEstateAndHome
        case .Ethics: return .RealEstateAndHome
        case .CriticalThinking: return .RealEstateAndHome
        case .Debate: return .RealEstateAndHome
        case .Environmentalism: return .RealEstateAndHome
        case .ClimateAction: return .RealEstateAndHome
        case .ZeroWaste: return .Automotive
        case .Sustainability: return .Automotive
        case .Conservation: return .Automotive
        case .SocialJustice: return .Automotive
        case .Activism: return .Automotive
        case .HumanRights: return .Automotive
        case .Feminism: return .Automotive
        case .LGBTQPlus: return .Automotive
        case .RacialJustice: return .Automotive
        case .DisabilityRights: return .Automotive
        case .AnimalRights: return .Automotive
        case .Veganism: return .Automotive
        case .EthicalConsumerism: return .Automotive
        case .Politics: return .Automotive
        case .CivicEngagement: return .Automotive
        case .Voting: return .EventPlanning
        case .PolicyAnalysis: return .EventPlanning
        case .Economics: return .EventPlanning
        case .MilitaryLife: return .EventPlanning
        case .Veterans: return .EventPlanning
        case .LawEnforcement: return .EventPlanning
        case .Firefighting: return .EventPlanning
        case .EMS: return .EventPlanning
        case .RealEstate: return .EventPlanning
        case .InteriorDesign: return .EventPlanning
        case .Architecture: return .WritingAndJournalism
        case .HomeRenovation: return .WritingAndJournalism
        case .Gardening: return .WritingAndJournalism
        case .Automotive: return .WritingAndJournalism
        case .CarReviews: return .WritingAndJournalism
        case .CarMaintenance: return .WritingAndJournalism
        case .Motorcycles: return .WritingAndJournalism
        case .ElectricVehicles: return .WritingAndJournalism
        case .EventPlanning: return .WritingAndJournalism
        case .WeddingPlanning: return .WritingAndJournalism
        case .PartyPlanning: return .WritingAndJournalism
        case .CorporateEvents: return .WritingAndJournalism
        case .Festivals: return .WritingAndJournalism
        case .Writing: return .WritingAndJournalism
        case .FictionWriting: return .WritingAndJournalism
        case .NonFictionWriting: return .WritingAndJournalism
        case .Poetry: return .WritingAndJournalism
        case .Screenwriting: return .WritingAndJournalism
        case .Journalism: return .WritingAndJournalism
        case .Blogging: return .WritingAndJournalism
        case .Copywriting: return .WritingAndJournalism
        case .TechnicalWriting: return .WritingAndJournalism
        case .Editing: return .WritingAndJournalism
        case .PerformingArts: return .WritingAndJournalism
        case .Theater: return .WritingAndJournalism
        case .Dance: return .PerformingArtsAndFilm
        case .Circus: return .PerformingArtsAndFilm
        case .StandUpComedy: return .PerformingArtsAndFilm
        case .Improv: return .PerformingArtsAndFilm
        case .Magic: return .PerformingArtsAndFilm
        case .Puppetry: return .PerformingArtsAndFilm
        case .VoiceActing: return .PerformingArtsAndFilm
        case .Acting: return .PerformingArtsAndFilm
        case .FilmMaking: return .PerformingArtsAndFilm
        case .Cinematography: return .PerformingArtsAndFilm
        case .Directing: return .PerformingArtsAndFilm
        case .Producing: return .PerformingArtsAndFilm
        case .FilmEditing: return .PerformingArtsAndFilm
        case .SoundDesign: return .PerformingArtsAndFilm
        case .ColorGrading: return .PerformingArtsAndFilm
        case .VFX: return .PerformingArtsAndFilm
        case .Stunts: return .PerformingArtsAndFilm
        case .CostumeDesign: return .PerformingArtsAndFilm
        case .Sports: return .PerformingArtsAndFilm
        case .Soccer: return .PerformingArtsAndFilm
        case .Basketball: return .PerformingArtsAndFilm
        case .Football: return .PerformingArtsAndFilm
        case .Baseball: return .PerformingArtsAndFilm
        case .Hockey: return .PerformingArtsAndFilm
        case .Tennis: return .PerformingArtsAndFilm
        case .Golf: return .PerformingArtsAndFilm
        case .Swimming: return .PerformingArtsAndFilm
        case .Gymnastics: return .PerformingArtsAndFilm
        case .Skateboarding: return .PerformingArtsAndFilm
        case .Snowboarding: return .PerformingArtsAndFilm
        case .Surfing: return .Sports
        case .RockClimbing: return .Sports
        case .MartialArts: return .Sports
        case .Boxing: return .Sports
        case .Wrestling: return .Sports
        case .FormulaOne: return .Sports
        case .NASCAR: return .Sports
        case .Motorsports: return .Sports
        case .Collecting: return .Sports
        case .StampCollecting: return .Sports
        case .CoinCollecting: return .Sports
        case .CardCollecting: return .Sports
        case .ToyCollecting: return .Sports
        case .AntiqueCollecting: return .Sports
        case .SneakerCollecting: return .Sports
        case .WatchCollecting: return .Sports
        case .ArtCollecting: return .Sports
        case .BookCollecting: return .Sports
        case .VintageComputing: return .Sports
        case .MechanicalKeyboards: return .Sports
        case .Audiophile: return .Sports
        case .HiFi: return .Sports
        case .VinylRecords: return .Sports
        case .CassetteTapes: return .Sports
        case .FilmPhotographyGear: return .Sports
        case .CameraCollecting: return .CollectingAndHobbies
        case .LensReviews: return .CollectingAndHobbies
        case .DronePiloting: return .CollectingAndHobbies
        case .HamRadio: return .CollectingAndHobbies
        case .AmateurRadio: return .CollectingAndHobbies
        case .Scanning: return .CollectingAndHobbies
        case .SatelliteTracking: return .CollectingAndHobbies
        case .Astronomy: return .CollectingAndHobbies
        case .Stargazing: return .CollectingAndHobbies
        case .Astrophotography: return .CollectingAndHobbies
        case .TelescopeReviews: return .CollectingAndHobbies
        case .SpaceExploration: return .CollectingAndHobbies
        case .NASA: return .CollectingAndHobbies
        case .SpaceX: return .CollectingAndHobbies
        case .Aviation: return .CollectingAndHobbies
        case .PlaneSpotting: return .CollectingAndHobbies
        case .FlightSimulators: return .CollectingAndHobbies
        case .PilotLife: return .CollectingAndHobbies
        case .Boating: return .CollectingAndHobbies
        case .Sailing: return .CollectingAndHobbies
        case .Yachting: return .CollectingAndHobbies
        case .Fishing: return .CollectingAndHobbies
        case .Hunting: return .CollectingAndHobbies
        case .Camping: return .CollectingAndHobbies
        case .Hiking: return .CollectingAndHobbies
        case .Backpacking: return .ScienceAndNature
        case .SurvivalSkills: return .ScienceAndNature
        case .Bushcraft: return .ScienceAndNature
        case .Foraging: return .ScienceAndNature
        case .WildEdibles: return .ScienceAndNature
        case .MushroomHunting: return .ScienceAndNature
        case .Herbalism: return .ScienceAndNature
        case .NaturalRemedies: return .ScienceAndNature
        case .Homesteading: return .ScienceAndNature
        case .Farming: return .ScienceAndNature
        case .Permaculture: return .ScienceAndNature
        case .RegenerativeAgriculture: return .ScienceAndNature
        case .UrbanFarming: return .ScienceAndNature
        case .Hydroponics: return .ScienceAndNature
        case .Aquaponics: return .ScienceAndNature
        case .Composting: return .ScienceAndNature
        case .Beekeeping: return .ScienceAndNature
        case .ChickenKeeping: return .ScienceAndNature
        case .Knitting: return .ScienceAndNature
        case .Crocheting: return .ScienceAndNature
        case .Sewing: return .ScienceAndNature
        case .Quilting: return .ScienceAndNature
        case .Embroidery: return .ScienceAndNature
        case .CrossStitch: return .ScienceAndNature
        case .Macrame: return .ScienceAndNature
        case .Weaving: return .ScienceAndNature
        case .Spinning: return .ScienceAndNature
        case .Dyeing: return .ScienceAndNature
        case .Pottery: return .ScienceAndNature
        case .Ceramics: return .ScienceAndNature
        case .Sculpture: return .CraftsAndMaking
        case .Woodworking: return .CraftsAndMaking
        case .Carpentry: return .CraftsAndMaking
        case .Metalworking: return .CraftsAndMaking
        case .Blacksmithing: return .CraftsAndMaking
        case .JewelryMaking: return .CraftsAndMaking
        case .LeatherCraft: return .CraftsAndMaking
        case .GlassBlowing: return .CraftsAndMaking
        case .Origami: return .CraftsAndMaking
        case .PaperCraft: return .CraftsAndMaking
        case .Bookbinding: return .CraftsAndMaking
        case .Printmaking: return .CraftsAndMaking
        case .ScreenPrinting: return .CraftsAndMaking
        case .Calligraphy: return .CraftsAndMaking
        case .HandLettering: return .CraftsAndMaking
        case .SignPainting: return .CraftsAndMaking
        case .MuralArt: return .CraftsAndMaking
        case .Graffiti: return .CraftsAndMaking
        case .TattooArt: return .CraftsAndMaking
        case .TattooDesign: return .CraftsAndMaking
        case .Piercing: return .CraftsAndMaking
        case .BodyModification: return .CraftsAndMaking
        case .CosplayMaking: return .CraftsAndMaking
        case .LARP: return .CraftsAndMaking
        case .RenaissanceFaire: return .CraftsAndMaking
        case .SteampunkCrafting: return .CraftsAndMaking
        case .PropMaking: return .CraftsAndMaking
        case .ModelBuilding: return .CraftsAndMaking
        case .RCVehicles: return .CraftsAndMaking
        case .ModelTrains: return .CraftsAndMaking
        case .Diorama: return .CraftsAndMaking
        case .MiniaturePainting: return .CraftsAndMaking
        case .Warhammer: return .CraftsAndMaking
        case .DungeonsAndDragons: return .CraftsAndMaking
        case .TabletopWargaming: return .CraftsAndMaking
        case .BoardGameDesign: return .CraftsAndMaking
        case .PuzzleDesign: return .CraftsAndMaking
        case .EscapeRooms: return .CraftsAndMaking
        case .TrueCrime: return .CraftsAndMaking
        case .ConspiracyTheories: return .CraftsAndMaking
        case .Paranormal: return .GamingAndEntertainment
        case .UFOs: return .GamingAndEntertainment
        case .Cryptozoology: return .GamingAndEntertainment
        case .UrbanExploration: return .GamingAndEntertainment
        case .AbandonedPlaces: return .GamingAndEntertainment
        case .GhostHunting: return .GamingAndEntertainment
        case .ASMR: return .GamingAndEntertainment
        case .Mukbang: return .GamingAndEntertainment
        case .ReactionVideos: return .GamingAndEntertainment
        case .Commentary: return .GamingAndEntertainment
        case .Drama: return .GamingAndEntertainment
        case .Tea: return .GamingAndEntertainment
        case .StanCulture: return .GamingAndEntertainment
        case .Fandom: return .GamingAndEntertainment
        case .Shipping: return .GamingAndEntertainment
        case .FanFiction: return .GamingAndEntertainment
        case .FanArt: return .GamingAndEntertainment
        case .Cosplay: return .GamingAndEntertainment
        case .MemeCulture: return .GamingAndEntertainment
        case .InternetCulture: return .GamingAndEntertainment
        case .TikTokTrends: return .GamingAndEntertainment
        case .ViralChallenges: return .GamingAndEntertainment
        case .DanceTrends: return .GamingAndEntertainment
        case .LanguageLearning: return .GamingAndEntertainment
        case .SignLanguage: return .GamingAndEntertainment
        case .Esperanto: return .GamingAndEntertainment
        case .Conlanging: return .GamingAndEntertainment
        case .Translation: return .GamingAndEntertainment
        case .Linguistics: return .GamingAndEntertainment
        case .Etymology: return .GamingAndEntertainment
        case .Dialects: return .BusinessAndMarketing
        case .Accents: return .BusinessAndMarketing
        case .SpeechTherapy: return .BusinessAndMarketing
        case .PublicSpeaking: return .BusinessAndMarketing
        case .Debate: return .BusinessAndMarketing
        case .Negotiation: return .BusinessAndMarketing
        case .Sales: return .BusinessAndMarketing
        case .Marketing: return .BusinessAndMarketing
        case .SEO: return .BusinessAndMarketing
        case .ContentMarketing: return .BusinessAndMarketing
        case .SocialMediaMarketing: return .BusinessAndMarketing
        case .EmailMarketing: return .BusinessAndMarketing
        case .InfluencerMarketing: return .BusinessAndMarketing
        case .BrandBuilding: return .BusinessAndMarketing
        case .PersonalBranding: return .BusinessAndMarketing
        case .Networking: return .BusinessAndMarketing
        case .PublicRelations: return .BusinessAndMarketing
        case .CrisisManagement: return .BusinessAndMarketing
        case .HumanResources: return .BusinessAndMarketing
        case .Recruiting: return .BusinessAndMarketing
        case .TalentManagement: return .BusinessAndMarketing
        case .EmployeeEngagement: return .BusinessAndMarketing
        case .RemoteWork: return .BusinessAndMarketing
        case .DigitalNomad: return .BusinessAndMarketing
        case .Coworking: return .BusinessAndMarketing
        case .Freelancing: return .BusinessAndMarketing
        case .SideHustle: return .BusinessAndMarketing
        case .PassiveIncome: return .BusinessAndMarketing
        case .Entrepreneurship: return .BusinessAndMarketing
        case .Startups: return .BusinessAndMarketing
        case .VentureCapital: return .BusinessAndMarketing
        case .AngelInvesting: return .BusinessAndMarketing
        case .BusinessStrategy: return .BusinessAndMarketing
        case .Management: return .BusinessAndMarketing
        case .Leadership: return .BusinessAndMarketing
        case .TeamBuilding: return .BusinessAndMarketing
        case .ProjectManagement: return .BusinessAndMarketing
        case .Agile: return .BusinessAndMarketing
        case .Scrum: return .BusinessAndMarketing
        case .Kanban: return .BusinessAndMarketing
        case .Lean: return .EngineeringAndManufacturing
        case .SixSigma: return .EngineeringAndManufacturing
        case .ProcessImprovement: return .EngineeringAndManufacturing
        case .SupplyChain: return .EngineeringAndManufacturing
        case .Logistics: return .EngineeringAndManufacturing
        case .Operations: return .EngineeringAndManufacturing
        case .QualityControl: return .EngineeringAndManufacturing
        case .Manufacturing: return .EngineeringAndManufacturing
        case .IndustrialDesign: return .EngineeringAndManufacturing
        case .ProductDesign: return .EngineeringAndManufacturing
        case .PackagingDesign: return .EngineeringAndManufacturing
        case .UXResearch: return .EngineeringAndManufacturing
        case .UserTesting: return .EngineeringAndManufacturing
        case .DataAnalysis: return .EngineeringAndManufacturing
        case .BusinessIntelligence: return .EngineeringAndManufacturing
        case .DataVisualization: return .EngineeringAndManufacturing
        case .DashboardDesign: return .EngineeringAndManufacturing
        case .KPITracking: return .EngineeringAndManufacturing
        case .Accounting: return .EngineeringAndManufacturing
        case .Bookkeeping: return .EngineeringAndManufacturing
        case .Auditing: return .EngineeringAndManufacturing
        case .TaxPreparation: return .EngineeringAndManufacturing
        case .FinancialPlanning: return .EngineeringAndManufacturing
        case .Insurance: return .EngineeringAndManufacturing
        case .RiskManagement: return .EngineeringAndManufacturing
        case .Compliance: return .EngineeringAndManufacturing
        case .LegalAnalysis: return .EngineeringAndManufacturing
        case .ContractLaw: return .EngineeringAndManufacturing
        case .IntellectualProperty: return .EngineeringAndManufacturing
        case .Copyright: return .EngineeringAndManufacturing
        case .Trademark: return .EngineeringAndManufacturing
        case .Patents: return .EngineeringAndManufacturing
        case .Licensing: return .EngineeringAndManufacturing
        case .RealEstateInvesting: return .EngineeringAndManufacturing
        case .PropertyManagement: return .EngineeringAndManufacturing
        case .HouseFlipping: return .HealthAndWellness
        case .RentalProperties: return .HealthAndWellness
        case .CommercialRealEstate: return .HealthAndWellness
        case .MortgageBrokering: return .HealthAndWellness
        case .InteriorStaging: return .HealthAndWellness
        case .HomeInspection: return .HealthAndWellness
        case .Architecture: return .HealthAndWellness
        case .LandscapeDesign: return .HealthAndWellness
        case .Construction: return .HealthAndWellness
        case .CivilEngineering: return .HealthAndWellness
        case .StructuralEngineering: return .HealthAndWellness
        case .MechanicalEngineering: return .HealthAndWellness
        case .ElectricalEngineering: return .HealthAndWellness
        case .SoftwareEngineering: return .HealthAndWellness
        case .DevOps: return .HealthAndWellness
        case .SRE: return .HealthAndWellness
        case .CloudArchitecture: return .HealthAndWellness
        case .SystemDesign: return .HealthAndWellness
        case .DatabaseAdministration: return .HealthAndWellness
        case .NetworkEngineering: return .HealthAndWellness
        case .Cybersecurity: return .HealthAndWellness
        case .EthicalHacking: return .HealthAndWellness
        case .PenetrationTesting: return .HealthAndWellness
        case .IncidentResponse: return .HealthAndWellness
        case .DigitalForensics: return .HealthAndWellness
        case .ThreatIntelligence: return .HealthAndWellness
        case .Compliance: return .HealthAndWellness
        case .GDPR: return .HealthAndWellness
        case .Accessibility: return .HealthAndWellness
        case .WCAG: return .HealthAndWellness
        case .InclusiveDesign: return .EducationAndLearning
        case .UniversalDesign: return .EducationAndLearning
        case .AssistiveTechnology: return .EducationAndLearning
        case .Neurodiversity: return .EducationAndLearning
        case .ADHD: return .EducationAndLearning
        case .Autism: return .EducationAndLearning
        case .Dyslexia: return .EducationAndLearning
        case .Anxiety: return .EducationAndLearning
        case .Depression: return .EducationAndLearning
        case .Bipolar: return .EducationAndLearning
        case .OCD: return .EducationAndLearning
        case .PTSD: return .EducationAndLearning
        case .EatingDisorders: return .EducationAndLearning
        case .AddictionRecovery: return .EducationAndLearning
        case .SubstanceAbuse: return .EducationAndLearning
        case .OneTwoStep: return .EducationAndLearning
        case .HarmReduction: return .EducationAndLearning
        case .SoberLiving: return .EducationAndLearning
        case .PhysicalTherapy: return .EducationAndLearning
        case .OccupationalTherapy: return .EducationAndLearning
        case .SpeechTherapy: return .EducationAndLearning
        case .MassageTherapy: return .EducationAndLearning
        case .Chiropractic: return .EducationAndLearning
        case .Acupuncture: return .EducationAndLearning
        case .TraditionalChineseMedicine: return .EducationAndLearning
        case .Ayurveda: return .MediaAndBroadcasting
        case .Homeopathy: return .MediaAndBroadcasting
        case .Naturopathy: return .MediaAndBroadcasting
        case .FunctionalMedicine: return .MediaAndBroadcasting
        case .IntegrativeMedicine: return .MediaAndBroadcasting
        case .HolisticHealth: return .MediaAndBroadcasting
        case .WellnessCoaching: return .MediaAndBroadcasting
        case .LifeCoaching: return .MediaAndBroadcasting
        case .CareerCoaching: return .MediaAndBroadcasting
        case .ExecutiveCoaching: return .MediaAndBroadcasting
        case .RelationshipCoaching: return .MediaAndBroadcasting
        case .DatingAdvice: return .MediaAndBroadcasting
        case .MarriageCounseling: return .MediaAndBroadcasting
        case .DivorceRecovery: return .MediaAndBroadcasting
        case .CoParenting: return .MediaAndBroadcasting
        case .BlendedFamilies: return .MediaAndBroadcasting
        case .Adoption: return .MediaAndBroadcasting
        case .FosterCare: return .MediaAndBroadcasting
        case .SeniorCare: return .MediaAndBroadcasting
        case .ElderCare: return .MediaAndBroadcasting
        case .DementiaCare: return .MediaAndBroadcasting
        case .Alzheimers: return .MediaAndBroadcasting
        case .Parkinsons: return .MediaAndBroadcasting
        case .Hospice: return .MediaAndBroadcasting
        case .EndofLife: return .MediaAndBroadcasting
        case .GriefSupport: return .Additional
        case .Bereavement: return .Additional
        case .DeathPositivity: return .Additional
        case .LegacyPlanning: return .Additional
        case .Genealogy: return .Additional
        case .DNATesting: return .Additional
        case .Ancestry: return .Additional
        case .FamilyHistory: return .Additional
        case .MilitaryHistory: return .Additional
        case .WarHistory: return .Additional
        case .AncientHistory: return .Additional
        case .MedievalHistory: return .Additional
        case .Renaissance: return .Additional
        case .Enlightenment: return .Additional
        case .IndustrialRevolution: return .Additional
        case .WorldWarI: return .Additional
        case .WorldWarII: return .Additional
        case .ColdWar: return .Additional
        case .Decolonization: return .Additional
        case .CivilRightsMovement: return .Additional
        case .WomensSuffrage: return .Additional
        case .LaborHistory: return .Additional
        case .EconomicHistory: return .Additional
        case .HistoryofScience: return .Additional
        case .HistoryofTechnology: return .Additional
        case .HistoryofArt: return .Additional
        case .HistoryofMusic: return .Additional
        case .HistoryofFashion: return .Additional
        case .Archaeology: return .Additional
        case .Anthropology: return .Additional
        case .CulturalStudies: return .Additional
        case .Sociology: return .Additional
        case .SocialPsychology: return .Additional
        case .CognitivePsychology: return .Additional
        case .DevelopmentalPsychology: return .Additional
        case .ClinicalPsychology: return .Additional
        case .ForensicPsychology: return .Additional
        case .SportsPsychology: return .Additional
        case .PositivePsychology: return .Additional
        case .BehavioralEconomics: return .Additional
        case .GameTheory: return .Additional
        case .DecisionScience: return .Additional
        case .RiskAssessment: return .Additional
        case .ForensicScience: return .Additional
        case .CriminalJustice: return .Additional
        case .LawEnforcement: return .Additional
        case .PrivateInvestigation: return .Additional
        case .Security: return .Additional
        case .FireSafety: return .Additional
        case .EmergencyManagement: return .Additional
        case .DisasterPreparedness: return .Additional
        case .FirstAid: return .Additional
        case .CPR: return .Additional
        case .SearchandRescue: return .Additional
        case .KNineUnits: return .Additional
        case .MountedPolice: return .Additional
        case .CoastGuard: return .Additional
        case .BorderPatrol: return .Additional
        case .Customs: return .Additional
        case .Immigration: return .Additional
        case .Diplomacy: return .Additional
        case .InternationalRelations: return .Additional
        case .Geopolitics: return .Additional
        case .ConflictResolution: return .Additional
        case .Peacekeeping: return .Additional
        case .HumanitarianAid: return .Additional
        case .NGOWork: return .Additional
        case .NonprofitManagement: return .Additional
        case .Fundraising: return .Additional
        case .GrantWriting: return .Additional
        case .VolunteerManagement: return .Additional
        case .CommunityOrganizing: return .Additional
        case .SocialWork: return .Additional
        case .SchoolCounseling: return .Additional
        case .CollegeCounseling: return .Additional
        case .CareerServices: return .Additional
        case .VocationalTraining: return .Additional
        case .Apprenticeships: return .Additional
        case .TradeSkills: return .Additional
        case .Electrician: return .Additional
        case .Plumber: return .Additional
        case .HVAC: return .Additional
        case .Carpentry: return .Additional
        case .Masonry: return .Additional
        case .Welding: return .Additional
        case .AutoMechanics: return .Additional
        case .DieselMechanics: return .Additional
        case .AviationMechanics: return .Additional
        case .MarineMechanics: return .Additional
        case .Machining: return .Additional
        case .CNC: return .Additional
        case .ThreeDPrinting: return .Additional
        case .LaserCutting: return .Additional
        case .Robotics: return .Additional
        case .Automation: return .Additional
        case .IndustrialIoT: return .Additional
        case .SmartManufacturing: return .Additional
        case .PredictiveMaintenance: return .Additional
        case .QualityAssurance: return .Additional
        case .SixSigma: return .Additional
        case .LeanManufacturing: return .Additional
        case .Kaizen: return .Additional
        case .TotalQualityManagement: return .Additional
        case .SupplyChainOptimization: return .Additional
        case .InventoryManagement: return .Additional
        case .WarehouseOperations: return .Additional
        case .Distribution: return .Additional
        case .LastMileDelivery: return .Additional
        case .FleetManagement: return .Additional
        case .RouteOptimization: return .Additional
        case .Telematics: return .Additional
        case .AutonomousVehicles: return .Additional
        case .Drones: return .Additional
        case .SpaceIndustry: return .Additional
        case .SatelliteTechnology: return .Additional
        case .Aerospace: return .Additional
        case .Defense: return .Additional
        case .NationalSecurity: return .Additional
        case .IntelligenceAnalysis: return .Additional
        case .Counterterrorism: return .Additional
        case .CyberWarfare: return .Additional
        case .InformationWarfare: return .Additional
        case .PropagandaAnalysis: return .Additional
        case .Disinformation: return .Additional
        case .FactChecking: return .Additional
        case .MediaLiteracy: return .Additional
        case .JournalismEthics: return .Additional
        case .InvestigativeJournalism: return .Additional
        case .DataJournalism: return .Additional
        case .Photojournalism: return .Additional
        case .BroadcastJournalism: return .Additional
        case .SportsJournalism: return .Additional
        case .EntertainmentJournalism: return .Additional
        case .FashionJournalism: return .Additional
        case .FoodWriting: return .Additional
        case .TravelWriting: return .Additional
        case .ScienceWriting: return .Additional
        case .TechnicalWriting: return .Additional
        case .MedicalWriting: return .Additional
        case .GrantWriting: return .Additional
        case .SpeechWriting: return .Additional
        case .GhostWriting: return .Additional
        case .ResumeWriting: return .Additional
        case .Translation: return .Additional
        case .Interpretation: return .Additional
        case .Localization: return .Additional
        case .Subtitling: return .Additional
        case .Dubbing: return .Additional
        case .VoiceOver: return .Additional
        case .Narration: return .Additional
        case .Audiobooks: return .Additional
        case .Podcasting: return .Additional
        case .RadioBroadcasting: return .Additional
        case .TVBroadcasting: return .Additional
        case .Streaming: return .Additional
        case .ContentCreation: return .Additional
        case .YouTube: return .Additional
        case .TikTok: return .Additional
        case .Instagram: return .Additional
        case .TwitterX: return .Additional
        case .LinkedIn: return .Additional
        case .Pinterest: return .Additional
        case .Snapchat: return .Additional
        case .Reddit: return .Additional
        case .Discord: return .Additional
        case .Twitch: return .Additional
        case .Kick: return .Additional
        case .Patreon: return .Additional
        case .OnlyFans: return .Additional
        case .Substack: return .Additional
        case .Medium: return .Additional
        case .Devto: return .Additional
        case .GitHub: return .Additional
        case .StackOverflow: return .Additional
        case .HackerNews: return .Additional
        case .ProductHunt: return .Additional
        case .IndieHackers: return .Additional
        case .BetaList: return .Additional
        case .AngelList: return .Additional
        case .Crunchbase: return .Additional
        case .PitchBook: return .Additional
        case .Bloomberg: return .Additional
        case .Reuters: return .Additional
        case .AssociatedPress: return .Additional
        case .BBC: return .Additional
        case .CNN: return .Additional
        case .FoxNews: return .Additional
        case .MSNBC: return .Additional
        case .AlJazeera: return .Additional
        case .RT: return .Additional
        case .CGTN: return .Additional
        case .NHK: return .Additional
        case .FranceTwoFour: return .Additional
        case .DeutscheWelle: return .Additional
        case .VoiceofAmerica: return .Additional
        case .RadioFreeEurope: return .Additional
        case .BBCWorldService: return .Additional
        case .Podcasts: return .Additional
        }
    }
}

// MARK: - Niche Model
/// Full niche descriptor with metadata for template matching
public struct NicheModel: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let niche: ContentNiche
    public let category: ContentNicheCategory
    public let description: String
    public let keywords: [String]
    public let suggestedPlatforms: [Platform]
    public let suggestedArchetypes: [ContentArchetype]
    public let suggestedStyles: [VisualStyle]

    public init(
        niche: ContentNiche,
        description: String = "",
        keywords: [String] = [],
        suggestedPlatforms: [Platform] = [.general],
        suggestedArchetypes: [ContentArchetype] = [],
        suggestedStyles: [VisualStyle] = []
    ) {
        self.id = niche.rawValue
        self.niche = niche
        self.category = niche.category
        self.description = description
        self.keywords = keywords
        self.suggestedPlatforms = suggestedPlatforms
        self.suggestedArchetypes = suggestedArchetypes
        self.suggestedStyles = suggestedStyles
    }
}

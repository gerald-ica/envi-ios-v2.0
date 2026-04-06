import Foundation

// MARK: - Tutorial Step

/// A single step within a tutorial.
struct TutorialStep: Identifiable, Codable {
    let id: UUID
    let title: String
    let description: String
    let actionType: ActionType

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        actionType: ActionType
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.actionType = actionType
    }

    enum ActionType: String, Codable, CaseIterable {
        case tap
        case swipe
        case input
        case navigate
        case observe
        case configure

        var iconName: String {
            switch self {
            case .tap:       return "hand.tap"
            case .swipe:     return "hand.draw"
            case .input:     return "keyboard"
            case .navigate:  return "arrow.right.circle"
            case .observe:   return "eye"
            case .configure: return "gearshape"
            }
        }
    }
}

// MARK: - Tutorial

/// An interactive tutorial consisting of ordered steps.
struct Tutorial: Identifiable, Codable {
    let id: UUID
    let title: String
    let category: Category
    let steps: [TutorialStep]
    var completionRate: Double

    init(
        id: UUID = UUID(),
        title: String,
        category: Category,
        steps: [TutorialStep],
        completionRate: Double = 0.0
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.steps = steps
        self.completionRate = completionRate
    }

    enum Category: String, Codable, CaseIterable, Identifiable {
        case gettingStarted
        case contentCreation
        case analytics
        case scheduling
        case collaboration
        case advanced

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .gettingStarted:   return "Getting Started"
            case .contentCreation:  return "Content Creation"
            case .analytics:        return "Analytics"
            case .scheduling:       return "Scheduling"
            case .collaboration:    return "Collaboration"
            case .advanced:         return "Advanced"
            }
        }

        var iconName: String {
            switch self {
            case .gettingStarted:   return "play.circle"
            case .contentCreation:  return "square.and.pencil"
            case .analytics:        return "chart.bar"
            case .scheduling:       return "calendar"
            case .collaboration:    return "person.2"
            case .advanced:         return "star"
            }
        }
    }

    var isCompleted: Bool { completionRate >= 1.0 }
    var completedSteps: Int { Int(Double(steps.count) * completionRate) }
}

// MARK: - Coaching Tip

/// A contextual coaching tip shown as an overlay.
struct CoachingTip: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let context: Context
    let priority: Priority

    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        context: Context,
        priority: Priority = .medium
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.context = context
        self.priority = priority
    }

    enum Context: String, Codable, CaseIterable {
        case editor
        case analytics
        case publishing
        case scheduling
        case feed
        case general

        var iconName: String {
            switch self {
            case .editor:      return "pencil.tip"
            case .analytics:   return "chart.xyaxis.line"
            case .publishing:  return "paperplane"
            case .scheduling:  return "clock"
            case .feed:        return "rectangle.grid.1x2"
            case .general:     return "lightbulb"
            }
        }
    }

    enum Priority: String, Codable, Comparable {
        case low
        case medium
        case high

        private var sortOrder: Int {
            switch self {
            case .low:    return 0
            case .medium: return 1
            case .high:   return 2
            }
        }

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}

// MARK: - Achievement Badge

/// A gamification badge that can be earned by completing actions.
struct AchievementBadge: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    var earnedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        iconName: String,
        earnedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconName = iconName
        self.earnedAt = earnedAt
    }

    var isEarned: Bool { earnedAt != nil }
}

// MARK: - Learning Path

/// A curated sequence of tutorials forming a learning path.
struct LearningPath: Identifiable, Codable {
    let id: UUID
    let name: String
    let tutorials: [Tutorial]
    var progress: Double

    init(
        id: UUID = UUID(),
        name: String,
        tutorials: [Tutorial],
        progress: Double = 0.0
    ) {
        self.id = id
        self.name = name
        self.tutorials = tutorials
        self.progress = progress
    }

    var completedTutorials: Int {
        tutorials.filter { $0.isCompleted }.count
    }

    var totalTutorials: Int { tutorials.count }
}

// MARK: - Mock Data

extension Tutorial {
    static let mock: [Tutorial] = [
        Tutorial(
            title: "Create Your First Post",
            category: .gettingStarted,
            steps: [
                TutorialStep(title: "Open Editor", description: "Tap the + button to start a new post.", actionType: .tap),
                TutorialStep(title: "Add Media", description: "Select photos or videos from your library.", actionType: .tap),
                TutorialStep(title: "Write Caption", description: "Write an engaging caption with hashtags.", actionType: .input),
                TutorialStep(title: "Publish", description: "Review and publish your content.", actionType: .tap),
            ],
            completionRate: 0.75
        ),
        Tutorial(
            title: "Schedule Content",
            category: .scheduling,
            steps: [
                TutorialStep(title: "Open Calendar", description: "Navigate to the scheduling calendar.", actionType: .navigate),
                TutorialStep(title: "Pick a Slot", description: "Select an optimal time slot.", actionType: .tap),
                TutorialStep(title: "Confirm Schedule", description: "Review and confirm your scheduled post.", actionType: .tap),
            ],
            completionRate: 0.0
        ),
        Tutorial(
            title: "Read Your Analytics",
            category: .analytics,
            steps: [
                TutorialStep(title: "Open Insights", description: "Navigate to the analytics dashboard.", actionType: .navigate),
                TutorialStep(title: "Review Metrics", description: "Understand reach, engagement, and growth.", actionType: .observe),
                TutorialStep(title: "Export Report", description: "Download or share your analytics report.", actionType: .tap),
            ],
            completionRate: 1.0
        ),
        Tutorial(
            title: "Collaborate with Team",
            category: .collaboration,
            steps: [
                TutorialStep(title: "Invite Members", description: "Add team members to your workspace.", actionType: .input),
                TutorialStep(title: "Assign Roles", description: "Configure permissions for each member.", actionType: .configure),
            ],
            completionRate: 0.5
        ),
    ]
}

extension CoachingTip {
    static let mock: [CoachingTip] = [
        CoachingTip(title: "Best Time to Post", message: "Your audience is most active between 6-8 PM. Schedule posts during this window for maximum reach.", context: .scheduling, priority: .high),
        CoachingTip(title: "Use Carousel Posts", message: "Carousel posts get 1.4x more reach than single images. Try creating multi-slide content.", context: .editor, priority: .medium),
        CoachingTip(title: "Hashtag Strategy", message: "Mix popular and niche hashtags. Aim for 15-20 relevant hashtags per post.", context: .publishing, priority: .medium),
        CoachingTip(title: "Track Weekly Trends", message: "Check your analytics every Monday to spot trends early.", context: .analytics, priority: .low),
    ]
}

extension AchievementBadge {
    static let mock: [AchievementBadge] = [
        AchievementBadge(name: "First Post", description: "Published your first piece of content.", iconName: "star.fill", earnedAt: Date().addingTimeInterval(-86400 * 30)),
        AchievementBadge(name: "Streak Master", description: "Posted content 7 days in a row.", iconName: "flame.fill", earnedAt: Date().addingTimeInterval(-86400 * 10)),
        AchievementBadge(name: "Analytics Pro", description: "Reviewed analytics for 30 days straight.", iconName: "chart.bar.fill", earnedAt: nil),
        AchievementBadge(name: "Collaborator", description: "Invited 3 team members to your workspace.", iconName: "person.2.fill", earnedAt: nil),
        AchievementBadge(name: "Scheduler", description: "Scheduled 50 posts in advance.", iconName: "calendar.badge.clock", earnedAt: Date().addingTimeInterval(-86400 * 5)),
        AchievementBadge(name: "Viral Hit", description: "A post reached 10,000+ impressions.", iconName: "bolt.fill", earnedAt: nil),
        AchievementBadge(name: "Content Machine", description: "Published 100 posts across all platforms.", iconName: "square.stack.3d.up.fill", earnedAt: nil),
        AchievementBadge(name: "Early Adopter", description: "Joined ENVI within the first month.", iconName: "gift.fill", earnedAt: Date().addingTimeInterval(-86400 * 60)),
    ]
}

extension LearningPath {
    static let mock: [LearningPath] = [
        LearningPath(name: "Creator Fundamentals", tutorials: Array(Tutorial.mock.prefix(2)), progress: 0.4),
        LearningPath(name: "Growth Mastery", tutorials: Array(Tutorial.mock.suffix(2)), progress: 0.75),
    ]
}

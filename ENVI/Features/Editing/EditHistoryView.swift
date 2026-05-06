import SwiftUI
import SwiftData

// MARK: - Edit History View
/// Browse, filter, and manage all ENVI edit history.
@MainActor
public struct EditHistoryView: View {
    @Query(sort: \EditRecord.createdAt, order: .reverse) private var records: [EditRecord]
    @State private var filter: HistoryFilter = .all
    @State private var dateRange: DateRangeFilter = .allTime
    @State private var formatFilter: ContentFormat?
    @State private var searchQuery: String = ""
    @State private var selectedRecord: EditRecord?
    @State private var showExportSheet: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var recordToDelete: EditRecord?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter bar
                HistoryFilterBar(
                    filter: $filter,
                    dateRange: $dateRange,
                    formatFilter: $formatFilter,
                    onClear: clearFilters
                )

                // Search
                if !filteredRecords.isEmpty {
                    SearchBar(query: $searchQuery, onSearch: {})
                        .padding(.horizontal)
                        .padding(.top, 8)
                }

                // Stats summary
                HistoryStatsBar(records: filteredRecords)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                // Record list
                List {
                    ForEach(groupedRecords.keys.sorted(by: >), id: \.self) { section in
                        Section(header: Text(section).font(.caption)) {
                            ForEach(groupedRecords[section] ?? []) { record in
                                HistoryRow(record: record)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecord = record
                                    }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            recordToDelete = record
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        if record.decision == .rejected {
                                            Button {
                                                retryRecord(record)
                                            } label: {
                                                Label("Retry", systemImage: "arrow.clockwise")
                                            }
                                            .tint(.blue)
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showExportSheet = true }) {
                            Label("Export JSON", systemImage: "square.and.arrow.up")
                        }
                        Button(role: .destructive, action: deleteAll) {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedRecord) { record in
                RecordDetailView(record: record)
            }
            .confirmationDialog(
                "Delete this edit?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let record = recordToDelete {
                        deleteRecord(record)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Filtering

    private var filteredRecords: [EditRecord] {
        var result = Array(records)

        // Apply decision filter
        switch filter {
        case .all: break
        case .approved: result = result.filter { $0.decision == .approved }
        case .rejected: result = result.filter { $0.decision == .rejected }
        case .saved: result = result.filter { $0.decision == .saved }
        }

        // Apply date range
        let calendar = Calendar.current
        let now = Date()
        switch dateRange {
        case .allTime: break
        case .today:
            result = result.filter { calendar.isDateInToday($0.createdAt) }
        case .thisWeek:
            result = result.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .weekOfYear) }
        case .thisMonth:
            result = result.filter { calendar.isDate($0.createdAt, equalTo: now, toGranularity: .month) }
        }

        // Apply format filter
        if let format = formatFilter {
            result = result.filter { $0.format == format }
        }

        // Apply search
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter {
                $0.templateName.lowercased().contains(query) ||
                $0.styleName.lowercased().contains(query) ||
                $0.nicheName.lowercased().contains(query)
            }
        }

        return result
    }

    private var groupedRecords: [String: [EditRecord]] {
        let calendar = Calendar.current
        var groups: [String: [EditRecord]] = [:]

        for record in filteredRecords {
            let section: String
            if calendar.isDateInToday(record.createdAt) {
                section = "Today"
            } else if calendar.isDateInYesterday(record.createdAt) {
                section = "Yesterday"
            } else {
                section = calendar.date(from: calendar.dateComponents([.year, .month], from: record.createdAt))?
                    .formatted(.dateTime.month(.wide).year()) ?? "Earlier"
            }
            groups[section, default: []].append(record)
        }

        return groups
    }

    // MARK: - Actions

    private func clearFilters() {
        filter = .all
        dateRange = .allTime
        formatFilter = nil
        searchQuery = ""
    }

    private func deleteRecord(_ record: EditRecord) {
        // SwiftData delete
        let context = record.modelContext
        context?.delete(record)
        try? context?.save()
    }

    private func deleteAll() {
        let context = records.first?.modelContext
        for record in records {
            context?.delete(record)
        }
        try? context?.save()
    }

    private func retryRecord(_ record: EditRecord) {
        // In production: trigger reverse edit with same source, different template
    }

    private func exportToJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(filteredRecords) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Filter Types

enum HistoryFilter: String, CaseIterable {
    case all = "All"
    case approved = "Approved"
    case rejected = "Rejected"
    case saved = "Saved"
}

enum DateRangeFilter: String, CaseIterable {
    case allTime = "All Time"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
}

// MARK: - History Filter Bar

struct HistoryFilterBar: View {
    @Binding var filter: HistoryFilter
    @Binding var dateRange: DateRangeFilter
    @Binding var formatFilter: ContentFormat?
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Decision filter
            Picker("Filter", selection: $filter) {
                ForEach(HistoryFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            // Secondary filters
            HStack(spacing: 12) {
                Menu {
                    ForEach(DateRangeFilter.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            dateRange = range
                        }
                    }
                } label: {
                    Label(dateRange.rawValue, systemImage: "calendar")
                        .font(.caption)
                }

                Menu {
                    Button("All Formats") {
                        formatFilter = nil
                    }
                    ForEach(ContentFormat.allCases, id: \.self) { format in
                        Button(format.displayName) {
                            formatFilter = format
                        }
                    }
                } label: {
                    Label(formatFilter?.displayName ?? "All Formats", systemImage: "photo.on.rectangle")
                        .font(.caption)
                }

                Spacer()

                Button(action: onClear) {
                    Text("Clear")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - History Stats Bar

struct HistoryStatsBar: View {
    let records: [EditRecord]

    var body: some View {
        HStack(spacing: 16) {
            StatPill(
                count: records.filter { $0.decision == .approved }.count,
                label: "Approved",
                color: .green,
                icon: "checkmark.circle.fill"
            )
            StatPill(
                count: records.filter { $0.decision == .rejected }.count,
                label: "Rejected",
                color: .red,
                icon: "xmark.circle.fill"
            )
            StatPill(
                count: records.filter { $0.decision == .saved }.count,
                label: "Saved",
                color: .blue,
                icon: "bookmark.circle.fill"
            )
        }
    }
}

struct StatPill: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.subheadline.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - History Row

struct HistoryRow: View {
    let record: EditRecord

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            if let thumbnailData = record.thumbnailData,
               let uiImage = UIImage(data: thumbnailData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: record.format.iconName)
                            .foregroundStyle(.secondary)
                    )
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(record.templateName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(record.styleName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(record.nicheName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(record.createdAt.formatted(.dateTime))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    DecisionBadge(decision: record.decision)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Decision Badge

struct DecisionBadge: View {
    let decision: EditDecision

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: decision.iconName)
                .font(.caption2)
            Text(decision.rawValue)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(decision.color.opacity(0.15))
        .foregroundStyle(decision.color)
        .clipShape(Capsule())
    }
}

// MARK: - Record Detail View

struct RecordDetailView: View {
    let record: EditRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Preview image
                    if let thumbnailData = record.thumbnailData,
                       let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding()
                    }

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Template", value: record.templateName)
                        DetailRow(label: "Style", value: record.styleName)
                        DetailRow(label: "Niche", value: record.nicheName)
                        DetailRow(label: "Format", value: record.format.displayName)
                        DetailRow(label: "Decision", value: record.decision.rawValue)
                        DetailRow(label: "Date", value: record.createdAt.formatted())
                        DetailRow(label: "Render Time", value: String(format: "%.1fs", record.renderTime))
                        if !record.operationsApplied.isEmpty {
                            DetailRow(label: "Operations", value: record.operationsApplied.joined(separator: ", "))
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - SwiftData Model

@Model
public final class EditRecord: Sendable {
    @Attribute(.unique) public var id: UUID
    public var templateName: String
    public var styleName: String
    public var nicheName: String
    public var format: ContentFormat
    public var decision: EditDecision
    public var createdAt: Date
    public var thumbnailData: Data?
    public var renderTime: TimeInterval
    public var operationsApplied: [String]
    public var sourceMediaIDs: [String]
    public var outputURL: String?

    public init(
        id: UUID = UUID(),
        templateName: String,
        styleName: String,
        nicheName: String,
        format: ContentFormat,
        decision: EditDecision,
        createdAt: Date = Date(),
        thumbnailData: Data? = nil,
        renderTime: TimeInterval = 0,
        operationsApplied: [String] = [],
        sourceMediaIDs: [String] = [],
        outputURL: String? = nil
    ) {
        self.id = id
        self.templateName = templateName
        self.styleName = styleName
        self.nicheName = nicheName
        self.format = format
        self.decision = decision
        self.createdAt = createdAt
        self.thumbnailData = thumbnailData
        self.renderTime = renderTime
        self.operationsApplied = operationsApplied
        self.sourceMediaIDs = sourceMediaIDs
        self.outputURL = outputURL
    }
}

// MARK: - Edit Decision

public enum EditDecision: String, Codable, Sendable, CaseIterable {
    case approved = "Approved"
    case rejected = "Rejected"
    case saved = "Saved"

    var color: Color {
        switch self {
        case .approved: return .green
        case .rejected: return .red
        case .saved: return .blue
        }
    }

    var iconName: String {
        switch self {
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        case .saved: return "bookmark.circle.fill"
        }
    }
}

// MARK: - ContentFormat Display Extension

extension ContentFormat {
    var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .carousel: return "Carousel"
        case .story: return "Story"
        case .newFormat: return "New Format"
        }
    }
}

// MARK: - Preview

#Preview {
    EditHistoryView()
}

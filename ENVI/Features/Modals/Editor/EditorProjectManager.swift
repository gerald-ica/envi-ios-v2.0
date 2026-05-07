import Foundation

final class EditorProjectManager: ObservableObject {
    nonisolated(unsafe) static let shared = EditorProjectManager()

    @Published var projects: [EditorProject] = []
    @Published var currentProject: EditorProject?

    private let storageKey = "com.envi.editorProjects"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        loadProjects()
    }

    // MARK: - Create

    /// Creates a new project with default tracks and returns it.
    @discardableResult
    func createProject(name: String = "Untitled", aspectRatio: AspectRatio = .portrait9x16) -> EditorProject {
        let project = EditorProject(
            name: name,
            tracks: EditorTrack.defaultTracks,
            duration: 30,
            aspectRatio: aspectRatio
        )
        projects.insert(project, at: 0)
        currentProject = project
        saveProjects()
        return project
    }

    // MARK: - Save / Auto-save

    /// Saves the current project state to persistent storage.
    func saveCurrentProject() {
        guard var project = currentProject else { return }
        project.lastEditedAt = Date()

        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.insert(project, at: 0)
        }

        currentProject = project
        saveProjects()
    }

    /// Updates the current project in memory (call `saveCurrentProject` to persist).
    func updateCurrentProject(_ updater: (inout EditorProject) -> Void) {
        guard var project = currentProject else { return }
        updater(&project)
        currentProject = project
    }

    /// Auto-save hook: call periodically or on significant edits.
    func autoSave() {
        saveCurrentProject()
    }

    // MARK: - Load

    /// Loads a project by ID and sets it as current.
    func openProject(_ id: UUID) {
        guard let project = projects.first(where: { $0.id == id }) else { return }
        currentProject = project
    }

    /// Returns the most recent projects, sorted by last edited date.
    var recentProjects: [EditorProject] {
        projects.sorted { $0.lastEditedAt > $1.lastEditedAt }
    }

    // MARK: - Delete

    /// Removes a project by ID.
    func deleteProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        if currentProject?.id == id {
            currentProject = nil
        }
        saveProjects()
    }

    /// Removes all projects.
    func deleteAllProjects() {
        projects.removeAll()
        currentProject = nil
        saveProjects()
    }

    // MARK: - Duplicate

    /// Duplicates a project with a new ID and name suffix.
    @discardableResult
    func duplicateProject(_ id: UUID) -> EditorProject? {
        guard let original = projects.first(where: { $0.id == id }) else { return nil }

        var copy = EditorProject(
            name: original.name + " Copy",
            tracks: original.tracks,
            duration: original.duration,
            aspectRatio: original.aspectRatio
        )
        copy.lastEditedAt = Date()
        projects.insert(copy, at: 0)
        saveProjects()
        return copy
    }

    // MARK: - Rename

    func renameProject(_ id: UUID, to newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[index].name = newName
        projects[index].lastEditedAt = Date()
        if currentProject?.id == id {
            currentProject?.name = newName
        }
        saveProjects()
    }

    // MARK: - Track Operations

    /// Adds a clip to a specific track type in the current project.
    func addClip(to trackType: EditorTrack.TrackType, clip: EditorClip) {
        updateCurrentProject { project in
            if let index = project.tracks.firstIndex(where: { $0.type == trackType }) {
                project.tracks[index].clips.append(clip)
            }
        }
        autoSave()
    }

    /// Removes a clip by ID from the current project.
    func removeClip(_ clipID: UUID) {
        updateCurrentProject { project in
            for i in project.tracks.indices {
                project.tracks[i].clips.removeAll { $0.id == clipID }
            }
        }
        autoSave()
    }

    /// Adds an effect to a specific clip in the current project.
    func addEffect(to clipID: UUID, effect: ClipEffect) {
        updateCurrentProject { project in
            for trackIndex in project.tracks.indices {
                if let clipIndex = project.tracks[trackIndex].clips.firstIndex(where: { $0.id == clipID }) {
                    project.tracks[trackIndex].clips[clipIndex].effects.append(effect)
                }
            }
        }
        autoSave()
    }

    // MARK: - Persistence (UserDefaults)

    private func saveProjects() {
        do {
            let data = try encoder.encode(projects)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[EditorProjectManager] Failed to save projects: \(error)")
        }
    }

    private func loadProjects() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            projects = try decoder.decode([EditorProject].self, from: data)
        } catch {
            print("[EditorProjectManager] Failed to load projects: \(error)")
        }
    }

    // MARK: - File-Based Persistence (alternative)

    private var projectsDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("EditorProjects", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Exports a project to a JSON file in Documents/EditorProjects/.
    func exportProjectToFile(_ id: UUID) -> URL? {
        guard let project = projects.first(where: { $0.id == id }) else { return nil }
        let fileURL = projectsDirectoryURL.appendingPathComponent("\(project.name)-\(project.id.uuidString.prefix(8)).json")
        do {
            let data = try encoder.encode(project)
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("[EditorProjectManager] Failed to export project: \(error)")
            return nil
        }
    }

    /// Imports a project from a JSON file.
    func importProjectFromFile(_ fileURL: URL) -> EditorProject? {
        do {
            let data = try Data(contentsOf: fileURL)
            let project = try decoder.decode(EditorProject.self, from: data)
            if !projects.contains(where: { $0.id == project.id }) {
                projects.insert(project, at: 0)
                saveProjects()
            }
            return project
        } catch {
            print("[EditorProjectManager] Failed to import project: \(error)")
            return nil
        }
    }
}

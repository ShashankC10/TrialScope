import Foundation
import SwiftData

/// Snapshot storage keeps trial details available offline. Defaults and no unique
/// constraints allow this schema to be used with SwiftData's optional CloudKit sync.
@Model public final class SavedTrial {
    public var trialID: String = ""
    public var snapshot: Data = Data()
    public var savedAt: Date = Date()
    public var notes: String = ""

    public init(trial: Trial) throws {
        trialID = trial.id
        snapshot = try JSONEncoder().encode(trial)
        savedAt = Date()
    }
    public var trial: Trial? { try? JSONDecoder().decode(Trial.self, from: snapshot) }
}

@MainActor public enum TrialStore {
    public static func container(inMemory: Bool = false, cloudContainerID: String? = nil) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudContainerID.map { .private($0) } ?? .none
        )
        return try ModelContainer(for: SavedTrial.self, configurations: configuration)
    }

    public static func save(_ trial: Trial, in context: ModelContext) throws {
        let id = trial.id
        let descriptor = FetchDescriptor<SavedTrial>(predicate: #Predicate { $0.trialID == id })
        guard try context.fetch(descriptor).isEmpty else { return }
        context.insert(try SavedTrial(trial: trial))
        do { try context.save() } catch { context.rollback(); throw error }
    }

    public static func remove(id: String, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<SavedTrial>(predicate: #Predicate { $0.trialID == id })
        for saved in try context.fetch(descriptor) { context.delete(saved) }
        do { try context.save() } catch { context.rollback(); throw error }
    }

    public static func updateNotes(_ notes: String, for saved: SavedTrial, in context: ModelContext) throws {
        saved.notes = notes
        do { try context.save() } catch { context.rollback(); throw error }
    }
}

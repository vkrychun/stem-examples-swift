//
//  FirebaseRepository.swift
//
//  Created by Vasyl Krychun on 17.09.2025.
//

import Foundation
import FirebaseCore
@preconcurrency import FirebaseFirestore
import StemRuntimeSDK

// MARK: - Firebase Entity (conforms to SDK's public StemRepoEntity)

private enum FirebaseKey: String {
    case collection, documentId, body, rewrite
}

public struct FirebaseEntity: StemRepoEntity {

    public struct Create: StemRepoWritableContext {
        public typealias Response = AnyDecodable
        public let collection: String?
        public let documentId: String?
        public let body: AnyDecodable
        public let rewrite: Bool

        public init(_ input: Any?) {
            let dict = input as? [String: Any]
            self.collection = dict?[FirebaseKey.collection.rawValue] as? String
            self.documentId = dict?[FirebaseKey.documentId.rawValue] as? String
            self.rewrite = dict?[FirebaseKey.rewrite.rawValue] as? Bool ?? false
            self.body = AnyDecodable(dict?[FirebaseKey.body.rawValue] ?? NSNull())
        }
    }

    public struct Read: StemRepoReadableContext {
        public typealias Response = AnyDecodable
        public let collection: String?
        public let documentId: String?

        public init(_ input: Any?) {
            let dict = input as? [String: Any]
            self.collection = dict?[FirebaseKey.collection.rawValue] as? String
            self.documentId = dict?[FirebaseKey.documentId.rawValue] as? String
        }
    }

    public struct Update: StemRepoWritableContext {
        public typealias Response = AnyDecodable
        public let collection: String?
        public let documentId: String?
        public let body: AnyDecodable
        public let rewrite: Bool

        public init(_ input: Any?) {
            let dict = input as? [String: Any]
            self.collection = dict?[FirebaseKey.collection.rawValue] as? String
            self.documentId = dict?[FirebaseKey.documentId.rawValue] as? String
            self.rewrite = dict?[FirebaseKey.rewrite.rawValue] as? Bool ?? false
            self.body = AnyDecodable(dict?[FirebaseKey.body.rawValue] ?? NSNull())
        }
    }

    public struct Delete: StemRepoReadableContext {
        public typealias Response = AnyDecodable
        public let collection: String?
        public let documentId: String?

        public init(_ input: Any?) {
            let dict = input as? [String: Any]
            self.collection = dict?[FirebaseKey.collection.rawValue] as? String
            self.documentId = dict?[FirebaseKey.documentId.rawValue] as? String
        }
    }
}

// MARK: - Firestore-backed Repo

public final class FirebaseRepository: StemRepository {
    public typealias Entity = FirebaseEntity
    public let id: String
    public var dependencyType: any StemDependencyType { AppRepositoryType.firebase }

    public struct Configuration: Decodable, Sendable {
        /// Base collection path, e.g. "apps/messenger_demo"
        var collectionPath: String
        /// Optional: Firestore emulator
        var emulatorHost: String? = nil
        var emulatorPort: Int? = nil
        /// Optional: custom Firebase app name if you use multiple apps
        var appName: String? = nil
        /// Optional: Firestore settings
        var isPersistenceEnabled: Bool? = nil
        /// Optional: Firebase API key for programmatic configuration (no plist needed)
        var apiKey: String? = nil
        /// Optional: Firebase project ID for programmatic configuration
        var projectId: String? = nil
        /// Optional: Google App ID for programmatic configuration
        var googleAppId: String? = nil
    }

    private let config: Configuration
    private nonisolated(unsafe) var _db: Firestore?

    /// Shared configuration set by the host app for programmatic Firebase setup.
    nonisolated(unsafe) static var sharedConfig: (apiKey: String, projectId: String, googleAppId: String)?

    /// Lazily resolves Firestore, configuring Firebase on first access if needed.
    private var db: Firestore {
        get throws {
            if let _db { return _db }

            // Configure Firebase if no app exists yet
            if FirebaseApp.app(name: config.appName ?? FirebaseApp.app()?.name ?? "__default__") == nil,
               FirebaseApp.app() == nil {
                if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
                    FirebaseApp.configure()
                } else if let apiKey = config.apiKey, let projectId = config.projectId, let googleAppId = config.googleAppId {
                    let options = FirebaseOptions(googleAppID: googleAppId, gcmSenderID: "000000000000")
                    options.apiKey = apiKey
                    options.projectID = projectId
                    FirebaseApp.configure(options: options)
                } else if let shared = Self.sharedConfig {
                    let options = FirebaseOptions(googleAppID: shared.googleAppId, gcmSenderID: "000000000000")
                    options.apiKey = shared.apiKey
                    options.projectID = shared.projectId
                    FirebaseApp.configure(options: options)
                }
            }

            guard let app = config.appName.flatMap({ FirebaseApp.app(name: $0) }) ?? FirebaseApp.app() else {
                throw StemActionError(.unknown, "Firebase is not configured. Add GoogleService-Info.plist or enter credentials in Settings.")
            }

            let db = Firestore.firestore(app: app)
            let settings = db.settings
            if let enabled = config.isPersistenceEnabled {
                settings.isPersistenceEnabled = enabled
            }
            db.settings = settings
            if let host = config.emulatorHost, let port = config.emulatorPort {
                db.useEmulator(withHost: host, port: port)
            }
            return db
        }
    }

    // MARK: Init / Decode

    public init(id: String, config: Configuration) throws {
        self.id = id
        self.config = config

        // Validate base path
        guard !config.collectionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw StemActionError(.invalidURL, "collectionPath must not be empty.")
        }

        // Eagerly configure Firebase from plist if available
        if FirebaseApp.app() == nil,
           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
    }

    // MARK: Path helpers

    private var baseCollection: CollectionReference {
        get throws { try db.collection(config.collectionPath) }
    }

    /// Treat `input.collection` as a sub-path under the base path: `basePath/<name>`
    private func collectionRef(_ name: String?) throws -> CollectionReference {
        if let n = name, !n.isEmpty {
            let path = config.collectionPath.hasSuffix("/") ? "\(config.collectionPath)\(n)" : "\(config.collectionPath)/\(n)"
            return try db.collection(path)
        } else {
            return try baseCollection
        }
    }

    // MARK: Error wrapping

    /// Firestore APIs throw `Error`; `StemRepository` requires `StemActionError`.
    /// - If `error` is already `StemActionError`, pass it through.
    /// - Otherwise, wrap as `.unknown` and preserve `underlyingError`.
    private func wrap(_ error: Error) -> StemActionError {
        if let e = error as? StemActionError { return e }
        return StemActionError(.unknown, underlying: error)
    }

    /// Convenience to keep all CRUD methods readable and consistent.
    private func call<T>(_ work: () async throws -> T) async throws(StemActionError) -> T {
        do { return try await work() }
        catch { throw wrap(error) }
    }

    // MARK: CRUD (async/await, typed)

    /// **CREATE**: returns array of created IDs (single insert -> one element).
    ///
    /// Behavior when `documentId` is provided:
    /// - If a document exists and `rewrite == true`: it overwrites.
    /// - If a document exists and `rewrite == false`: throws `StemActionError(.documentExists)`.
    public func create(_ input: Entity.Create) async throws(StemActionError) -> Entity.Create.Response {
        try await call {
            let col = try collectionRef(input.collection)

            if var json = input.body.value as? [String: Any] {
                StemRepositoryHelper.stampForCreate(&json)

                if let docId = input.documentId {
                    let docRef = col.document(docId)

                    if !input.rewrite {
                        let snap = try await docRef.getDocument()
                        if snap.exists {
                            throw StemActionError(.documentExists, "Document already exists: \(docId)")
                        }
                    }

                    try await docRef.setData(json) // full replace
                    return .init([docId])
                } else {
                    let ref = try await col.addDocument(data: json)
                    return .init([ref.documentID])
                }

            } else if let docs = input.body.value as? [[String: Any]] {
                // Firestore batch commit limit: 500 ops
                var ids: [String] = []
                ids.reserveCapacity(docs.count)

                let pageSize = 500
                var idx = 0
                while idx < docs.count {
                    let end = min(idx + pageSize, docs.count)
                    let slice = docs[idx..<end]

                    let batch = try db.batch()
                    var refs: [DocumentReference] = []
                    refs.reserveCapacity(slice.count)

                    for var json in slice {
                        StemRepositoryHelper.stampForCreate(&json)
                        let ref = col.document() // auto-id
                        batch.setData(json, forDocument: ref)
                        refs.append(ref)
                    }

                    try await batch.commit()
                    ids.append(contentsOf: refs.map { $0.documentID })
                    idx = end
                }

                return .init(ids)

            } else {
                var json: [String: Any] = ["value": input.body.value]
                StemRepositoryHelper.stampForCreate(&json)
                let ref = try await col.addDocument(data: json)
                return .init([ref.documentID])
            }
        }
    }

    /// **READ**: returns JSON object (single doc) or array of objects (whole collection).
    ///
    /// Errors:
    /// - Throws `StemActionError(.documentNotFound)` if a specific document ID does not exist.
    public func read(_ input: Entity.Read) async throws(StemActionError) -> Entity.Read.Response {
        try await call {
            let col = try collectionRef(input.collection)

            // Single doc
            if let docId = input.documentId {
                let snap = try await col.document(docId).getDocument()
                guard var data = snap.data() else {
                    throw StemActionError(.documentNotFound, "Document not found: \(docId)")
                }
                data[Self.kDocumentId] = docId
                return .init(data)
            }

            // Whole collection
            let snapshot = try await col.getDocuments()
            var items: [[String: Any]] = []
            items.reserveCapacity(snapshot.documents.count)
            for doc in snapshot.documents {
                var d = doc.data()
                d[Self.kDocumentId] = doc.documentID
                items.append(d)
            }
            return .init(items)
        }
    }

    /// **UPDATE**: only supports object body (`[String: Any]`); returns success flag.
    ///
    /// Errors:
    /// - Throws `StemActionError(.noDocumentId)` if `documentId` is missing.
    /// - Throws `StemActionError(.documentNotFound)` if the document does not exist.
    /// - Throws `StemActionError(.invalidBody)` if body is not an object.
    public func update(_ input: Entity.Update) async throws(StemActionError) -> Entity.Update.Response {
        try await call {
            let col = try collectionRef(input.collection)

            guard let docId = input.documentId else {
                throw StemActionError(.noDocumentId, "Update requires 'documentId'.")
            }

            let ref = col.document(docId)
            let snap = try await ref.getDocument()
            guard snap.exists else {
                throw StemActionError(.documentNotFound, "Document not found: \(docId)")
            }

            guard var json = input.body.value as? [String: Any] else {
                throw StemActionError(.invalidBody, "Update requires an object body: [String: Any].")
            }

            if input.rewrite {
                // Preserve created_at if present
                if json["created_at"] == nil, let old = snap.data()?["created_at"] {
                    json["created_at"] = old
                }
                StemRepositoryHelper.stampForUpdate(&json)
                try await ref.setData(json) // full replace
            } else {
                // Shallow merge
                StemRepositoryHelper.stampForUpdate(&json)
                try await ref.setData(json, merge: true)
            }

            return .init(true)
        }
    }

    /// **DELETE**: returns success flag.
    ///
    /// Errors:
    /// - Throws `StemActionError(.documentNotFound)` when deleting a specific missing document.
    public func delete(_ input: Entity.Delete) async throws(StemActionError) -> Entity.Delete.Response {
        try await call {
            let col = try collectionRef(input.collection)

            // Delete a single document
            if let docId = input.documentId {
                let ref = col.document(docId)
                let snap = try await ref.getDocument()
                guard snap.exists else {
                    throw StemActionError(.documentNotFound, "Document not found: \(docId)")
                }
                try await ref.delete()
                return .init(true)
            }

            // Delete the whole collection (page and batch; Firestore limit = 500)
            var lastSnapshot: QuerySnapshot?
            let pageSize = 500

            repeat {
                var query: Query = col.limit(to: pageSize)
                if let last = lastSnapshot?.documents.last {
                    query = query.start(afterDocument: last)
                }
                let snap = try await query.getDocuments()
                lastSnapshot = snap
                if snap.documents.isEmpty { break }

                let batch = try db.batch()
                for doc in snap.documents { batch.deleteDocument(doc.reference) }
                try await batch.commit()
            } while lastSnapshot?.documents.isEmpty == false

            return .init(true)
        }
    }
}

// MARK: - Listen

enum FirebaseListenError: Error {
    case invalidParameters(String)
}

extension FirebaseRepository: StemListenable {

    /// Emits snapshots as an array of documents (each document includes `kDocumentId`).
    /// Note: `StemListenable` stream throws `Error` (not `StemActionError`), so we throw plain errors here.
    public func listen(_ params: AnyDecodable) -> AsyncThrowingStream<AnyDecodable, Error> {
        // Resolve db before the closure to avoid throwing inside non-throwing context
        let resolvedDb: Firestore
        do { resolvedDb = try db } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }

        return AsyncThrowingStream { continuation in
            guard let dict = params.value as? [String: Any] else {
                continuation.finish(throwing: FirebaseListenError.invalidParameters("Expected parameters to be a dictionary."))
                return
            }

            guard let path = dict["collection"] as? String else {
                continuation.finish(throwing: FirebaseListenError.invalidParameters("Missing or invalid 'collection' path string."))
                return
            }

            let basePath = self.config.collectionPath
            let fullPath = basePath.hasSuffix("/") ? "\(basePath)\(path)" : "\(basePath)/\(path)"
            let query: Query = resolvedDb.collection(fullPath).order(by: "created_at", descending: false)
            let manager = ListenerManager()

            Task {
                let listener = query.addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    guard let snapshot else { return }

                    let items = snapshot.documents.map { doc in
                        var d = doc.data()
                        d[Self.kDocumentId] = doc.documentID
                        return d
                    }

                    continuation.yield(.init(items))
                }

                await manager.setListener(listener)

                continuation.onTermination = { @Sendable _ in
                    Task { await manager.removeListener() }
                }
            }
        }
    }
}

// MARK: - Decodable

extension FirebaseRepository: Decodable {
    private enum CodingKeys: String, CodingKey { case id, config }

    public convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id  = try c.decode(String.self, forKey: .id)
        let cfg = try c.decode(Configuration.self, forKey: .config)
        try self.init(id: id, config: cfg)
    }
}

// MARK: - Listener Manager

actor ListenerManager {
    private var listener: ListenerRegistration?

    fileprivate func setListener(_ listener: ListenerRegistration) {
        self.listener = listener
    }

    func removeListener() {
        listener?.remove()
        listener = nil
    }
}

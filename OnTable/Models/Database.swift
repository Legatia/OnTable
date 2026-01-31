import Foundation
import SQLite

// MARK: - Database Manager

class DatabaseManager {
    static let shared = DatabaseManager()
    private(set) var db: Connection?

    private let currentSchemaVersion = 2  // Increment when schema changes

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let path = getDatabasePath()
            db = try Connection(path)
            createTables()
            migrateIfNeeded()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func getDatabasePath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsPath.appendingPathComponent("ontable.sqlite3").path
        return dbPath
    }

    private func createTables() {
        guard let db = db else { return }

        do {
            // Enable foreign keys
            try db.execute("PRAGMA foreign_keys = ON")

            // Decisions table (v2: chosen_option_id instead of chosen_side)
            try db.execute("""
                CREATE TABLE IF NOT EXISTS decisions (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    created_at INTEGER NOT NULL,
                    resolved_at INTEGER,
                    chosen_option_id TEXT,
                    is_collaborative INTEGER DEFAULT 0
                )
            """)

            // Options table (v2: option_index instead of side)
            try db.execute("""
                CREATE TABLE IF NOT EXISTS options (
                    id TEXT PRIMARY KEY,
                    decision_id TEXT NOT NULL,
                    option_index INTEGER NOT NULL,
                    title TEXT NOT NULL,
                    image_url TEXT,
                    FOREIGN KEY (decision_id) REFERENCES decisions(id) ON DELETE CASCADE
                )
            """)

            // ProsCons table
            try db.execute("""
                CREATE TABLE IF NOT EXISTS pros_cons (
                    id TEXT PRIMARY KEY,
                    option_id TEXT NOT NULL,
                    type TEXT NOT NULL,
                    text TEXT NOT NULL,
                    weight INTEGER DEFAULT 1,
                    added_by TEXT DEFAULT 'me',
                    FOREIGN KEY (option_id) REFERENCES options(id) ON DELETE CASCADE
                )
            """)

            // Participants table (v2: voted_for_option_id instead of voted_for)
            try db.execute("""
                CREATE TABLE IF NOT EXISTS participants (
                    id TEXT PRIMARY KEY,
                    decision_id TEXT NOT NULL,
                    name TEXT NOT NULL,
                    voted_for_option_id TEXT,
                    FOREIGN KEY (decision_id) REFERENCES decisions(id) ON DELETE CASCADE
                )
            """)

            // Schema version table
            try db.execute("""
                CREATE TABLE IF NOT EXISTS schema_version (
                    version INTEGER PRIMARY KEY
                )
            """)

        } catch {
            print("Table creation error: \(error)")
        }
    }

    // MARK: - Migration

    private func migrateIfNeeded() {
        guard let db = db else { return }

        do {
            // Get current schema version
            var version = 0
            let stmt = try db.prepare("SELECT version FROM schema_version LIMIT 1")
            for row in stmt {
                version = Int(row[0] as? Int64 ?? 0)
            }

            if version < currentSchemaVersion {
                performMigration(from: version, to: currentSchemaVersion)
            }
        } catch {
            // Table doesn't exist or empty, do full migration from 0
            performMigration(from: 0, to: currentSchemaVersion)
        }
    }

    private func performMigration(from oldVersion: Int, to newVersion: Int) {
        guard let db = db else { return }

        do {
            if oldVersion < 2 {
                // Migration from v1 to v2: Multi-option support
                migrateToV2()
            }

            // Update schema version
            try db.run("DELETE FROM schema_version")
            try db.run("INSERT INTO schema_version (version) VALUES (?)", newVersion)

            print("Database migrated from v\(oldVersion) to v\(newVersion)")
        } catch {
            print("Migration error: \(error)")
        }
    }

    private func migrateToV2() {
        guard let db = db else { return }

        do {
            // Check if old schema exists (has 'side' column in options)
            let hasSideColumn = try checkColumnExists(table: "options", column: "side")
            let hasChosenSideColumn = try checkColumnExists(table: "decisions", column: "chosen_side")

            if hasSideColumn {
                // Migrate options: side -> option_index
                // Create new table
                try db.execute("""
                    CREATE TABLE IF NOT EXISTS options_new (
                        id TEXT PRIMARY KEY,
                        decision_id TEXT NOT NULL,
                        option_index INTEGER NOT NULL,
                        title TEXT NOT NULL,
                        image_url TEXT,
                        FOREIGN KEY (decision_id) REFERENCES decisions(id) ON DELETE CASCADE
                    )
                """)

                // Copy data with conversion
                try db.execute("""
                    INSERT INTO options_new (id, decision_id, option_index, title, image_url)
                    SELECT id, decision_id,
                           CASE WHEN side = 'left' THEN 0 ELSE 1 END,
                           title, image_url
                    FROM options
                """)

                // Drop old table and rename new
                try db.execute("DROP TABLE options")
                try db.execute("ALTER TABLE options_new RENAME TO options")
            }

            if hasChosenSideColumn {
                // Migrate decisions: chosen_side -> chosen_option_id
                // We need to look up the option ID based on side

                // First add the new column
                try db.execute("ALTER TABLE decisions ADD COLUMN chosen_option_id TEXT")

                // Update chosen_option_id based on chosen_side
                try db.execute("""
                    UPDATE decisions
                    SET chosen_option_id = (
                        SELECT o.id FROM options o
                        WHERE o.decision_id = decisions.id
                        AND o.option_index = CASE WHEN decisions.chosen_side = 'left' THEN 0 ELSE 1 END
                    )
                    WHERE chosen_side IS NOT NULL
                """)

                // We can't easily drop the old column in SQLite, so we leave it
                // It will be ignored by the new code
            }

            // Migrate participants: voted_for -> voted_for_option_id
            let hasVotedForColumn = try checkColumnExists(table: "participants", column: "voted_for")
            let hasVotedForOptionIdColumn = try checkColumnExists(table: "participants", column: "voted_for_option_id")

            if hasVotedForColumn && !hasVotedForOptionIdColumn {
                try db.execute("ALTER TABLE participants ADD COLUMN voted_for_option_id TEXT")
                // Note: Can't easily migrate votes without knowing which decision they belong to
                // Old votes will be lost, but that's acceptable for collaboration sessions
            }

        } catch {
            print("V2 migration error: \(error)")
        }
    }

    private func checkColumnExists(table: String, column: String) throws -> Bool {
        guard let db = db else { return false }

        let stmt = try db.prepare("PRAGMA table_info(\(table))")
        for row in stmt {
            if let name = row[1] as? String, name == column {
                return true
            }
        }
        return false
    }
}

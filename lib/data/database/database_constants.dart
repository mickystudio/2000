class DatabaseConstants {
  static const String databaseFileName = 'secure_offline_vault.db';
  static const int databaseVersion = 1;

  static const String tableUsers = 'users';
  static const String tableDailyCheckins = 'daily_checkins';
  static const String tableEvents = 'events';
  static const String tableBrainHealthCounter = 'brain_health_counter';
  static const String tableDecayLog = 'decay_log';
  static const String tableSpiritualContent = 'spiritual_content';
  static const String tableSpiritualLog = 'spiritual_log';
  static const String tableSosSessions = 'sos_sessions';

  static const List<String> allTables = <String>[
    tableUsers,
    tableDailyCheckins,
    tableEvents,
    tableBrainHealthCounter,
    tableDecayLog,
    tableSpiritualContent,
    tableSpiritualLog,
    tableSosSessions,
  ];

  static const String createTableUsers = '''
    CREATE TABLE IF NOT EXISTS $tableUsers (
      id TEXT PRIMARY KEY NOT NULL,
      username TEXT NOT NULL,
      email TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      metadata TEXT
    );
  ''';

  static const String createTableDailyCheckins = '''
    CREATE TABLE IF NOT EXISTS $tableDailyCheckins (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      checkin_date TEXT NOT NULL,
      mood_score REAL NOT NULL,
      resilience_rating REAL NOT NULL,
      notes TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES $tableUsers(id) ON DELETE CASCADE
    );
  ''';

  static const String createTableEvents = '''
    CREATE TABLE IF NOT EXISTS $tableEvents (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      severity TEXT NOT NULL,
      payload TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES $tableUsers(id) ON DELETE CASCADE
    );
  ''';

  static const String createTableBrainHealthCounter = '''
    CREATE TABLE IF NOT EXISTS $tableBrainHealthCounter (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      current_score REAL NOT NULL,
      peak_score REAL NOT NULL,
      last_decay_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES $tableUsers(id) ON DELETE CASCADE
    );
  ''';

  static const String createTableDecayLog = '''
    CREATE TABLE IF NOT EXISTS $tableDecayLog (
      id TEXT PRIMARY KEY NOT NULL,
      counter_id TEXT NOT NULL,
      user_id TEXT NOT NULL,
      event_id TEXT,
      previous_score REAL NOT NULL,
      new_score REAL NOT NULL,
      delta REAL NOT NULL,
      cause TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      metadata TEXT,
      FOREIGN KEY (counter_id) REFERENCES $tableBrainHealthCounter(id) ON DELETE CASCADE,
      FOREIGN KEY (user_id) REFERENCES $tableUsers(id) ON DELETE CASCADE,
      FOREIGN KEY (event_id) REFERENCES $tableEvents(id) ON DELETE SET NULL
    );
  ''';

  static const String createTableSpiritualContent = '''
    CREATE TABLE IF NOT EXISTS $tableSpiritualContent (
      id TEXT PRIMARY KEY NOT NULL,
      category TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      reference_tag TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );
  ''';

  static const String createTableSpiritualLog = '''
    CREATE TABLE IF NOT EXISTS $tableSpiritualLog (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      content_id TEXT,
      duration_seconds INTEGER NOT NULL,
      reflections TEXT,
      completed_at INTEGER NOT NULL,
      FOREIGN KEY (user_id) REFERENCES $tableUsers(id) ON DELETE CASCADE,
      FOREIGN KEY (content_id) REFERENCES $tableSpiritualContent(id) ON DELETE SET NULL
    );
  ''';

  static const String createTableSosSessions = '''
    CREATE TABLE IF NOT EXISTS $tableSosSessions (
      id TEXT PRIMARY KEY NOT NULL,
      user_id TEXT NOT NULL,
      trigger_reason TEXT NOT NULL,
      duration_seconds INTEGER NOT NULL,
      outcome_state TEXT NOT NULL,
      notes TEXT,
      started_at INTEGER NOT NULL,
      ended_at INTEGER,
      FOREIGN KEY (user_id) REFERENCES $tableUsers(id) ON DELETE CASCADE
    );
  ''';

  static const List<String> createIndices = <String>[
    'CREATE INDEX IF NOT EXISTS idx_users_updated ON $tableUsers(updated_at);',
    'CREATE INDEX IF NOT EXISTS idx_checkins_user_date ON $tableDailyCheckins(user_id, checkin_date);',
    'CREATE INDEX IF NOT EXISTS idx_events_user_time ON $tableEvents(user_id, timestamp);',
    'CREATE INDEX IF NOT EXISTS idx_counter_user ON $tableBrainHealthCounter(user_id);',
    'CREATE INDEX IF NOT EXISTS idx_decay_log_counter ON $tableDecayLog(counter_id);',
    'CREATE INDEX IF NOT EXISTS idx_decay_log_event ON $tableDecayLog(event_id);',
    'CREATE INDEX IF NOT EXISTS idx_decay_log_timestamp ON $tableDecayLog(timestamp DESC);',
    'CREATE INDEX IF NOT EXISTS idx_spiritual_cat ON $tableSpiritualContent(category);',
    'CREATE INDEX IF NOT EXISTS idx_spiritual_log_user ON $tableSpiritualLog(user_id, completed_at);',
    'CREATE INDEX IF NOT EXISTS idx_sos_user_time ON $tableSosSessions(user_id, started_at);',
  ];

  static const String createDecayTrigger = '''
    CREATE TRIGGER IF NOT EXISTS trg_brain_health_decay_log_audit
    AFTER UPDATE OF current_score ON $tableBrainHealthCounter
    FOR EACH ROW
    WHEN OLD.current_score != NEW.current_score
    BEGIN
      INSERT INTO $tableDecayLog (
        id,
        counter_id,
        user_id,
        event_id,
        previous_score,
        new_score,
        delta,
        cause,
        timestamp,
        metadata
      ) VALUES (
        lower(hex(randomblob(4))) || '-' || lower(hex(randomblob(2))) || '-4' || substr(lower(hex(randomblob(2))),2) || '-a' || substr(lower(hex(randomblob(2))),2) || '-' || lower(hex(randomblob(6))),
        NEW.id,
        NEW.user_id,
        NULL,
        OLD.current_score,
        NEW.current_score,
        ROUND(NEW.current_score - OLD.current_score, 4),
        'SQL_TRIGGER_MODIFICATION',
        (strftime('%s', 'now') * 1000),
        json_object('triggered_by', 'sqlite_engine', 'old_score', OLD.current_score, 'new_score', NEW.current_score)
      );
    END;
  ''';
}

import path from "path";
import crypto from "crypto";
import { DatabaseSync } from "node:sqlite";
import { DATA_DIR, ensureDirSync } from "../infra/data.js";
import { logger } from "../infra/logger.js";

const DB_DIR = path.join(DATA_DIR, "memory_db");
const DB_PATH = path.join(DB_DIR, "memory.db");

let db: DatabaseSync | null = null;

function getDb(): DatabaseSync {
  if (db) return db;

  ensureDirSync(DB_DIR);
  db = new DatabaseSync(DB_PATH);
  db.exec("PRAGMA journal_mode = WAL");
  db.exec("PRAGMA foreign_keys = ON");
  initSchema(db);
  return db;
}

function initSchema(d: DatabaseSync): void {
  d.exec(`
    CREATE TABLE IF NOT EXISTS memories (
      id         TEXT PRIMARY KEY,
      agent_id   TEXT NOT NULL,
      content    TEXT NOT NULL,
      mem_type   TEXT NOT NULL,
      importance TEXT NOT NULL,
      ts         INTEGER NOT NULL,
      embedding  BLOB NOT NULL
    );
    CREATE INDEX IF NOT EXISTS idx_memories_agent_ts   ON memories(agent_id, ts DESC);
    CREATE INDEX IF NOT EXISTS idx_memories_agent_type ON memories(agent_id, mem_type);

    CREATE TABLE IF NOT EXISTS entities (
      id          TEXT PRIMARY KEY,
      name        TEXT NOT NULL,
      entity_type TEXT NOT NULL,
      UNIQUE(name, entity_type)
    );

    CREATE TABLE IF NOT EXISTS topics (
      id   TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE
    );

    CREATE TABLE IF NOT EXISTS memory_entities (
      memory_id TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      PRIMARY KEY(memory_id, entity_id),
      FOREIGN KEY(memory_id) REFERENCES memories(id) ON DELETE CASCADE,
      FOREIGN KEY(entity_id) REFERENCES entities(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS memory_topics (
      memory_id TEXT NOT NULL,
      topic_id  TEXT NOT NULL,
      PRIMARY KEY(memory_id, topic_id),
      FOREIGN KEY(memory_id) REFERENCES memories(id) ON DELETE CASCADE,
      FOREIGN KEY(topic_id)  REFERENCES topics(id)   ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS memory_follows (
      from_id TEXT NOT NULL,
      to_id   TEXT NOT NULL,
      PRIMARY KEY(from_id, to_id),
      FOREIGN KEY(from_id) REFERENCES memories(id) ON DELETE CASCADE,
      FOREIGN KEY(to_id)   REFERENCES memories(id) ON DELETE CASCADE
    );
  `);
  logger.info(`[MemoryDB] SQLite schema ready at ${DB_PATH}`);
}

function encodeEmbedding(vec: number[]): Uint8Array {
  const f32 = new Float32Array(vec);
  return new Uint8Array(f32.buffer, f32.byteOffset, f32.byteLength);
}

function decodeEmbedding(buf: Uint8Array): Float32Array {
  const copy = new Uint8Array(buf.byteLength);
  copy.set(buf);
  return new Float32Array(copy.buffer);
}

function cosineSimilarity(a: Float32Array | number[], b: Float32Array | number[]): number {
  const len = Math.min(a.length, b.length);
  let dot = 0, normA = 0, normB = 0;
  for (let i = 0; i < len; i++) {
    const x = a[i];
    const y = b[i];
    dot += x * y;
    normA += x * x;
    normB += y * y;
  }
  const denom = Math.sqrt(normA) * Math.sqrt(normB);
  return denom === 0 ? 0 : dot / denom;
}

function upsertEntity(name: string, entityType: string): string {
  const d = getDb();
  const row = d
    .prepare("SELECT id FROM entities WHERE name = ? AND entity_type = ?")
    .get(name, entityType) as { id: string } | undefined;
  if (row) return row.id;
  const id = crypto.randomUUID();
  d.prepare("INSERT INTO entities (id, name, entity_type) VALUES (?, ?, ?)").run(id, name, entityType);
  return id;
}

function upsertTopic(name: string): string {
  const d = getDb();
  const row = d.prepare("SELECT id FROM topics WHERE name = ?").get(name) as { id: string } | undefined;
  if (row) return row.id;
  const id = crypto.randomUUID();
  d.prepare("INSERT INTO topics (id, name) VALUES (?, ?)").run(id, name);
  return id;
}

function getLastMemoryId(agentId: string): string | null {
  const d = getDb();
  const row = d
    .prepare("SELECT id FROM memories WHERE agent_id = ? ORDER BY ts DESC LIMIT 1")
    .get(agentId) as { id: string } | undefined;
  return row?.id ?? null;
}

export type MemoryType = "core" | "daily";
export type Importance = "low" | "normal" | "high";

export interface EntityInput {
  name: string;
  type?: "person" | "tool" | "concept" | "place" | "other";
}

export interface InsertMemoryOptions {
  agentId: string;
  content: string;
  memType: MemoryType;
  embedding: number[];
  topics?: string[];
  entities?: EntityInput[];
  importance?: Importance;
}

export interface MemorySearchResult {
  content: string;
  memType: string;
  importance: string;
  score: number;
  topics: string[];
  entities: Array<{ name: string; type: string }>;
}

export async function insertMemoryNode(opts: InsertMemoryOptions): Promise<void> {
  const d = getDb();
  const {
    agentId, content, memType, embedding,
    topics = [], entities = [], importance = "normal",
  } = opts;

  const id = crypto.randomUUID();
  const ts = Date.now();

  d.exec("BEGIN");
  try {
    d.prepare(
      "INSERT INTO memories (id, agent_id, content, mem_type, importance, ts, embedding) VALUES (?, ?, ?, ?, ?, ?, ?)",
    ).run(id, agentId, content, memType, importance, ts, encodeEmbedding(embedding));

    const prevId = getLastMemoryId(agentId);
    if (prevId && prevId !== id) {
      d.prepare("INSERT OR IGNORE INTO memory_follows (from_id, to_id) VALUES (?, ?)").run(prevId, id);
    }

    for (const ent of entities) {
      const entId = upsertEntity(ent.name, ent.type ?? "concept");
      d.prepare("INSERT OR IGNORE INTO memory_entities (memory_id, entity_id) VALUES (?, ?)").run(id, entId);
    }

    for (const topicName of topics) {
      const topicId = upsertTopic(topicName);
      d.prepare("INSERT OR IGNORE INTO memory_topics (memory_id, topic_id) VALUES (?, ?)").run(id, topicId);
    }

    d.exec("COMMIT");
  } catch (err) {
    d.exec("ROLLBACK");
    throw err;
  }
}

export async function searchMemoryNodes(
  agentId: string,
  queryEmbedding: number[],
  topK: number = 5,
): Promise<MemorySearchResult[]> {
  const d = getDb();
  const rows = d
    .prepare(
      "SELECT id, content, mem_type AS memType, importance, embedding FROM memories WHERE agent_id = ?",
    )
    .all(agentId) as Array<{
      id: string;
      content: string;
      memType: string;
      importance: string;
      embedding: Uint8Array;
    }>;

  if (rows.length === 0) return [];

  const topicStmt = d.prepare(
    `SELECT t.name FROM topics t
     JOIN memory_topics mt ON mt.topic_id = t.id
     WHERE mt.memory_id = ?`,
  );
  const entityStmt = d.prepare(
    `SELECT e.name AS name, e.entity_type AS type FROM entities e
     JOIN memory_entities me ON me.entity_id = e.id
     WHERE me.memory_id = ?`,
  );

  const importanceWeight: Record<string, number> = { high: 1.2, normal: 1.0, low: 0.8 };
  const queryVec = Float32Array.from(queryEmbedding);

  const scored = rows.map((row) => {
    const emb = decodeEmbedding(row.embedding);
    const baseSim = cosineSimilarity(queryVec, emb);
    const weight = importanceWeight[row.importance] ?? 1.0;
    return { row, score: baseSim * weight };
  });

  scored.sort((a, b) => b.score - a.score);
  const top = scored.slice(0, topK);

  return top.map(({ row, score }) => {
    const topics = (topicStmt.all(row.id) as Array<{ name: string }>).map((r) => r.name);
    const entities = (entityStmt.all(row.id) as Array<{ name: string; type: string }>).filter((e) => e.name);
    return {
      content: row.content,
      memType: row.memType,
      importance: row.importance,
      score,
      topics,
      entities,
    };
  });
}

export async function deleteCoreMemoryNodes(agentId: string): Promise<void> {
  const d = getDb();
  d.prepare("DELETE FROM memories WHERE agent_id = ? AND mem_type = 'core'").run(agentId);
}

export async function deleteAllMemoryNodes(agentId: string): Promise<void> {
  const d = getDb();
  d.prepare("DELETE FROM memories WHERE agent_id = ?").run(agentId);
}

export interface MemoryStats {
  coreCount: number;
  dailyCount: number;
  entityCount: number;
  topicCount: number;
  mentionsCount: number;
  aboutCount: number;
  followsCount: number;
}

export async function getMemoryStats(agentId: string): Promise<MemoryStats> {
  const d = getDb();

  const one = (sql: string): number => {
    const row = d.prepare(sql).get(agentId) as { n: number | bigint } | undefined;
    if (!row) return 0;
    const n = row.n;
    return typeof n === "bigint" ? Number(n) : n;
  };

  return {
    coreCount: one(
      "SELECT COUNT(*) AS n FROM memories WHERE agent_id = ? AND mem_type = 'core'",
    ),
    dailyCount: one(
      "SELECT COUNT(*) AS n FROM memories WHERE agent_id = ? AND mem_type = 'daily'",
    ),
    entityCount: one(
      `SELECT COUNT(DISTINCT me.entity_id) AS n
       FROM memory_entities me
       JOIN memories m ON m.id = me.memory_id
       WHERE m.agent_id = ?`,
    ),
    topicCount: one(
      `SELECT COUNT(DISTINCT mt.topic_id) AS n
       FROM memory_topics mt
       JOIN memories m ON m.id = mt.memory_id
       WHERE m.agent_id = ?`,
    ),
    mentionsCount: one(
      `SELECT COUNT(*) AS n
       FROM memory_entities me
       JOIN memories m ON m.id = me.memory_id
       WHERE m.agent_id = ?`,
    ),
    aboutCount: one(
      `SELECT COUNT(*) AS n
       FROM memory_topics mt
       JOIN memories m ON m.id = mt.memory_id
       WHERE m.agent_id = ?`,
    ),
    followsCount: one(
      `SELECT COUNT(*) AS n
       FROM memory_follows mf
       JOIN memories m ON m.id = mf.from_id
       WHERE m.agent_id = ?`,
    ),
  };
}

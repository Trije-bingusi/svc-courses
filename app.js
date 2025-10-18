import express from "express";
import { Pool } from "pg";
import { apiReference } from "@scalar/express-api-reference";
import YAML from "yamljs";

function required(name, fallback) {
    const v = process.env[name] ?? fallback;
    if (v === undefined || v === null || v === "") {
        throw new Error(`Missing env: ${name}`);
    }
    return v;
}

const PORT = Number(required("PORT", 3000));
const DATABASE_URL = required("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/courses");

const pool = new Pool({
    connectionString: DATABASE_URL,
    max: 10,
    idleTimeoutMillis: 10_000,
    connectionTimeoutMillis: 5_000,
});

const app = express();
app.use(express.json());

// Scalar API reference setup
const openapi = YAML.load("./openapi.yaml");
app.get("/openai.json", (_req, res) => res.json(openapi));

// Serve API reference at /docs
app.use(
    "/docs",
    apiReference({
        spec: { url: "/openai.json" },
        theme: "default",
        darkMode: true
    })
);

// Create tables if they don't already exist
async function ensureSchema() {
    // Enable the uuid-ossp extension (for uuid_generate_v4)
    await pool.query(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`);

    await pool.query(`
        CREATE TABLE IF NOT EXISTS courses (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        name TEXT NOT NULL,
        created_at TIMESTAMP NOT NULL DEFAULT now()
        );
    `);
    
    await pool.query(`
        CREATE TABLE IF NOT EXISTS lectures (
        id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
        course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        manifest_url TEXT,
        created_at TIMESTAMP NOT NULL DEFAULT now()
        );
    `);
}
await ensureSchema();

// Health endpoints
app.get("/healthz", (_req, res) => res.send("OK"));
app.get("/readyz", async (_req, res) => {
    try {
        await pool.query("SELECT 1");
        res.send("READY");
    } catch {
        res.status(500).send("NOT READY");
    }
});

// Courses
app.get("/api/courses", async (_req, res) => {
    const { rows} = await pool.query(
        `SELECT id, name, created_at FROM courses ORDER BY created_at`
    );
    res.json(rows);
});

app.post("/api/courses", async (req, res) => {
    const { name } = req.body || {};
    if (!name) {
        return res.status(400).json({ error: "Name is required!"});
    }
    const { rows } = await pool.query(
        `INSERT INTO courses (name) VALUES ($1) RETURNING id, name, created_at`,
        [name]
    );
    res.status(201).json(rows[0]); 
});

// Lectures
app.get("/api/courses/:courseId/lectures", async (req, res) => {
    const { courseId } = req.params;
    const { rows } = await pool.query(
        `SELECT id, course_id, title, manifest_url, created_at 
        FROM lectures WHERE course_id = $1 ORDER BY created_at`,
        [courseId]
    )
    res.json(rows);
});

app.post("/api/courses/:courseId/lectures", async (req, res) => {
    const { courseId} = req.params;
    const { title, manifest_url } = req.body || {};
    if (!title) {
        return res.status(400).json({ error: "Title is required!" });
    };
    const { rows } = await pool.query(
        `INSERT INTO lectures (course_id, title, manifest_url)
        VALUES ($1, $2, $3)
        RETURNING id, course_id, title, manifest_url, created_at`,
        [courseId, title, manifest_url]
    );
    res.status(201).json(rows[0]);
});

// error handling
app.use((err, _req, res, _next) => {
    console.error(err);
    res.status(500).json({ error: "Internal server error" });
});

// start + graceful shutdown
const server = app.listen(PORT, () => {
  console.log("Courses service listening on port", PORT);
});

function shutdown() {
    console.log("Shutting down server...");
    server.close(() => {
        pool.end().then(() => process.exit(0)); 
    });
    setTimeout(() => process.exit(1), 10000).unref();
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
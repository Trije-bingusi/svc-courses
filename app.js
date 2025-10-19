import express from "express";
import client from "prom-client";
import pinoHttp from "pino-http";
import YAML from "yamljs";
import { PrismaClient } from "@prisma/client";
import { apiReference } from "@scalar/express-api-reference";

function required(name, fallback) {
  const v = process.env[name] ?? fallback;
  if (v === undefined || v === null || v === "") {
    throw new Error(`Missing env: ${name}`);
  }
  return v;
}

// Prisma reads DATABASE_URL from env
const PORT = Number(required("PORT", 3000));
required("DATABASE_URL", "postgres://postgres:postgres@localhost:5432/courses");

const prisma = new PrismaClient();

const app = express();
app.use(express.json());

// Scalar API reference
const openapi = YAML.load("./openapi.yaml");
app.get("/openapi.json", (_req, res) => res.json(openapi));
app.use(
  "/docs",
  apiReference({
    spec: { url: "/openapi.json" },
    theme: "default",
    darkMode: true,
  })
);

app.use(pinoHttp());

// Prometheus metrics
client.collectDefaultMetrics();
const courseCreatedCounter = new client.Counter({
  name: "svc_courses_course_created_total",
  help: "Total number of courses created",
});
app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", client.register.contentType);
  res.end(await client.register.metrics());
});

// Health endpoints
app.get("/healthz", (_req, res) => res.send("OK"));
app.get("/readyz", async (_req, res) => {
  try {
    // Simple connectivity check to the DB
    await prisma.$queryRaw`SELECT 1`;
    res.send("READY");
  } catch {
    res.status(500).send("NOT READY");
  }
});

// Courses
app.get("/api/courses", async (_req, res) => {
  const courses = await prisma.course.findMany({
    orderBy: { created_at: "asc" },
    select: { id: true, name: true, created_at: true },
  });
  res.json(courses);
});

app.post("/api/courses", async (req, res) => {
  const { name } = req.body || {};
  if (!name) return res.status(400).json({ error: "Name is required!" });

  const course = await prisma.course.create({
    data: { name },
    select: { id: true, name: true, created_at: true },
  });
  courseCreatedCounter.inc();
  res.status(201).json(course);
});

// Lectures
app.get("/api/courses/:courseId/lectures", async (req, res) => {
  const { courseId } = req.params;
  const lectures = await prisma.lecture.findMany({
    where: { course_id: courseId },
    orderBy: { created_at: "asc" },
    select: {
      id: true,
      course_id: true,
      title: true,
      manifest_url: true,
      created_at: true,
    },
  });
  res.json(lectures);
});

app.post("/api/courses/:courseId/lectures", async (req, res) => {
  const { courseId } = req.params;
  const { title, manifest_url } = req.body || {};
  if (!title) return res.status(400).json({ error: "Title is required!" });

  const lecture = await prisma.lecture.create({
    data: { course_id: courseId, title, manifest_url },
    select: {
      id: true,
      course_id: true,
      title: true,
      manifest_url: true,
      created_at: true,
    },
  });
  res.status(201).json(lecture);
});

// Error handling
app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: "Internal server error" });
});

// Start + graceful shutdown
const server = app.listen(PORT, () => {
  console.log("Courses service listening on port", PORT);
});

function shutdown() {
  console.log("Shutting down server...");
  server.close(async () => {
    try {
      await prisma.$disconnect();
    } finally {
      process.exit(0);
    }
  });
  setTimeout(() => process.exit(1), 10000).unref();
}
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
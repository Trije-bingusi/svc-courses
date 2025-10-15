import express from "express";
const app = express();

app.get("/", (_req, res) => res.send("✅ It works!"));
app.get("/healthz", (_req, res) => res.send("ok"));

const port = process.env.PORT || 3000;
app.listen(port, () => console.log(`Server on :${port}`));
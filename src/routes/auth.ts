import { Router } from "express";
import { hashPassword, signToken, verifyPassword } from "../security";
import { createUser, findUserByEmail, toPublicUser } from "../store";

export const authRouter = Router();

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function readString(value: unknown): string | undefined {
  return typeof value === "string" ? value.trim() : undefined;
}

authRouter.post("/register", (req, res) => {
  const email = readString(req.body?.email)?.toLowerCase();
  const name = readString(req.body?.name);
  const password = typeof req.body?.password === "string" ? req.body.password : "";

  if (!email || !EMAIL_PATTERN.test(email)) {
    res.status(400).json({ error: "A valid email is required" });
    return;
  }
  if (!name) {
    res.status(400).json({ error: "Name is required" });
    return;
  }
  if (password.length < 8) {
    res.status(400).json({ error: "Password must be at least 8 characters" });
    return;
  }
  if (findUserByEmail(email)) {
    res.status(409).json({ error: "An account with that email already exists" });
    return;
  }

  const user = createUser({
    email,
    name,
    passwordHash: hashPassword(password),
  });

  res.status(201).json({
    user: toPublicUser(user),
    token: signToken(user.id, user.email),
  });
});

authRouter.post("/login", (req, res) => {
  const email = readString(req.body?.email)?.toLowerCase();
  const password = typeof req.body?.password === "string" ? req.body.password : "";

  if (!email || !password) {
    res.status(400).json({ error: "Email and password are required" });
    return;
  }

  const user = email ? findUserByEmail(email) : undefined;
  if (!user || !verifyPassword(password, user.passwordHash)) {
    res.status(401).json({ error: "Invalid email or password" });
    return;
  }

  res.json({
    user: toPublicUser(user),
    token: signToken(user.id, user.email),
  });
});

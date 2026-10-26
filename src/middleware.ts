import type { NextFunction, Request, Response } from "express";
import { findUserById } from "./store";
import { readToken } from "./security";

export interface AuthedRequest extends Request {
  userId?: string;
}

export function requireAuth(req: AuthedRequest, res: Response, next: NextFunction): void {
  const header = req.header("authorization");
  if (!header?.startsWith("Bearer ")) {
    res.status(401).json({ error: "Missing bearer token" });
    return;
  }

  const token = readToken(header.slice("Bearer ".length).trim());
  if (!token || !findUserById(token.sub)) {
    res.status(401).json({ error: "Invalid or expired token" });
    return;
  }

  req.userId = token.sub;
  next();
}

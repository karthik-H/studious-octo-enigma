import {
  createHmac,
  randomBytes,
  scryptSync,
  timingSafeEqual,
} from "crypto";
import type { AuthToken } from "./types";

const SCRYPT_KEYLEN = 64;
const TOKEN_TTL_SECONDS = 60 * 60 * 24;

function secret(): string {
  return process.env.AUTH_SECRET ?? "dev-only-change-me";
}

export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(password, salt, SCRYPT_KEYLEN).toString("hex");
  return `${salt}:${hash}`;
}

export function verifyPassword(password: string, stored: string): boolean {
  const [salt, hash] = stored.split(":");
  if (!salt || !hash) return false;
  const actual = Buffer.from(hash, "hex");
  const expected = scryptSync(password, salt, SCRYPT_KEYLEN);
  if (actual.length !== expected.length) return false;
  return timingSafeEqual(actual, expected);
}

export function signToken(userId: string, email: string): string {
  const header = Buffer.from(
    JSON.stringify({ alg: "HS256", typ: "JWT" }),
  ).toString("base64url");
  const payload = Buffer.from(
    JSON.stringify({
      sub: userId,
      email,
      exp: Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS,
    }),
  ).toString("base64url");
  const data = `${header}.${payload}`;
  const signature = createHmac("sha256", secret()).update(data).digest("base64url");
  return `${data}.${signature}`;
}

export function readToken(token: string): AuthToken | undefined {
  const parts = token.split(".");
  if (parts.length !== 3) return undefined;
  const [header, payload, signature] = parts;
  if (!header || !payload || !signature) return undefined;

  const data = `${header}.${payload}`;
  const expected = createHmac("sha256", secret()).update(data).digest("base64url");
  const actualBuf = Buffer.from(signature);
  const expectedBuf = Buffer.from(expected);
  if (actualBuf.length !== expectedBuf.length) return undefined;
  if (!timingSafeEqual(actualBuf, expectedBuf)) return undefined;

  try {
    const body = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")) as {
      sub?: unknown;
      email?: unknown;
      exp?: unknown;
    };
    if (typeof body.sub !== "string" || typeof body.email !== "string") return undefined;
    if (typeof body.exp !== "number" || body.exp < Math.floor(Date.now() / 1000)) {
      return undefined;
    }
    return { sub: body.sub, email: body.email };
  } catch {
    return undefined;
  }
}

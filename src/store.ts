import { randomUUID } from "crypto";
import { pool } from "./db";
import type { Product, PublicUser, User } from "./types";

interface UserRow {
  id: string;
  email: string;
  name: string;
  password_hash: string;
  created_at: Date | string;
}

interface ProductRow {
  id: string;
  name: string;
  description: string;
  price: string;
  sku: string;
  stock: number;
  created_at: Date | string;
}

function iso(value: Date | string): string {
  return value instanceof Date ? value.toISOString() : new Date(value).toISOString();
}

function mapUser(row: UserRow): User {
  return {
    id: row.id,
    email: row.email,
    name: row.name,
    passwordHash: row.password_hash,
    createdAt: iso(row.created_at),
  };
}

function mapProduct(row: ProductRow): Product {
  return {
    id: row.id,
    name: row.name,
    description: row.description,
    price: Number(row.price),
    sku: row.sku,
    stock: row.stock,
    createdAt: iso(row.created_at),
  };
}

export function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    createdAt: user.createdAt,
  };
}

export async function createUser(input: {
  email: string;
  name: string;
  passwordHash: string;
}): Promise<User> {
  const result = await pool.query<UserRow>(
    `INSERT INTO users (id, email, name, password_hash)
     VALUES ($1, $2, $3, $4)
     RETURNING id, email, name, password_hash, created_at`,
    [randomUUID(), input.email, input.name, input.passwordHash],
  );
  return mapUser(result.rows[0]);
}

export async function findUserByEmail(email: string): Promise<User | undefined> {
  const result = await pool.query<UserRow>(
    `SELECT id, email, name, password_hash, created_at
     FROM users
     WHERE email = $1`,
    [email],
  );
  return result.rows[0] ? mapUser(result.rows[0]) : undefined;
}

export async function findUserById(id: string): Promise<User | undefined> {
  try {
    const result = await pool.query<UserRow>(
      `SELECT id, email, name, password_hash, created_at
       FROM users
       WHERE id = $1`,
      [id],
    );
    return result.rows[0] ? mapUser(result.rows[0]) : undefined;
  } catch (error) {
    if (isInvalidUuid(error)) return undefined;
    throw error;
  }
}

export async function createProduct(input: {
  name: string;
  description: string;
  price: number;
  sku: string;
  stock: number;
}): Promise<Product> {
  const result = await pool.query<ProductRow>(
    `INSERT INTO products (id, name, description, price, sku, stock)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING id, name, description, price, sku, stock, created_at`,
    [randomUUID(), input.name, input.description, input.price, input.sku, input.stock],
  );
  return mapProduct(result.rows[0]);
}

export async function listProducts(): Promise<Product[]> {
  const result = await pool.query<ProductRow>(
    `SELECT id, name, description, price, sku, stock, created_at
     FROM products
     ORDER BY created_at ASC`,
  );
  return result.rows.map(mapProduct);
}

export async function findProductById(id: string): Promise<Product | undefined> {
  try {
    const result = await pool.query<ProductRow>(
      `SELECT id, name, description, price, sku, stock, created_at
       FROM products
       WHERE id = $1`,
      [id],
    );
    return result.rows[0] ? mapProduct(result.rows[0]) : undefined;
  } catch (error) {
    if (isInvalidUuid(error)) return undefined;
    throw error;
  }
}

function isInvalidUuid(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "22P02"
  );
}

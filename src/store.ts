import { randomUUID } from "crypto";
import type { Product, PublicUser, User } from "./types";

const users = new Map<string, User>();
const usersByEmail = new Map<string, string>();
const products = new Map<string, Product>();

export function toPublicUser(user: User): PublicUser {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    createdAt: user.createdAt,
  };
}

export function createUser(input: {
  email: string;
  name: string;
  passwordHash: string;
}): User {
  const user: User = {
    id: randomUUID(),
    email: input.email,
    name: input.name,
    passwordHash: input.passwordHash,
    createdAt: new Date().toISOString(),
  };
  users.set(user.id, user);
  usersByEmail.set(user.email, user.id);
  return user;
}

export function findUserByEmail(email: string): User | undefined {
  const id = usersByEmail.get(email);
  return id ? users.get(id) : undefined;
}

export function findUserById(id: string): User | undefined {
  return users.get(id);
}

export function createProduct(input: {
  name: string;
  description: string;
  price: number;
  sku: string;
  stock: number;
}): Product {
  const product: Product = {
    id: randomUUID(),
    name: input.name,
    description: input.description,
    price: input.price,
    sku: input.sku,
    stock: input.stock,
    createdAt: new Date().toISOString(),
  };
  products.set(product.id, product);
  return product;
}

export function listProducts(): Product[] {
  return Array.from(products.values());
}

export function findProductById(id: string): Product | undefined {
  return products.get(id);
}

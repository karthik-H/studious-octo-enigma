import { Router } from "express";
import { asyncHandler, requireAuth } from "../middleware";
import { createProduct, findProductById, listProducts } from "../store";

export const productsRouter = Router();

function readString(value: unknown): string | undefined {
  return typeof value === "string" ? value.trim() : undefined;
}

productsRouter.get(
  "/",
  asyncHandler(async (_req, res) => {
    res.json({ products: await listProducts() });
  }),
);

productsRouter.get(
  "/:id",
  asyncHandler(async (req, res) => {
    const product = await findProductById(req.params.id);
    if (!product) {
      res.status(404).json({ error: "Product not found" });
      return;
    }
    res.json({ product });
  }),
);

productsRouter.post(
  "/",
  requireAuth,
  asyncHandler(async (req, res) => {
    const name = readString(req.body?.name);
    const description = readString(req.body?.description) ?? "";
    const sku = readString(req.body?.sku) ?? "";
    const price = req.body?.price;
    const stock = req.body?.stock ?? 0;

    if (!name) {
      res.status(400).json({ error: "Product name is required" });
      return;
    }
    if (typeof price !== "number" || !Number.isFinite(price) || price < 0) {
      res.status(400).json({ error: "Price must be a number greater than or equal to 0" });
      return;
    }
    if (typeof stock !== "number" || !Number.isInteger(stock) || stock < 0) {
      res.status(400).json({ error: "Stock must be a whole number greater than or equal to 0" });
      return;
    }

    const product = await createProduct({ name, description, price, sku, stock });
    res.status(201).json({ product });
  }),
);

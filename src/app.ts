import express from "express";
import { authRouter } from "./routes/auth";
import { productsRouter } from "./routes/products";

export function createApp() {
  const app = express();
  app.use(express.json());

  app.get("/", (_req, res) => {
    res.json({
      service: "studious-octo-enigma",
      endpoints: {
        register: "POST /auth/register",
        login: "POST /auth/login",
        catalogProduct: "POST /products",
        listProducts: "GET /products",
        readProduct: "GET /products/:id",
      },
    });
  });

  app.use("/auth", authRouter);
  app.use("/products", productsRouter);

  app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
    console.error(error);
    res.status(500).json({ error: "Internal server error" });
  });

  return app;
}

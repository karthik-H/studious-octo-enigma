import { createApp } from "./app";
import { initDb, pool } from "./db";

const port = Number(process.env.PORT) || 3000;

initDb()
  .then(() => {
    createApp().listen(port, () => {
      console.log(`Ecommerce service listening on http://localhost:${port}`);
    });
  })
  .catch((error: unknown) => {
    console.error(error);
    pool.end().finally(() => process.exit(1));
  });

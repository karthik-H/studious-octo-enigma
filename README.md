# studious-octo-enigma

TypeScript ecommerce service with account registration, login, and a product catalog.

Accounts and products are stored in PostgreSQL. Set `DATABASE_URL` and set `AUTH_SECRET` before running anywhere other than local development. Tokens expire after 24 hours.

## Run

```bash
docker compose up -d
npm install
DATABASE_URL=postgres://ecommerce:ecommerce@localhost:5434/ecommerce npm run dev
```

`npm run build` compiles to `dist/`, and `npm start` runs the compiled server. The default port is `3000` (`PORT` overrides it).

## Auth

`POST /auth/register`

```json
{ "email": "ada@example.com", "name": "Ada", "password": "correct-horse" }
```

`POST /auth/login`

```json
{ "email": "ada@example.com", "password": "correct-horse" }
```

Both return the public user and a bearer token. Passwords must be at least 8 characters.

## Products

Adding a product requires `Authorization: Bearer <token>`.

`POST /products`

```json
{ "name": "Canvas tote", "description": "Natural cotton", "price": 24.5, "sku": "TOTE-1", "stock": 12 }
```

`price` is a non-negative number. `stock` is a non-negative integer and defaults to `0`. `description` and `sku` are optional.

Reading the catalog does not require a token.

- `GET /products` lists every product
- `GET /products/:id` returns one product

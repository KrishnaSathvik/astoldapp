# --- build stage ---
FROM node:24-slim AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

# --- runtime stage ---
FROM node:24-slim AS runtime
ENV NODE_ENV=production
WORKDIR /app
# Run as the built-in non-root user.
USER node
COPY --chown=node:node --from=build /app/node_modules ./node_modules
COPY --chown=node:node --from=build /app/dist ./dist
COPY --chown=node:node package.json ./
EXPOSE 8787
# OPENAI_API_KEY and APP_ATTEST_REQUIRED=true are provided as runtime secrets/env, never baked in.
CMD ["node", "dist/index.js"]

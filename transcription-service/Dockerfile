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
COPY --chown=node:node --from=build /app/node_modules ./node_modules
COPY --chown=node:node --from=build /app/dist ./dist
COPY --chown=node:node package.json ./
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
EXPOSE 8787
# The entrypoint starts as root only to chown the mounted volume, then drops to `node` via setpriv;
# the server process is unprivileged. OPENAI_API_KEY and APP_ATTEST_* are runtime secrets/env,
# never baked into the image.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["node", "dist/index.js"]

import { loadConfig } from './config.js';
import { buildServer, makeDefaultDeps } from './server.js';

async function main(): Promise<void> {
  const config = loadConfig();
  const app = await buildServer(makeDefaultDeps(config));
  try {
    await app.listen({ port: config.PORT, host: '0.0.0.0' });
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
}

void main();

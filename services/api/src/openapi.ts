// Writes the OpenAPI document to docs/openapi.json (run: pnpm openapi).
import 'reflect-metadata';
import { writeFileSync } from 'fs';
import { join } from 'path';
import { createApp } from './app.factory';

(async () => {
  const { app, doc } = await createApp();
  writeFileSync(join(__dirname, '../../../docs/openapi.json'), JSON.stringify(doc, null, 2));
  await app.close();
})();

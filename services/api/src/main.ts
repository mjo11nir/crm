import 'reflect-metadata';
import { createApp } from './app.factory';

async function bootstrap() {
  const { app } = await createApp();
  app.enableShutdownHooks();
  await app.listen(Number(process.env.PORT ?? 3000), '0.0.0.0');
}
void bootstrap();

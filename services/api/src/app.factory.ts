import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

export function configureApp(app: INestApplication) {
  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.enableCors({ origin: (process.env.CORS_ORIGINS ?? 'http://localhost:3001,http://localhost:8080').split(','), credentials: false });
  const httpAdapter = app.getHttpAdapter().getInstance();
  httpAdapter.disable?.('x-powered-by');
  return app;
}

export async function createApp() {
  const app = await NestFactory.create(AppModule, { logger: process.env.NODE_ENV === 'test' ? false : undefined });
  configureApp(app);
  const doc = SwaggerModule.createDocument(app, new DocumentBuilder().setTitle('Beauty CRM API').setVersion('1.0').addBearerAuth().build());
  SwaggerModule.setup('api/docs', app, doc);
  return { app, doc };
}

process.env.DATABASE_URL ??= 'postgresql://crm:crm@localhost:5432/crm_test';
process.env.JWT_SECRET ??= 'test-secret-do-not-use-in-production-0123456789';
process.env.BCRYPT_ROUNDS ??= '4';
process.env.NODE_ENV = 'test';

function required(name: string): string {
  const v = process.env[name];
  if (!v) throw new Error(`Missing required environment variable ${name}`);
  return v;
}

export const config = {
  get jwtSecret() {
    const s = required('JWT_SECRET');
    if (s.length < 32) throw new Error('JWT_SECRET must be at least 32 characters');
    return s;
  },
  accessTtlSeconds: Number(process.env.ACCESS_TOKEN_TTL ?? 900),
  refreshTtlDays: Number(process.env.REFRESH_TOKEN_TTL_DAYS ?? 30),
  bcryptRounds: Number(process.env.BCRYPT_ROUNDS ?? 12),
  trialDays: 14,
  publicBookingBaseUrl: process.env.PUBLIC_BOOKING_BASE_URL ?? 'http://localhost:3001',
};

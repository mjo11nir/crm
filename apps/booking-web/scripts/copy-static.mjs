// Next's standalone output does not include static assets; copy them so `pnpm start` serves CSS/JS.
import { cpSync, existsSync } from 'node:fs';
const target = '.next/standalone/apps/booking-web';
if (!existsSync(target)) throw new Error(`standalone output not found at ${target}`);
cpSync('.next/static', `${target}/.next/static`, { recursive: true });
if (existsSync('public')) cpSync('public', `${target}/public`, { recursive: true });
console.log('copied static assets into standalone output');

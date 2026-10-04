import { defineConfig } from 'astro/config';
export default defineConfig({ site: process.env.PUBLIC_SITE_URL || 'https://klicksea-web.vercel.app', output: 'static' });

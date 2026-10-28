/// <reference types="vitest" />
import { getViteConfig } from 'astro/config';

// The site's own Astro config (astro.config.mjs) — its integrations, its
// `@/` alias and the astro:* modules the config and components import — so
// .astro components render in tests through Astro's container API exactly
// as they build.
export default getViteConfig({
  test: {
    include: ['src/**/*.test.ts'],
  },
});

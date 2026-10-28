import { afterEach, describe, expect, it, vi } from 'vitest';
import { SITE } from '@data/constants';

// astro.config.mjs is evaluated once per build: load it fresh for each case.
async function siteFor(
  publicSiteUrl: string | undefined
): Promise<string | undefined> {
  vi.resetModules();
  if (publicSiteUrl === undefined) delete process.env.PUBLIC_SITE_URL;
  else process.env.PUBLIC_SITE_URL = publicSiteUrl;
  const { default: astroConfig } = await import('../../astro.config.mjs');
  return astroConfig.site;
}

const saved = process.env.PUBLIC_SITE_URL;
afterEach(() => {
  if (saved === undefined) delete process.env.PUBLIC_SITE_URL;
  else process.env.PUBLIC_SITE_URL = saved;
});

describe("the build's origin (astro.config.mjs)", () => {
  it('is PUBLIC_SITE_URL when a deploy sets it', async () => {
    expect(await siteFor('https://site-web-stage.example.workers.dev')).toBe(
      'https://site-web-stage.example.workers.dev'
    );
  });

  it('is LOCAL_ORIGIN for a local build — an origin, no path', async () => {
    const { LOCAL_ORIGIN } = await import('../../astro.config.mjs');
    expect(new URL(LOCAL_ORIGIN).origin).toBe(LOCAL_ORIGIN);
    expect(await siteFor(undefined)).toBe(LOCAL_ORIGIN);
    expect(await siteFor('')).toBe(LOCAL_ORIGIN);
  });
});

describe("the site's absolute URLs (src/data_files/constants.ts)", () => {
  it('are built on the origin Astro built for, without a trailing slash', () => {
    expect(SITE.url).toBe(import.meta.env.SITE.replace(/\/+$/, ''));
    expect(SITE.url.endsWith('/')).toBe(false);
  });
});

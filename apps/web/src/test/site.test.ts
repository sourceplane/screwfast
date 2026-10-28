import { describe, expect, it, vi } from 'vitest';
import { experimental_AstroContainer as AstroContainer } from 'astro/container';

// The name seam, exercised: with src/site.ts saying another name, the site's
// chrome and every line of its copy say that one. (That no source file still
// spells the template's name is the rename engine's leftover sweep.)
const NAME = 'Acme & Sons';
vi.mock('@/site', () => ({ SITE_NAME: 'Acme & Sons' }));

// Every string reachable from a value.
function strings(value: unknown, path = ''): [string, string][] {
  if (typeof value === 'string') return [[path, value]];
  if (Array.isArray(value))
    return value.flatMap((v, i) => strings(v, `${path}[${i}]`));
  if (value && typeof value === 'object')
    return Object.entries(value).flatMap(([k, v]) =>
      strings(v, path ? `${path}.${k}` : k)
    );
  return [];
}

describe('site identity (src/site.ts)', () => {
  it('names the site', async () => {
    const actual = await vi.importActual<typeof import('../site')>('../site');
    expect(actual.SITE_NAME.trim()).not.toBe('');
  });

  it("is the site's title (src/data_files/constants.ts)", async () => {
    const { SITE } = await import('@data/constants');
    expect(SITE.title).toBe(NAME);
    expect(SITE.description.startsWith(NAME)).toBe(true);
  });

  it('is the name every line of the copy, in every locale, uses', async () => {
    const { getCopy } = await import('@/copy');
    for (const locale of ['en', 'fr'] as const) {
      const copy = getCopy(locale);
      const named = strings(copy).filter(([, s]) => s.includes(NAME));
      // the titles, descriptions, hero and services copy, the pricing
      // subtitle, the features and the FAQ all name the company
      expect(named.length).toBeGreaterThan(30);
      expect(copy.site.ogTitle).toContain(NAME);
      expect(copy.data.pricing.subTitle).toContain(NAME);
    }
  });

  it("is the header logo's label", async () => {
    const { getCopy } = await import('@/copy');
    const { default: Navbar } =
      await import('../components/sections/navbar&footer/Navbar.astro');
    const container = await AstroContainer.create();
    const html = await container.renderToString(Navbar, {
      // the navbar reads the two locals the site's middleware sets
      locals: { locale: 'en', copy: getCopy('en') } as unknown as App.Locals,
    });
    expect(html).toContain('aria-label="Acme &amp; Sons"');
  });
});

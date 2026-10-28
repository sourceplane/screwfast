import { describe, expect, it } from 'vitest';
import worker from '../../worker/index';

// A stand-in for the assets binding: the files it holds, and the site's
// English 404 page for anything else (what `not_found_handling: "404-page"`
// serves).
function assets(files: Record<string, string>) {
  const seen: string[] = [];
  return {
    seen,
    env: {
      ASSETS: {
        fetch: async (input: Request | string) => {
          const { pathname } = new URL(
            typeof input === 'string' ? input : input.url
          );
          seen.push(pathname);
          return pathname in files
            ? new Response(files[pathname], {
                headers: { 'content-type': 'text/html' },
              })
            : new Response('english 404', { status: 404 });
        },
      },
    },
  };
}

describe('the Worker (worker/index.ts)', () => {
  it('hands a request to the assets and returns what they answer', async () => {
    const { env, seen } = assets({ '/products/': 'products' });
    const response = await worker.fetch(
      new Request('https://example.com/products/'),
      env
    );
    expect(seen).toEqual(['/products/']);
    expect(response.status).toBe(200);
    expect(await response.text()).toBe('products');
  });

  it("answers an unknown path with the site's English 404 page", async () => {
    const { env, seen } = assets({ '/fr/404/': 'french 404' });
    const response = await worker.fetch(
      new Request('https://example.com/no-such-page'),
      env
    );
    expect(seen).toEqual(['/no-such-page']);
    expect(response.status).toBe(404);
    expect(await response.text()).toBe('english 404');
  });

  it('answers an unknown path under /fr/ with the French 404 page, as a 404', async () => {
    for (const path of ['/fr/no-such-page', '/fr/blog/nope/', '/fr']) {
      const { env, seen } = assets({ '/fr/404/': 'french 404' });
      const response = await worker.fetch(
        new Request(`https://example.com${path}`),
        env
      );
      expect(seen).toEqual([path, '/fr/404/']);
      expect(response.status).toBe(404);
      expect(response.headers.get('content-type')).toBe('text/html');
      expect(await response.text()).toBe('french 404');
    }
  });

  it('does not take a path that merely starts with "fr" for French', async () => {
    const { env, seen } = assets({ '/fr/404/': 'french 404' });
    const response = await worker.fetch(
      new Request('https://example.com/freight'),
      env
    );
    expect(seen).toEqual(['/freight']);
    expect(await response.text()).toBe('english 404');
  });

  it('falls back to the English 404 page if the French one is missing', async () => {
    const { env } = assets({});
    const response = await worker.fetch(
      new Request('https://example.com/fr/nope'),
      env
    );
    expect(response.status).toBe(404);
    expect(await response.text()).toBe('english 404');
  });
});

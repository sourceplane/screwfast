// The site's Worker. The site builds fully static, so there is no server
// code: every page is a file in dist/, uploaded as Workers Static Assets. A
// request that matches a file is served from the assets without reaching this
// Worker; one that does not is handed here.
//
// It answers with the site's own 404 page and a 404 status: the assets'
// `not_found_handling: "404-page"` serves dist/404.html (English), and under
// /fr/ the French page (/fr/404/) instead — what the template's Vercel
// config did with its `/fr/:path*` → `/fr/404` rewrite.
interface Env {
  ASSETS: { fetch(request: Request | string): Promise<Response> };
}

const FRENCH = /^\/fr(\/|$)/;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const response = await env.ASSETS.fetch(request);
    const { pathname, origin } = new URL(request.url);
    if (response.status !== 404 || !FRENCH.test(pathname)) return response;
    const french = await env.ASSETS.fetch(new URL('/fr/404/', origin).href);
    if (!french.ok) return response;
    return new Response(french.body, {
      status: 404,
      headers: french.headers,
    });
  },
};

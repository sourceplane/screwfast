import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';
import starlight from '@astrojs/starlight';

import mdx from '@astrojs/mdx';
import { SITE_NAME } from './src/site.ts';

// The site's public origin: canonical, hreflang and Open Graph links, the
// sitemap and robots.txt are absolute. A deploy sets PUBLIC_SITE_URL to its
// environment's (its SITE_URL, else its workers.dev URL); a local build uses
// LOCAL_ORIGIN, the domain placeholder until the site has a domain. Renaming
// the site rewrites that line, so its layout is not left to its length.
// prettier-ignore
export const LOCAL_ORIGIN = 'https://screwfast.example.com';
const site = process.env.PUBLIC_SITE_URL || LOCAL_ORIGIN;

// https://astro.build/config
export default defineConfig({
  // https://docs.astro.build/en/guides/images/#authorizing-remote-images
  site,
  image: {
    domains: ['images.unsplash.com'],
  },
  // i18n: {
  //   defaultLocale: "en",
  //   locales: ["en", "fr"],
  //   fallback: {
  //     fr: "en",
  //   },
  //   routing: {
  //     prefixDefaultLocale: false,
  //   },
  // },
  prefetch: true,
  integrations: [
    sitemap({
      i18n: {
        defaultLocale: 'en', // All urls that don't contain language prefix will be treated as default locale
        locales: {
          en: 'en', // The `defaultLocale` value must present in `locales` keys
          fr: 'fr',
        },
      },
    }),
    starlight({
      title: `${SITE_NAME} Docs`,
      // https://github.com/withastro/starlight/blob/main/packages/starlight/CHANGELOG.md
      // If no Astro and Starlight i18n configurations are provided, the built-in default locale is used in Starlight and a matching Astro i18n configuration is generated/used.
      // If only a Starlight i18n configuration is provided, an equivalent Astro i18n configuration is generated/used.
      // If only an Astro i18n configuration is provided, the Starlight i18n configuration is updated to match it.
      // If both an Astro and Starlight i18n configurations are provided, an error is thrown.
      locales: {
        root: {
          label: 'English',
          lang: 'en',
        },
        de: { label: 'Deutsch', lang: 'de' },
        es: { label: 'Español', lang: 'es' },
        fa: { label: 'Persian', lang: 'fa', dir: 'rtl' },
        fr: { label: 'Français', lang: 'fr' },
        ja: { label: '日本語', lang: 'ja' },
        'zh-cn': { label: '简体中文', lang: 'zh-CN' },
      },
      // https://starlight.astro.build/guides/sidebar/
      sidebar: [
        {
          label: 'Quick Start Guides',
          translations: {
            de: 'Schnellstartanleitungen',
            es: 'Guías de Inicio Rápido',
            fa: 'راهنمای شروع سریع',
            fr: 'Guides de Démarrage Rapide',
            ja: 'クイックスタートガイド',
            'zh-cn': '快速入门指南',
          },
          items: [{ autogenerate: { directory: 'guides' } }],
        },
        {
          label: 'Tools & Equipment',
          // Translated guide intros exist per locale; these pages fall back to English.
          translations: {
            de: 'Werkzeuge & Ausrüstung',
            es: 'Herramientas y Equipo',
            fa: 'ابزار و تجهیزات',
            fr: 'Outils et Équipement',
            ja: 'ツールと機材',
            'zh-cn': '工具与设备',
          },
          items: [
            { label: 'Tool Guides', link: 'tools/tool-guides/' },
            { label: 'Equipment Care', link: 'tools/equipment-care/' },
          ],
        },
        {
          label: 'Construction Services',
          translations: {
            de: 'Baudienstleistungen',
            es: 'Servicios de Construcción',
            fa: 'خدمات ساخت‌وساز',
            fr: 'Services de Construction',
            ja: '建設サービス',
            'zh-cn': '施工服务',
          },
          items: [{ autogenerate: { directory: 'construction' } }],
        },
        {
          label: 'Advanced Topics',
          items: [{ autogenerate: { directory: 'advanced' } }],
        },
      ],
      social: [
        {
          icon: 'github',
          label: 'GitHub',
          href: 'https://github.com/sourceplane/screwfast',
        },
      ],
      disable404Route: true,
      customCss: ['./src/assets/styles/starlight.css'],
      favicon: '/favicon.ico',
      components: {
        SiteTitle: './src/components/ui/starlight/SiteTitle.astro',
        Head: './src/components/ui/starlight/Head.astro',
        MobileMenuFooter:
          './src/components/ui/starlight/MobileMenuFooter.astro',
        ThemeSelect: './src/components/ui/starlight/ThemeSelect.astro',
      },
      head: [
        {
          tag: 'meta',
          attrs: {
            property: 'og:image',
            content: new URL('/social.webp', site).href,
          },
        },
        {
          tag: 'meta',
          attrs: {
            property: 'twitter:image',
            content: new URL('/social.webp', site).href,
          },
        },
      ],
    }),
    mdx(),
  ],
  experimental: {
    clientPrerender: true,
  },
  vite: {
    plugins: [tailwindcss()],
  },
});

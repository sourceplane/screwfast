import fs from 'node:fs/promises';
import { minify } from 'html-minifier-terser';

// Minify every page Astro wrote to dist/ (the static build the Worker's
// assets serve).
const path = './dist';
try {
  await fs.access(path);
} catch {
  console.log('No build output found to minify (checked dist).');
  process.exit(0);
}

const files = await Array.fromAsync(fs.glob(`${path}/**/*.html`));
if (files.length === 0) {
  console.log(`No HTML files found under ${path}.`);
  process.exit(0);
}

await Promise.all(
  files.map(async file => {
    console.log('Processing file:', file);
    let html = await fs.readFile(file, 'utf-8');

    html = await minify(html, {
      removeComments: true,
      preserveLineBreaks: true,
      collapseWhitespace: true,
      minifyJS: true,
    });
    await fs.writeFile(file, html);
  })
);

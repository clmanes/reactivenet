// Genera static/img/og-default.png (1200×630): logo su fondo scuro con i
// colori del brand. Eseguire dalla radice del repo (dove vive sharp):
//   bun site/scripts/generate-og.mjs
import sharp from "sharp";
import { mkdir } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const site = join(dirname(fileURLToPath(import.meta.url)), "..");

const svg = `<svg width="1200" height="630" xmlns="http://www.w3.org/2000/svg">
  <rect width="1200" height="630" fill="#2a303c"/>
  <circle cx="960" cy="90" r="320" fill="#5b3df5" opacity="0.18"/>
  <circle cx="200" cy="560" r="340" fill="#2dd4bf" opacity="0.10"/>
  <text x="600" y="470" text-anchor="middle" font-family="sans-serif"
        font-size="76" font-weight="700" fill="#ffffff">ReactiveNET</text>
  <text x="600" y="530" text-anchor="middle" font-family="sans-serif"
        font-size="32" fill="#b2ccd6">La tua app in una frase, privata by design</text>
</svg>`;

const logo = await sharp(join(site, "static/logo.svg"), { density: 300 })
  .resize(220, 220)
  .png()
  .toBuffer();

await mkdir(join(site, "static/img"), { recursive: true });
await sharp(Buffer.from(svg))
  .composite([{ input: logo, left: 490, top: 110 }])
  .png()
  .toFile(join(site, "static/img/og-default.png"));

console.log("static/img/og-default.png scritto");

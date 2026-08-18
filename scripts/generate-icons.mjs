// Rasterises the PWA icons from the single source of truth: `logo.svg` in the
// repo root. It is copied into `public/` (so Vite serves it at `/logo.svg`) and
// rendered to PNG. Run with `bun run icons` after editing logo.svg.
import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import sharp from "sharp";

const root = fileURLToPath(new URL("../", import.meta.url));
const publicDir = root + "public/";

// Must match the badge background in logo.svg: the maskable variant is the badge
// centred on a flat square of the same colour, so the rounded corners disappear
// and the launcher can apply its own mask.
const BADGE_BACKGROUND = "#16161d";
const MASKABLE_SAFE_ZONE = 368; // ~72% of 512, inside the 80% safe circle

const svg = await readFile(root + "logo.svg");
await writeFile(publicDir + "logo.svg", svg);
console.log("logo.svg -> public/logo.svg");

const render = (size) =>
  sharp(svg, { density: 384 })
    .resize(size, size, { fit: "contain", background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png({ compressionLevel: 9 })
    .toBuffer();

for (const [out, size] of [
  ["pwa-192.png", 192],
  ["pwa-512.png", 512],
  ["apple-touch-icon-180.png", 180],
]) {
  await writeFile(publicDir + out, await render(size));
  console.log(`logo.svg -> ${out} (${size}x${size})`);
}

const maskable = await sharp({
  create: { width: 512, height: 512, channels: 4, background: BADGE_BACKGROUND },
})
  .composite([{ input: await render(MASKABLE_SAFE_ZONE), gravity: "centre" }])
  .png({ compressionLevel: 9 })
  .toBuffer();
await writeFile(publicDir + "pwa-maskable-512.png", maskable);
console.log("logo.svg -> pwa-maskable-512.png (512x512, maskable)");

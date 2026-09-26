// Screenshots each shot page: node capture.js <port> <outDir> <shot...>
const { chromium } = require("playwright");
const path = require("path");

(async () => {
  const [port, outDir, ...shots] = process.argv.slice(2);
  const browser = await chromium.launch({
    args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
  });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  page.on("console", (m) => { if (m.type() === "error") console.log("page:", m.text()); });
  for (const shot of shots) {
    const t0 = Date.now();
    await page.goto(`http://127.0.0.1:${port}/index.html?shot=${shot}`);
    await page.waitForFunction(() => window.__done || window.__error, null, { timeout: 300000 });
    const err = await page.evaluate(() => window.__error);
    if (err) {
      console.log(`${shot}: ERROR ${err}`);
      continue;
    }
    const file = path.join(outDir, `${shot}.png`);
    await page.locator("canvas").screenshot({ path: file });
    console.log(`${shot}: ${file} (${((Date.now() - t0) / 1000).toFixed(1)}s)`);
  }
  await browser.close();
})();

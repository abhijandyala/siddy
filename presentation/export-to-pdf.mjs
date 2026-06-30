import puppeteer from 'puppeteer-core';
import { PDFDocument } from 'pdf-lib';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const htmlPath = path.join(__dirname, 'index.html');
const outPath = path.join(__dirname, 'Voca-FBLA-Presentation.pdf');

if (!fs.existsSync(CHROME)) {
  console.error('Google Chrome not found at', CHROME);
  process.exit(1);
}

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage'],
});

try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 2 });

  await page.goto('http://127.0.0.1:8080/index.html', {
    waitUntil: 'load',
    timeout: 60000,
  });
  await page.waitForSelector('.slide.visible', { timeout: 10000 });
  await page.evaluate(async () => {
    if (document.fonts?.ready) {
      await Promise.race([
        document.fonts.ready,
        new Promise((resolve) => setTimeout(resolve, 3000)),
      ]);
    }
    const slideNum = document.getElementById('slide-num');
    if (slideNum) slideNum.style.display = 'none';
    const demoVid = document.getElementById('demoVid');
    if (demoVid) demoVid.pause();
  });

  const slideCount = await page.evaluate(() => document.querySelectorAll('.slide').length);
  const mergedPdf = await PDFDocument.create();

  for (let i = 0; i < slideCount; i += 1) {
    await page.evaluate((index) => {
      document.querySelectorAll('.slide').forEach((slide, j) => {
        slide.classList.toggle('visible', j === index);
      });
    }, i);

    await new Promise((resolve) => setTimeout(resolve, 400));

    const pdfBytes = await page.pdf({
      width: '1920px',
      height: '1080px',
      printBackground: true,
      margin: { top: 0, right: 0, bottom: 0, left: 0 },
    });

    const slidePdf = await PDFDocument.load(pdfBytes);
    const [copiedPage] = await mergedPdf.copyPages(slidePdf, [0]);
    mergedPdf.addPage(copiedPage);
    process.stdout.write(`Exported slide ${i + 1}/${slideCount}\r`);
  }

  fs.writeFileSync(outPath, await mergedPdf.save());
  console.log(`\nSaved ${slideCount}-slide PDF to ${outPath}`);
} finally {
  await browser.close();
}

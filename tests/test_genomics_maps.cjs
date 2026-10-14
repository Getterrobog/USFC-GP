// Run with Playwright available via NODE_PATH; no server or internet needed.
const assert=require('node:assert/strict');
const {pathToFileURL}=require('node:url');
const path=require('node:path');
const {chromium}=require('playwright');
(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    const page=await browser.newPage({viewport:{width:1280,height:900}});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.goto(pathToFileURL(path.resolve('Output/Genomics/maps.html')).href);
    assert.match(await page.locator('#result-count').textContent(),/1,000 plotted/);
    assert.equal(await page.locator('article').count(),80);
    await page.locator('#search').fill('Menidia menidia');
    assert.equal(await page.locator('article:visible').count(),1);
    const card=page.locator('article:visible'),map=card.locator('.map-host svg');
    assert.equal(await map.getAttribute('data-count'),'238');
    const bounds=await map.evaluate(s=>[s.dataset.west,s.dataset.east,s.dataset.south,s.dataset.north]);
    assert.deepEqual(bounds,['-100','-50','5','60']);
    const annual=await card.locator('.year-select option').evaluateAll(opts=>opts.slice(1).map(o=>({year:o.value,count:Number(o.textContent.match(/— ([\d,]+)/)[1].replaceAll(',',''))})));
    for(const {year,count} of annual){
      await card.locator('.year-select').selectOption(year);
      assert.equal(Number(await map.getAttribute('data-count')),count);
      const bar=card.locator(`.timeline-bar[data-year="${year}"]`);
      const dims=await bar.evaluate(b=>({height:Number(b.getAttribute('height')),expected:Number(b.dataset.count)/Number(b.dataset.max)*Number(b.dataset.plotHeight),fill:b.getAttribute('fill')}));
      assert.ok(Math.abs(dims.height-dims.expected)<1e-8);assert.equal(dims.fill,'#bd372d');
      assert.deepEqual(await map.evaluate(s=>[s.dataset.west,s.dataset.east,s.dataset.south,s.dataset.north]),bounds);
    }
    await card.locator('.year-select').selectOption('all');
    await card.locator('.sample-cell').first().click();
    assert.equal(await card.locator('.cell-details').getAttribute('open'),'');
    assert.match(await card.locator('.cell-records').textContent(),/LOC\d+/);
    assert.ok(await card.locator('.cell-records a[href^="https://"]').count()>0);
    const downloadPromise=page.waitForEvent('download');await card.locator('.download-map').click();
    const download=await downloadPromise;assert.match(download.suggestedFilename(),/Menidia_menidia_all_genomics.svg/);
    await card.locator('.play').click();await page.waitForTimeout(1150);
    assert.equal(await card.locator('.play').textContent(),'Pause');
    assert.notEqual(await card.locator('.year-select').inputValue(),'all');
    await page.locator('#life-stage').selectOption('unknown');
    assert.equal(await card.locator('.play').textContent(),'Play years');
    await page.locator('#life-stage').selectOption('');
    await page.locator('#cohort').selectOption('all_wgs');
    assert.match(await card.locator('.record-summary').textContent(),/1,277 WGS accessions/);
    await page.locator('#extent').selectOption('world');
    assert.equal(await map.getAttribute('data-count'),'251');
    await page.locator('#year-min').fill('2020');await page.locator('#year-max').fill('2000');
    assert.equal(await page.locator('article:visible').count(),0);assert.ok(await page.locator('#filter-error').isVisible());
    await page.locator('button[type="reset"]').click();await page.waitForTimeout(50);
    assert.match(await page.locator('#result-count').textContent(),/1,000 plotted/);
    await page.locator('#search').fill('Atherinomorus stipes');await page.locator('#cohort').selectOption('all_wgs');
    assert.equal(await page.locator('article:visible .map-host svg').getAttribute('data-count'),'15');
    await page.locator('#include-undated').uncheck();assert.equal(await page.locator('article:visible').count(),0);
    // The same independent genomic criteria apply on both historical pages.
    for(const file of ['index.html','overview.html']){
      await page.goto(pathToFileURL(path.resolve('Output/SamplingAtlas',file)).href);
      assert.equal(await page.locator('article .genomic-stats').count(),80);
      await page.locator('#genomic-filters').evaluate(e=>e.open=true);
      await page.locator('#genomics-min-candidates').fill('200');
      const found=await page.locator('article:visible').evaluateAll(a=>a.map(x=>x.dataset.species));
      assert.deepEqual(found.sort(),['fundulus heteroclitus','menidia menidia']);
      await page.locator('button[type="reset"]').click();await page.waitForTimeout(50);
      await page.locator('#genomics-availability').selectOption('unknown');
      assert.equal(await page.locator('article:visible').count(),1);
      assert.equal(await page.locator('article:visible').getAttribute('data-species'),'myctophum opalinum');
      await page.locator('button[type="reset"]').click();await page.waitForTimeout(50);
      await page.locator('#genomics-reference').selectOption('annotated');
      assert.equal(await page.locator('article:visible').count(),8);
    }
    await page.setViewportSize({width:390,height:844});
    await page.goto(pathToFileURL(path.resolve('Output/Genomics/maps.html')).href+'#Menidia_menidia');
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    assert.deepEqual(errors,[]);
    console.log('Browser checks passed: genomic filters on both atlases, map counts, year/bar agreement, fixed extents, provenance, playback, SVG export, unknowns and mobile layout.');
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

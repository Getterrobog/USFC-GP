// Compare all three viewers to the curated source, including missing/zero values.
const assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
const {pathToFileURL}=require('node:url');const path=require('node:path');
const {chromium}=require('playwright');
const source=JSON.parse(execFileSync('python3',['-c','import csv,json; print(json.dumps(list(csv.DictReader(open("Output/SpeciesTraits/species_summary.csv")))))'],{encoding:'utf8'}));
const expected=fn=>source.filter(fn).map(r=>r.species.toLowerCase()).sort();
(async()=>{
 const browser=await chromium.launch({headless:true});
 try{
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
  for(const file of ['Output/SamplingAtlas/index.html','Output/SamplingAtlas/overview.html','Output/Genomics/maps.html']){
   await page.goto(pathToFileURL(path.resolve(file)).href);
   const genomic=file.includes('Genomics');
   const reset=async()=>{await page.locator('button[type="reset"]').click();await page.waitForTimeout(80);if(genomic)await page.locator('#plotted-only').uncheck();await page.locator('#trait-filters').evaluate(e=>e.open=true);};
   const visible=async()=>page.locator('article:visible').evaluateAll(xs=>xs.map(x=>x.dataset.species.toLowerCase()).sort());
   await reset();assert.equal((await visible()).length,80);
   assert.equal(await page.locator('.species-traits').count(),80);
   await page.locator('#trait-fishbase_feeding_group').selectOption('mainly plants/detritus');
   assert.deepEqual(await visible(),expected(r=>r.fishbase_feeding_group==='mainly plants/detritus'));
   await reset();await page.locator('#trait-migration_best_available').selectOption('oceano-estuarine');
   assert.deepEqual(await visible(),expected(r=>r.migration_best_available==='oceano-estuarine'));
   await reset();await page.locator('#trait-body_shape').selectOption('elongated');
   assert.deepEqual(await visible(),expected(r=>r.body_shape==='elongated'));
   await reset();const trophic=page.locator('.trait-range[data-trait="trophic_level_preferred"]');
   await trophic.locator('.trait-min').fill('3');await trophic.locator('.trait-max').fill('3.5');
   assert.deepEqual(await visible(),expected(r=>r.trophic_level_preferred!==''&&Number(r.trophic_level_preferred)>=3&&Number(r.trophic_level_preferred)<=3.5));
   await trophic.locator('.trait-min').fill('4');assert.equal((await visible()).length,0);assert.ok(await page.locator('#trait-range-error').isVisible());
   await reset();await trophic.locator('.trait-availability').selectOption('missing');
   assert.deepEqual(await visible(),expected(r=>r.trophic_level_preferred===''));
   await reset();const depth=page.locator('.trait-range[data-trait="depth_shallow_m"]');
   await depth.locator('.trait-min').fill('0');await depth.locator('.trait-max').fill('0');
   assert.deepEqual(await visible(),expected(r=>r.depth_shallow_m!==''&&Number(r.depth_shallow_m)===0));
   await reset();await page.locator('#search').fill('Menidia menidia');
   assert.equal((await visible()).length,1);
   const card=page.locator('article:visible .species-traits');
   assert.match(await card.textContent(),/3\.19 · diet estimate/);
   assert.match(await card.textContent(),/latest status unverified/);
   assert.ok(await card.locator('.trait-evidence a[href^="http"]').count()>0);
   await page.locator('#genomic-filters').evaluate(e=>e.open=true);
   await page.locator('#genomics-min-candidates').fill('300');assert.equal((await visible()).length,0);
   await reset();assert.equal((await visible()).length,80);
   await page.setViewportSize({width:390,height:844});await page.locator('#search').fill('Menidia menidia');
   assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
   await page.setViewportSize({width:1280,height:900});
  }
  assert.deepEqual(errors,[]);console.log('All three trait viewers match the source: categories, numeric bounds, zero depths, missingness, combined filters, provenance, reset and mobile layout.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

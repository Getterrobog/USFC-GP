// Run after build_sampling_explorer.R, with Playwright available on NODE_PATH.
const assert=require('node:assert/strict');
const {execFileSync}=require('node:child_process');
const {pathToFileURL}=require('node:url');
const path=require('node:path');
const {chromium}=require('playwright');
const traits=JSON.parse(execFileSync('python3',['-c','import csv,json; print(json.dumps(list(csv.DictReader(open("Output/SpeciesTraits/species_summary.csv")))))'],{encoding:'utf8'}));
(async()=>{
 const browser=await chromium.launch({headless:true});
 try {
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  const url=pathToFileURL(path.resolve('Output/SamplingAtlas/explorer.html')).href;
  await page.goto(url);
  assert.equal(await page.locator('#map-host svg:visible').count(),1);
  const selectable=()=>page.evaluate(()=>eligible.map(c=>c.species).sort());
  assert.equal((await selectable()).length,80);
  const search=async(name)=>{await page.locator('#species-search').fill(name);await page.locator('#species-search').press('Enter');};
  await search('Menidia menidia');
  assert.equal(await page.locator('#map-host svg').getAttribute('data-species'),'Menidia menidia');
  await page.locator('#map-stage').selectOption('larva');
  const larvalCount=await page.locator('#map-host svg').getAttribute('data-specimens');
  await page.locator('#map-stage').selectOption('adult');
  assert.notEqual(await page.locator('#map-host svg').getAttribute('data-specimens'),larvalCount);
  // Common-name search, keyboard selection, and rejected free text.
  await page.locator('#species-search').fill('Blueback shad');
  await page.locator('#species-search').press('ArrowDown');await page.locator('#species-search').press('Enter');
  assert.equal(await page.locator('#map-host svg').getAttribute('data-species'),'Alosa aestivalis');
  await page.locator('#species-search').fill('no such fish');await page.locator('#species-search').press('Enter');
  assert.equal(await page.locator('#map-host svg').getAttribute('data-species'),'Alosa aestivalis');
  await page.locator('#species-search').press('Escape');assert.match(await page.locator('#species-search').inputValue(),/Alosa aestivalis/);
  await page.locator('#species-toggle').click();await page.locator('#species-options [role=option]').filter({hasText:'Menidia menidia'}).click();
  assert.equal(await page.locator('#map-host svg').getAttribute('data-species'),'Menidia menidia');
  // Render all 320 species/stage combinations and reconcile the SVG with the R export.
  const checked=await page.evaluate(()=>{
   let n=0;
   for(const c of candidates){
    choose(c);
    for(const stage of ['all','adult','larva','mixed']){
     $('map-stage').value=stage;renderMap();
     const s=explorer.summary.find(s=>s.species===c.species&&s.map_stage===stage),svg=$('map-host').querySelector('svg');
     const cells=Array.from(svg.querySelectorAll('.sample-cell'));
     if(cells.length!==s.cells||cells.reduce((sum,c)=>sum+Number(c.dataset.specimens),0)!==s.mapped_specimens)throw Error('Cell totals: '+c.species+'/'+stage);
     if(svg.dataset.west!=='-100'||svg.dataset.east!=='-50'||svg.dataset.south!=='5'||svg.dataset.north!=='60'||svg.getAttribute('viewBox')!=='0 0 1250 1220')throw Error('Extent changed');
     if(Number(svg.dataset.maximum)!==s.color_maximum)throw Error('Scale changed');
     for(const label of svg.querySelectorAll('.year-label')){
      const box=label.getBBox();if(box.x+box.width>1250||box.y+box.height>1071||box.y<105)throw Error('Clipped year label: '+c.species+'/'+stage);
      if(!/\(\d+\)/.test(label.textContent))throw Error('Missing specimen count');
     }
     n++;
    }
   }
   return n;
  });
  assert.equal(checked,320);
  await page.locator('.filters').evaluate(e=>e.open=true);
  const reset=async()=>{await page.locator('button[type=reset]').click();await page.waitForTimeout(80);};
  await page.locator('#taxonomy-family').selectOption('Clupeidae');
  const families=await page.evaluate(()=>eligible.map(c=>c.template.dataset.family));assert.ok(families.length>0&&families.every(f=>f==='Clupeidae'));
  await page.locator('#species-search').fill('Menidia');assert.equal(await page.locator('#species-options [role=option]').count(),0);
  await page.locator('#species-search').press('Escape');
  await reset();await page.locator('#trait-filters').evaluate(e=>e.open=true);
  await page.locator('#trait-body_shape').selectOption('elongated');
  assert.deepEqual(await selectable(),traits.filter(r=>r.body_shape==='elongated').map(r=>r.species).sort());
  await reset();await page.locator('#genomic-filters').evaluate(e=>e.open=true);
  await page.locator('#genomics-min-candidates').fill('300');
  assert.deepEqual(await selectable(),await page.evaluate(()=>candidates.filter(c=>Number(c.template.content.querySelector('.genomic-stats').dataset.candidates)>=300).map(c=>c.species).sort()));
  await page.locator('#min-specimens').fill('999999999');
  assert.equal((await selectable()).length,0);assert.ok(await page.locator('#empty-results').isVisible());
  assert.ok(await page.locator('#species-search').isDisabled());assert.ok(await page.locator('#map-stage').isDisabled());
  assert.equal(await page.locator('#map-host svg:visible').count(),0);
  await reset();assert.equal((await selectable()).length,80);
  await page.locator('#region').selectOption('Caribbean');await page.locator('#mapped-only').check();
  const expectedRegional=await page.evaluate(()=>candidates.filter(c=>c.records.filter(r=>r.region==='Caribbean').reduce((s,r)=>s+r.mapped_specimens,0)>=50).map(c=>c.species).sort());
  assert.deepEqual(await selectable(),expectedRegional);
  await reset();await search('Menidia menidia');await page.locator('#map-stage').selectOption('larva');
  const download=page.waitForEvent('download');await page.locator('#download-map').click();assert.equal((await download).suggestedFilename(),'Menidia_menidia_larva_all_years.svg');
  await page.locator('#enlarge-map').click();assert.equal(await page.locator('#enlarge-map').getAttribute('aria-pressed'),'true');
  await page.locator('#enlarge-map').click();
  await page.goto(url+'#Menidia_menidia/larva');
  await page.reload();
  assert.equal(await page.locator('#map-host svg').getAttribute('data-species'),'Menidia menidia');assert.equal(await page.locator('#map-stage').inputValue(),'larva');
  await page.setViewportSize({width:390,height:844});
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  await page.locator('.filters').evaluate(e=>e.open=true);await page.locator('#trait-filters').evaluate(e=>e.open=true);
  assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  assert.deepEqual(errors,[]);
  console.log('Explorer browser checks passed: 320 maps, searchable/filtered choices, stage counts, bounds/scales, label fit, empty results, download, deep link and mobile layout.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});

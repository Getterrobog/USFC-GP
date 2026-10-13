// Embedded data and coastlines keep the page usable from file:// and static hosting.
'use strict';
const genomeData=JSON.parse(document.getElementById('genomic-data').textContent);
const genomicRecords=genomeData.records.map(row=>Object.fromEntries(genomeData.columns.map((key,i)=>[key,row[i]])));
const sourceRegistry=new Map(genomeData.sources.map(s=>[s.source_id,s]));
const bySpecies=new Map();
for(const r of genomicRecords){if(!bySpecies.has(r.species))bySpecies.set(r.species,[]);bySpecies.get(r.species).push(r);}
const states=Array.from(document.querySelectorAll('article'),article=>({article,records:bySpecies.get(article.dataset.species)||[],traits:traitCandidate(article),year:'all',timer:null,selectedCell:null}));
const $=id=>document.getElementById(id);
const number=n=>n.toLocaleString();
const esc=value=>String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const yearKey=r=>r.year===null?'undated':String(r.year);
const yearText=y=>y==='all'?'All years':y==='undated'?'Undated':y;
const hasCoordinates=r=>Number.isFinite(r.latitude)&&Number.isFinite(r.longitude);
function extent(){return $('extent').value==='world'?{west:-180,east:180,south:-90,north:90}:genomeData.bounds;}
function inBounds(r,b){return hasCoordinates(r)&&r.longitude>=b.west&&r.longitude<=b.east&&r.latitude>=b.south&&r.latitude<=b.north;}
function groupCells(records){
  const groups=new Map();
  for(const r of records){const k=r.cell_lon+','+r.cell_lat;if(!groups.has(k))groups.set(k,[]);groups.get(k).push(r);}
  return Array.from(groups,([key,rows])=>({key,lon:rows[0].cell_lon,lat:rows[0].cell_lat,rows})).sort((a,b)=>b.lat-a.lat||a.lon-b.lon);
}
function yearCounts(rows){const c=new Map();for(const r of rows){const k=yearKey(r);c.set(k,(c.get(k)||0)+1);}return Array.from(c).sort((a,b)=>a[0]==='undated'?1:b[0]==='undated'?-1:Number(a[0])-Number(b[0]));}
function yearCountLabel(rows){return yearCounts(rows).map(([y,n])=>yearText(y)+' ('+number(n)+')').join(', ');}
function color(count,max){const t=Math.log1p(count)/Math.log1p(Math.max(1,max));const start=[255,244,209],end=[166,38,28];return 'rgb('+start.map((v,i)=>Math.round(v+(end[i]-v)*t)).join(',')+')';}
function stop(state){if(state.timer)clearInterval(state.timer);state.timer=null;state.article.querySelector('.play').textContent='Play years';}
function selectedRecords(state){
  const stage=$('life-stage').value,lo=$('year-min').value===''?null:Number($('year-min').value),hi=$('year-max').value===''?null:Number($('year-max').value);
  return state.records.filter(r=>($('cohort').value!=='candidates'||r.map_candidate)&&(!stage||r.life_stage===stage)&&
    (!$('exclude-approximate').checked||!r.coordinate_approximate)&&
    (r.year===null?$('include-undated').checked:(lo===null||r.year>=lo)&&(hi===null||r.year<=hi)));
}
function mapGeometry(){
  const b=extent(),world=$('extent').value==='world',left=60,top=95,width=780;
  const height=world?390:width*(b.north-b.south)/(b.east-b.west)/Math.cos((b.south+b.north)/2*Math.PI/180);
  return {b,left,top,width,height,bottom:top+height,canvasHeight:top+height+100,
    x:lon=>left+(lon-b.west)/(b.east-b.west)*width,y:lat=>top+(b.north-lat)/(b.north-b.south)*height};
}
const coastCache=new Map();
function coastSvg(g){
  const mode=$('extent').value;if(coastCache.has(mode))return coastCache.get(mode);
  const paths=genomeData.coast.filter(p=>p.some(([lon,lat])=>lon>=g.b.west-10&&lon<=g.b.east+10&&lat>=g.b.south-10&&lat<=g.b.north+10)).map(p=>
    '<polygon points="'+p.map(([lon,lat])=>g.x(lon).toFixed(2)+','+g.y(lat).toFixed(2)).join(' ')+'" fill="#e0e3df" stroke="#839196" stroke-width=".65"/>').join('');
  coastCache.set(mode,paths);return paths;
}
function drawMap(state){
  const a=state.article,g=mapGeometry(),prefix=a.id,frame=state.plotted.filter(r=>state.year==='all'||yearKey(r)===state.year);
  state.frame=frame;state.cells=groupCells(frame);
  const allCells=groupCells(state.plotted),annualCells=Array.from(new Set(state.plotted.map(yearKey))).flatMap(y=>groupCells(state.plotted.filter(r=>yearKey(r)===y)));
  // All-year and annual views use one scale for the current species/filter selection.
  state.maximum=Math.max(1,...allCells.map(c=>c.rows.length),...annualCells.map(c=>c.rows.length));
  const clip='clip-'+prefix,hatch='hatch-'+prefix;
  let svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 ${g.canvasHeight.toFixed(2)}" role="img" aria-labelledby="title-${prefix}" data-west="${g.b.west}" data-east="${g.b.east}" data-south="${g.b.south}" data-north="${g.b.north}" data-maximum="${state.maximum}" data-count="${frame.length}">
  <title id="title-${prefix}">${esc(a.dataset.species)} · ${yearText(state.year)} · ${frame.length} WGS BioSample accessions</title>
  <defs><clipPath id="${clip}"><rect x="${g.left}" y="${g.top}" width="${g.width}" height="${g.height}"/></clipPath><pattern id="${hatch}" width="8" height="8" patternUnits="userSpaceOnUse"><path d="M-2 2L2-2M0 8L8 0M6 10L10 6" stroke="#233342" stroke-opacity=".55" stroke-width="1"/></pattern></defs>
  <rect width="900" height="${g.canvasHeight}" fill="white"/><text x="60" y="30" font-size="20" font-style="italic">${esc(a.dataset.species)}</text><text class="map-year" x="60" y="66" font-size="28" font-weight="bold">${yearText(state.year)}</text><text x="840" y="65" text-anchor="end" font-size="16">${number(frame.length)} accessions</text>
  <rect x="${g.left}" y="${g.top}" width="${g.width}" height="${g.height}" fill="#edf5f8" stroke="#9eadb5"/><g clip-path="url(#${clip})">${coastSvg(g)}`;
  const step=$('extent').value==='world'?30:10;
  for(let lon=Math.ceil(g.b.west/step)*step;lon<=g.b.east;lon+=step)svg+=`<path d="M${g.x(lon)} ${g.top}V${g.bottom}" stroke="#c2d4df" stroke-dasharray="3 5"/>`;
  for(let lat=Math.ceil(g.b.south/step)*step;lat<=g.b.north;lat+=step)svg+=`<path d="M${g.left} ${g.y(lat)}H${g.left+g.width}" stroke="#c2d4df" stroke-dasharray="3 5"/>`;
  if($('extent').value==='atlas')for(const [label,lon,lat] of [['North Atlantic',-65,38],['Gulf of Mexico',-91,24],['Caribbean Sea',-73,14],['Cuba',-79,22],['Bahamas',-75,26]])svg+=`<text x="${g.x(lon)}" y="${g.y(lat)}" text-anchor="middle" font-size="14" fill="#536e7e">${label}</text>`;
  state.cells.forEach((c,i)=>{
    const x=g.x(c.lon),y=g.y(c.lat+genomeData.cellDegrees),w=g.x(c.lon+genomeData.cellDegrees)-x,h=g.y(c.lat)-y,approx=c.rows.filter(r=>r.coordinate_approximate).length;
    const title=`Cell ${i+1}: ${c.lon} to ${c.lon+2}° longitude, ${c.lat} to ${c.lat+2}° latitude. ${c.rows.length} accessions; ${yearCountLabel(c.rows)}; ${approx} approximate.`;
    svg+=`<g class="sample-cell" data-cell="${esc(c.key)}" data-count="${c.rows.length}" tabindex="0" role="button" aria-label="${esc(title)}"><title>${esc(title)}</title><rect x="${x}" y="${y}" width="${w}" height="${h}" fill="${color(c.rows.length,state.maximum)}" stroke="#674b42" stroke-width=".8"/>`;
    if(approx)svg+=`<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="url(#${hatch})"/>`;
    if($('extent').value==='atlas')svg+=`<text class="cell-number" x="${x+w/2}" y="${y+h/2+4}" text-anchor="middle" font-size="13" font-weight="bold" paint-order="stroke" stroke="white" stroke-width="3" fill="#233342">${i+1}</text>`;
    svg+='</g>';
  });
  svg+='</g>';
  for(let lon=Math.ceil(g.b.west/step)*step;lon<=g.b.east;lon+=step)svg+=`<text x="${g.x(lon)}" y="${g.bottom+24}" text-anchor="middle" font-size="14">${Math.abs(lon)}°${lon<0?'W':lon>0?'E':''}</text>`;
  for(let lat=Math.ceil(g.b.south/step)*step;lat<=g.b.north;lat+=step)svg+=`<text x="48" y="${g.y(lat)+5}" text-anchor="end" font-size="14">${Math.abs(lat)}°${lat<0?'S':lat>0?'N':''}</text>`;
  if(!frame.length)svg+=`<text x="450" y="${g.top+g.height/2}" text-anchor="middle" font-size="22">No plotted records for this selection</text>`;
  svg+=`<text x="60" y="${g.bottom+50}" font-size="14">2° cells · BioSample accessions · Hatching: approximate positions · Not population abundance</text>`;
  svg+=`<text x="60" y="${g.bottom+79}" font-size="14">Log color scale:</text>`;
  Array.from(new Set([1,Math.round(Math.sqrt(state.maximum)),state.maximum])).forEach((n,i)=>{svg+=`<rect x="${175+i*160}" y="${g.bottom+66}" width="38" height="16" fill="${color(n,state.maximum)}" stroke="#674b42"/><text x="${223+i*160}" y="${g.bottom+79}" font-size="14">${number(n)}</text>`;});
  svg+='</svg>';
  a.querySelector('.map-host').innerHTML=svg;
  a.querySelector('.year-label').textContent=yearText(state.year);
  a.querySelector('.frame-summary').textContent=`${number(frame.length)} plotted accessions in ${state.cells.length} cells for ${yearText(state.year).toLowerCase()}; ${number(frame.filter(r=>r.coordinate_approximate).length)} with approximate positions.`;
  a.querySelector('.legend').innerHTML='Accessions per cell (log color): '+Array.from(new Set([1,Math.round(Math.sqrt(state.maximum)),state.maximum])).map(n=>`<span class="swatch" style="background:${color(n,state.maximum)}"></span>${number(n)}`).join('');
  for(const el of a.querySelectorAll('.sample-cell')){
    const choose=()=>showCell(state,el.dataset.cell);
    el.addEventListener('click',choose);el.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();choose();}});
  }
  a.querySelector('.grid-records').innerHTML='<table><thead><tr><th>Cell</th><th>Longitude / latitude bounds</th><th>Year (accessions)</th><th>Total</th><th>Approximate</th></tr></thead><tbody>'+state.cells.map((c,i)=>`<tr><td><button type="button" data-cell="${esc(c.key)}">${i+1}</button></td><td>${c.lon} to ${c.lon+2}°; ${c.lat} to ${c.lat+2}°</td><td>${yearCountLabel(c.rows)}</td><td>${c.rows.length}</td><td>${c.rows.filter(r=>r.coordinate_approximate).length}</td></tr>`).join('')+'</tbody></table>';
  a.querySelectorAll('.grid-records button').forEach(b=>b.addEventListener('click',()=>showCell(state,b.dataset.cell)));
  if(state.selectedCell)showCell(state,state.selectedCell,false);
  drawTimeline(state);
}
function drawTimeline(state){
  const rows=state.plotted.filter(r=>r.year!==null),counts=yearCounts(rows),a=state.article;
  if(!counts.length){a.querySelector('.timeline-host').textContent='No dated plotted records.';return;}
  const min=Number(counts[0][0]),max=Number(counts[counts.length-1][0]),highest=Math.max(...counts.map(x=>x[1])),left=65,width=770,top=35,height=130;
  const x=y=>left+(Number(y)-min+.5)/(max-min+1)*width,bw=Math.max(1,Math.min(34,width/(max-min+1)*.8));
  let svg=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 220" role="img" aria-label="Plotted WGS accessions by collection year"><text x="65" y="20" font-size="15">Plotted BioSample accessions by collection year</text>`;
  for(const tick of [0,highest])svg+=`<text x="55" y="${top+height-tick/highest*height+5}" text-anchor="end" font-size="13">${tick}</text>`;
  for(const [year,count] of counts){const h=count/highest*height;svg+=`<rect class="timeline-bar" data-year="${year}" data-count="${count}" data-max="${highest}" data-plot-height="${height}" tabindex="0" role="button" aria-label="${year}: ${count} accessions" x="${x(year)-bw/2}" y="${top+height-h}" width="${bw}" height="${h}" fill="${state.year===year?'#bd372d':state.year==='all'?'#286c8d':'#b3c0c7'}"><title>${year}: ${count} accessions</title></rect>`;}
  const ticks=Array.from(new Set([min,...counts.filter((_,i)=>i%Math.max(1,Math.ceil(counts.length/8))===0).map(x=>Number(x[0])),max]));
  for(const year of ticks)svg+=`<text x="${x(year)}" y="190" font-size="13" text-anchor="middle">${year}</text>`;
  svg+='</svg>';a.querySelector('.timeline-host').innerHTML=svg;
  a.querySelectorAll('.timeline-bar').forEach(bar=>{const go=()=>{stop(state);selectYear(state,bar.dataset.year);};bar.addEventListener('click',go);bar.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();go();}});});
}
function sourceLinks(r){return (r.location_source_ids||'').split(' | ').filter(Boolean).map(id=>{
  const src=sourceRegistry.get(id),url=id==='archive'?'https://www.ebi.ac.uk/ena/browser/view/'+encodeURIComponent(r.sample_accession):src?.landing_url;
  return url?`<a href="${esc(url)}" target="_blank" rel="noopener noreferrer">${esc(id==='archive'?'Archive record':src.publication_doi||id)}</a>`:esc(id);
}).join(' · ');}
function showCell(state,key,open=true){
  state.selectedCell=key;const c=state.cells.find(c=>c.key===key),box=state.article.querySelector('.cell-details'),host=box.querySelector('.cell-records');
  if(!c){host.textContent='This cell has no records in the current frame.';return;}
  box.querySelector('summary').textContent=`Cell ${state.cells.indexOf(c)+1}: ${c.rows.length} accessions · ${yearCountLabel(c.rows)}`;
  if(open)box.open=true;
  let limit=100;
  const render=()=>{
    host.innerHTML='<table><thead><tr><th>BioSample / study</th><th>Year / stage</th><th>Location / precision</th><th>Sources, provenance and review flags</th></tr></thead><tbody>'+c.rows.slice(0,limit).map(r=>
      `<tr><td><a href="https://www.ebi.ac.uk/ena/browser/view/${encodeURIComponent(r.sample_accession)}" target="_blank" rel="noopener noreferrer">${esc(r.sample_accession)}</a><br>${esc(r.studies)}</td><td>${yearText(yearKey(r))}<br>${esc(r.life_stage)}</td><td>${esc(r.locality_raw||'Locality text not reported')}<br>${r.latitude}, ${r.longitude}<br>${esc(r.coordinate_scope||'Scope unspecified')}</td><td>${sourceLinks(r)}<br><a href="location_provenance.csv">Location evidence</a>: ${esc(r.location_evidence_ids||'Not assigned')}<br>Date evidence: ${esc(r.date_evidence_ids||'Not assigned')}<br>${esc(r.review_reason)}</td></tr>`).join('')+'</tbody></table>';
    if(c.rows.length>limit){const b=document.createElement('button');b.type='button';b.textContent=`Show next ${Math.min(100,c.rows.length-limit)} (${limit} of ${c.rows.length} shown)`;b.onclick=()=>{limit+=100;render();};host.appendChild(b);}
  };render();
}
function selectYear(state,year){state.year=year;state.article.querySelector('.year-select').value=year;drawMap(state);}
function configureState(state){
  stop(state);state.selected=selectedRecords(state);state.plotted=state.selected.filter(r=>inBounds(r,extent()));
  state.years=yearCounts(state.plotted).map(x=>x[0]);
  if(state.year!=='all'&&!state.years.includes(state.year))state.year='all';
  const select=state.article.querySelector('.year-select');select.innerHTML='<option value="all">All years</option>'+yearCounts(state.plotted).map(([y,n])=>`<option value="${y}">${yearText(y)} — ${number(n)} accessions</option>`).join('');select.value=state.year;
  state.article.querySelector('.play').disabled=state.years.filter(y=>y!=='undated').length<2;
  state.article.querySelector('.record-summary').textContent=`${number(state.selected.length)} WGS accessions meet the record filters: ${number(state.plotted.length)} in this extent, ${number(state.selected.filter(r=>hasCoordinates(r)&&!inBounds(r,extent())).length)} outside it, ${number(state.selected.filter(r=>!hasCoordinates(r)).length)} without usable coordinates. ${number(state.selected.filter(r=>r.year===null).length)} lack a collection year.`;
}
function applyMapFilters(){
  const criteria=traitCriteria();
  const q=$('search').value.trim().toLowerCase(),order=$('taxonomy-order').value,family=$('taxonomy-family').value;
  const invalid=$('year-min').value!==''&&$('year-max').value!==''&&Number($('year-min').value)>Number($('year-max').value);$('filter-error').hidden=!invalid;
  let visible=0,total=0;
  for(const state of states){
    configureState(state);const a=state.article;
    a.hidden=invalid||!a.dataset.search.includes(q)||(order&&(order==='__missing__'?!!a.dataset.order:a.dataset.order!==order))||(family&&(family==='__missing__'?!!a.dataset.family:a.dataset.family!==family))||!matchesGenomics(a)||!matchesTraits(state.traits,criteria)||($('plotted-only').checked&&!state.plotted.length);
    if(!a.hidden){visible++;total+=state.plotted.length;drawMap(state);}
  }
  $('result-count').textContent=`${visible} of ${states.length} species shown · ${number(total)} plotted WGS BioSample accessions across all selected years`;
  $('no-results').hidden=visible!==0;
}
for(const state of states){
  const a=state.article;
  a.querySelector('.year-select').addEventListener('change',e=>{stop(state);selectYear(state,e.target.value);});
  for(const [selector,direction] of [['.previous',-1],['.next',1]])a.querySelector(selector).onclick=()=>{stop(state);const options=['all',...state.years],i=options.indexOf(state.year);selectYear(state,options[(i+direction+options.length)%options.length]);};
  a.querySelector('.play').onclick=()=>{
    if(state.timer){stop(state);return;}
    states.forEach(other=>{if(other!==state)stop(other);});
    const years=state.years.filter(y=>y!=='undated');if(years.length<2)return;
    let i=years.indexOf(state.year);if(i<0)i=0;selectYear(state,years[i]);a.querySelector('.play').textContent='Pause';
    state.timer=setInterval(()=>{i=(i+1)%years.length;selectYear(state,years[i]);},1000);
  };
  a.querySelector('.download-map').onclick=()=>{
    const original=a.querySelector('.map-host svg'),copy=original.cloneNode(true),ns='http://www.w3.org/2000/svg';
    // Embed labels/legend in the exported SVG as well as the browser display.
    const style=document.createElementNS(ns,'style');style.textContent='text{font-family:Arial,sans-serif;fill:#233342}.cell-number{paint-order:stroke;stroke:white;stroke-width:3px;stroke-linejoin:round}';copy.prepend(style);
    const url=URL.createObjectURL(new Blob([new XMLSerializer().serializeToString(copy)],{type:'image/svg+xml'})),link=document.createElement('a');
    link.href=url;link.download=a.id+'_'+state.year+'_genomics.svg';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  };
}
const form=$('filters');form.addEventListener('input',applyMapFilters);form.addEventListener('submit',e=>e.preventDefault());form.addEventListener('reset',()=>setTimeout(()=>{states.forEach(s=>{s.year='all';s.selectedCell=null;});applyMapFilters();},0));
document.addEventListener('visibilitychange',()=>{if(document.hidden)states.forEach(stop);});
document.querySelectorAll('.species-photo').forEach(img=>{const fail=()=>{img.hidden=true;img.closest('figure').querySelector('.image-error').hidden=false;};img.addEventListener('error',fail);if(img.complete&&!img.naturalWidth)fail();});
function revealSpecies(){const id=decodeURIComponent(location.hash.slice(1)),state=states.find(s=>s.article.id===id);if(state){$('search').value=state.article.dataset.species;$('plotted-only').checked=false;applyMapFilters();state.article.scrollIntoView();}}
applyMapFilters();revealSpecies();window.addEventListener('hashchange',revealSpecies);

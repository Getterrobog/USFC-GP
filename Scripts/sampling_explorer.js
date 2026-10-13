'use strict';
const explorer=JSON.parse(document.getElementById('explorer-data').textContent);
const $=id=>document.getElementById(id),esc=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const labels={all:'All life stages',adult:'Adult / non-larval',larva:'Larvae',mixed:'Mixed lots'};
const candidates=Array.from(document.querySelectorAll('.species-template'),template=>({template,species:template.dataset.species,label:template.dataset.label,traits:traitCandidate(template.content),records:explorer.filters.filter(r=>r.species===template.dataset.species)}));
let eligible=[],suggestions=[],selected=null,active=-1;
const input=$('species-search'),list=$('species-options'),background=$('map-background').content.querySelector('svg').innerHTML;
function closeOptions(restore=true){list.hidden=true;input.setAttribute('aria-expanded','false');$('species-toggle').setAttribute('aria-expanded','false');input.removeAttribute('aria-activedescendant');active=-1;if(restore)input.value=selected?.label||'';}
function setActive(index){active=index;if(index<0){input.removeAttribute('aria-activedescendant');return;}Array.from(list.children).forEach((el,i)=>el.classList.toggle('active',i===index));const el=list.children[index];input.setAttribute('aria-activedescendant',el.id);el.scrollIntoView({block:'nearest'});}
function showOptions(query=''){
  suggestions=eligible.filter(c=>c.label.toLowerCase().includes(query.trim().toLowerCase()));
  list.replaceChildren();active=-1;input.removeAttribute('aria-activedescendant');
  suggestions.forEach((c,i)=>{const li=document.createElement('li');li.id='species-option-'+i;li.role='option';li.setAttribute('aria-selected',String(c===selected));li.textContent=c.label;li.addEventListener('mousedown',e=>e.preventDefault());li.addEventListener('click',()=>{choose(c);closeOptions();input.focus();closeOptions();});list.appendChild(li);});
  list.hidden=!suggestions.length;input.setAttribute('aria-expanded',String(suggestions.length>0));$('species-toggle').setAttribute('aria-expanded',String(suggestions.length>0));
  $('search-status').textContent=suggestions.length?`${suggestions.length} matching selectable species. Use ↑/↓ and Enter, or click a name.`:'No selectable species match this search.';
}
input.addEventListener('focus',()=>{input.select();showOptions();});
input.addEventListener('input',()=>showOptions(input.value));
input.addEventListener('keydown',e=>{
  if(e.key==='ArrowDown'||e.key==='ArrowUp'){e.preventDefault();if(list.hidden)showOptions(input.value===selected?.label?'':input.value);if(suggestions.length)setActive((active+(e.key==='ArrowDown'?1:active<0?0:-1)+suggestions.length)%suggestions.length);}
  else if(e.key==='Enter'){e.preventDefault();const choice=active>=0?suggestions[active]:suggestions.length===1?suggestions[0]:eligible.find(c=>c.label.toLowerCase()===input.value.toLowerCase()||c.species.toLowerCase()===input.value.toLowerCase());if(choice){choose(choice);closeOptions();}}
  else if(e.key==='Escape'){e.preventDefault();closeOptions();}
});
input.addEventListener('blur',()=>setTimeout(()=>{if(!document.activeElement?.closest('.species-picker'))closeOptions();},0));
$('species-toggle').addEventListener('click',()=>{if(list.hidden){input.focus();showOptions();}else closeOptions();});
document.addEventListener('click',e=>{if(!e.target.closest('.species-picker'))closeOptions();});
function filterSpecies(){
  const previous=selected,criteria=traitCriteria(),region=$('region').value,mapped=$('mapped-only').checked;
  const minimum=Math.max(0,Number($('min-specimens').value)||0),yearsMinimum=Math.max(1,Number($('min-years').value)||1);
  const ranks=['order','family'].map(field=>({field,value:$('taxonomy-'+field).value}));
  eligible=candidates.filter(c=>{
    const years=new Set();let count=0;
    c.records.filter(r=>!region||r.region===region).forEach(r=>{count+=mapped?r.mapped_specimens:r.specimens;String(mapped?r.mapped_years:r.years).split(',').filter(Boolean).forEach(y=>years.add(y));});
    return count>0&&count>=minimum&&years.size>=yearsMinimum&&ranks.every(r=>!r.value||(r.value==='__missing__'?!c.template.dataset[r.field]:c.template.dataset[r.field]===r.value))&&matchesTraits(c.traits,criteria)&&matchesGenomics(c.template.content);
  });
  $('filter-count').textContent=`(${eligible.length} of ${candidates.length} species)`;
  input.disabled=$('species-toggle').disabled=$('map-stage').disabled=eligible.length===0;
  $('empty-results').hidden=eligible.length>0;
  choose(eligible.includes(previous)?previous:eligible[0]||null);
  closeOptions();
  $('search-status').textContent=`${eligible.length} species available after filtering.`;
  if(previous&&selected&&previous!==selected)$('selection-status').textContent=`${previous.species} no longer matches. Now showing ${selected.species}.`;
}
function choose(c){
  selected=c;input.value=c?.label||'';$('selected-view').hidden=!c;
  if(!c){$('map-host').replaceChildren();$('species-heading').replaceChildren();$('species-details').replaceChildren();$('selection-status').textContent='No selected species.';return;}
  $('species-heading').replaceChildren(c.template.content.querySelector('.identity').cloneNode(true));
  $('species-details').replaceChildren(c.template.content.querySelector('.species-information').cloneNode(true));
  document.querySelectorAll('#species-heading .species-photo').forEach(img=>{const fail=()=>{img.hidden=true;img.closest('figure').querySelector('.image-error').hidden=false;};img.addEventListener('error',fail);if(img.complete&&!img.naturalWidth)fail();});
  for(const option of $('map-stage').options){const total=explorer.summary.find(s=>s.species===c.species&&s.map_stage===option.value);option.textContent=`${labels[option.value]} — ${total.specimens.toLocaleString()} specimens`;}
  renderMap();
}
function wrapLabel(label,width=36){let current='',lines=[];for(const part of label.split(', ')){const next=current?current+', '+part:part;if(current&&next.length>width){lines.push(current+',');current=part;}else current=next;}lines.push(current);return lines;}
function labelPositions(desired,heights,top,bottom,gap=7){
  if(!desired.length)return [];
  if(heights.reduce((a,b)=>a+b,0)+gap*(heights.length-1)>bottom-top)throw Error('Collection-year labels exceed the fixed map canvas.');
  const y=desired.map((v,i)=>v-heights[i]/2);y[0]=Math.max(top,y[0]);for(let i=1;i<y.length;i++)y[i]=Math.max(y[i],y[i-1]+heights[i-1]+gap);y[y.length-1]=Math.min(y.at(-1),bottom-heights.at(-1));for(let i=y.length-2;i>=0;i--)y[i]=Math.min(y[i],y[i+1]-heights[i]-gap);return y;
}
function yearLabel(c){const years=c.years?String(c.years).split(';'):[],counts=c.year_specimens?String(c.year_specimens).split(';'):[];const parts=years.map((y,i)=>`${y} (${counts[i]})`);if(c.undated_specimens)parts.push(`Undated (${c.undated_specimens})`);return parts.join(', ');}
$('map-stage').addEventListener('change',renderMap);
$('filters').addEventListener('input',filterSpecies);$('filters').addEventListener('change',filterSpecies);$('filters').addEventListener('submit',e=>e.preventDefault());$('filters').addEventListener('reset',()=>setTimeout(filterSpecies,0));
$('enlarge-map').onclick=()=>{const box=document.querySelector('.map-viewport'),on=box.classList.toggle('enlarged');$('enlarge-map').setAttribute('aria-pressed',String(on));$('enlarge-map').textContent=on?'Fit map to page':'Enlarge labels';};
$('download-map').onclick=()=>{const svg=$('map-host').querySelector('svg');if(!svg)return;const url=URL.createObjectURL(new Blob([new XMLSerializer().serializeToString(svg)],{type:'image/svg+xml'}));const a=document.createElement('a');a.href=url;a.download=selected.template.id+'_'+$('map-stage').value+'_all_years.svg';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
const initialHash=decodeURIComponent(location.hash.slice(1)).split('/');
filterSpecies();const initial=candidates.find(c=>c.template.id===initialHash[0]);if(initial&&eligible.includes(initial)){if(Object.hasOwn(labels,initialHash[1]))$('map-stage').value=initialHash[1];choose(initial);}

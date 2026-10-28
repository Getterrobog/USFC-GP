// Shared species-level controls for the historical atlas and genomic maps.
function matchesGenomics(article) {
  const d=article.querySelector('.genomic-stats').dataset;
  const choice=document.getElementById('genomics-availability').value;
  const known=d.known==='TRUE';
  if(choice==='unknown' && known)return false;
  if(choice && choice!=='unknown' && !known)return false;
  if(choice==='none' && Number(d.wgs)!==0)return false;
  if(['wgs','contemporary'].includes(choice) && Number(d[choice])<=0)return false;
  if(choice==='mapped' && Number(d.candidates)<=0)return false;
  const ref=document.getElementById('genomics-reference').value;
  if(ref && (!known || Number(d[ref])<=0))return false;
  for(const key of ['wgs','contemporary','candidates']) {
    const min=Math.max(0,Number(document.getElementById('genomics-min-'+key).value)||0);
    if(min>0 && (!known || Number(d[key])<min))return false;
  }
  if(document.getElementById('genomics-low').checked && (!known || Number(d.low)<=0))return false;
  return true;
}

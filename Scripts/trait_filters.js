// Shared trait controls for all geographic viewers.
function traitCandidate(article){return {traits:Object.fromEntries(Array.from(article.querySelectorAll(".trait-value"),node=>[node.dataset.trait,node.dataset])),lengths:Array.from(article.querySelectorAll(".trait-length"),node=>({type:node.dataset.type,value:Number(node.dataset.value)}))};}
function traitCriteria(){
  const categories=Array.from(document.querySelectorAll(".trait-category")).filter(input=>input.value).map(input=>({field:input.dataset.trait,value:input.value}));
  const ranges=Array.from(document.querySelectorAll(".trait-range")).map(box=>{
    const availability=box.querySelector(".trait-availability").value, min=box.querySelector(".trait-min"),max=box.querySelector(".trait-max");
    min.disabled=max.disabled=availability==="missing";
    return {field:box.dataset.trait,availability,min:availability==="missing"||min.value===""?null:Number(min.value),max:availability==="missing"||max.value===""?null:Number(max.value),type:box.dataset.trait==="maximum_length"?document.getElementById("length-type").value:""};
  }).filter(r=>r.availability||r.min!==null||r.max!==null||r.type);
  const invalid=ranges.some(r=>r.min!==null&&r.max!==null&&r.min>r.max);
  document.getElementById("trait-range-error").hidden=!invalid;
  document.getElementById("trait-filter-count").textContent=categories.length+ranges.length?"("+(categories.length+ranges.length)+" active)":"";
  return {categories,ranges,invalid};
}
function matchesTraits(candidate,criteria){
  if(criteria.invalid)return false;
  if(!criteria.categories.every(c=>{
    const values=(candidate.traits[c.field]?.values||"").split(";").filter(Boolean);
    return c.value==="__missing__"?values.length===0:values.includes(c.value);
  }))return false;
  return criteria.ranges.every(r=>{
    let values;
    if(r.field==="maximum_length")values=candidate.lengths.filter(x=>!r.type||x.type===r.type).map(x=>x.value);
    else {const value=candidate.traits[r.field]?.value;values=value===undefined||value===""?[]:[Number(value)];}
    if(r.availability==="missing")return values.length===0;
    // Ignore floating-point serialization noise at inclusive numeric boundaries.
    return values.some(v=>{const epsilon=1e-7*Math.max(1,Math.abs(v));return (r.min===null||v>=r.min-epsilon)&&(r.max===null||v<=r.max+epsilon);});
  });
}

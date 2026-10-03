/* نبضة "متصل الآن": تسجّل آخر ظهور للعميل المسجّل كل دقيقة ليراه المشرف في لوحة التحكم */
(function(){
  var sb = window.TawassulSupabase && window.TawassulSupabase.client;
  if(!sb || !sb.auth || !sb.rpc) return;
  var busy = false;
  async function beat(){
    if(busy || document.visibilityState !== 'visible') return;
    busy = true;
    try{
      var r = await sb.auth.getSession();
      if(r && r.data && r.data.session) await sb.rpc('touch_last_seen');
    }catch(e){}
    busy = false;
  }
  beat();
  setInterval(beat, 60000);
  document.addEventListener('visibilitychange', beat);
  try{ sb.auth.onAuthStateChange(function(ev){ if(ev === 'SIGNED_IN') setTimeout(beat, 500); }); }catch(e){}
})();

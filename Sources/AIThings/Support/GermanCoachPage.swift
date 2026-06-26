import Foundation

/// The gamified "Workplace German" coach page (self-contained HTML/JS, opened
/// in the browser). Design follows the deep-research findings:
/// - XP scaled by exercise difficulty + recall (not raw activity)
/// - forgiving daily streak (no harsh loss)
/// - Leitner spaced repetition persisted in localStorage
/// - auto-generated cloze / listen / type exercises, interleaved
/// - German text-to-speech via the Web Speech API
extension GermanCoach {
    private struct PageItem: Codable { let c: String; let d: String; let e: String }

    static var coachHTML: String {
        let items = lessons.map { PageItem(c: $0.category, d: $0.de, e: $0.en) }
        let json = (try? JSONEncoder().encode(items)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Workplace German — AI-Things</title>
        <style>
          :root{color-scheme:dark}
          *{box-sizing:border-box}
          body{font:16px/1.55 -apple-system,system-ui,sans-serif;background:#0b1620;color:#e9f0f7;margin:0;padding:28px 20px 60px;max-width:880px;margin-inline:auto}
          header{display:flex;align-items:center;gap:12px}
          .mark{width:38px;height:38px;border:3px solid #6bb0f0;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#6bb0f0;font-size:12px}
          h1{margin:0;font-weight:800;font-size:22px}
          .hud{display:flex;gap:10px;align-items:center;flex-wrap:wrap;margin:14px 0 6px}
          .pill{background:#111e2b;border:1px solid rgba(255,255,255,.1);border-radius:999px;padding:6px 12px;font-size:13px;font-weight:700}
          .pill .muted{color:#8597a9;font-weight:400}
          .xpbar{flex:1;min-width:160px;height:10px;background:#111e2b;border-radius:999px;overflow:hidden;border:1px solid rgba(255,255,255,.1)}
          .xpfill{height:100%;background:linear-gradient(90deg,#2563a0,#6bb0f0);width:0%}
          .tabs{display:flex;gap:8px;flex-wrap:wrap;margin:16px 0}
          .tab{padding:7px 14px;border-radius:999px;border:1px solid rgba(255,255,255,.12);background:#111e2b;color:#cfe0f2;cursor:pointer;font-size:14px}
          .tab.active{background:#2563a0;border-color:#2563a0;color:#fff;font-weight:700}
          select,input{background:#111e2b;color:#e9f0f7;border:1px solid rgba(255,255,255,.15);border-radius:8px;padding:9px 11px;font:inherit;width:100%}
          .btn{background:#2563a0;color:#fff;border:none;border-radius:10px;padding:11px 18px;cursor:pointer;font-weight:700;font:inherit}
          .btn.alt{background:#16273a;color:#cfe0f2}
          .card{background:#111e2b;border:1px solid rgba(255,255,255,.1);border-radius:16px;padding:26px;text-align:center;position:relative;overflow:hidden}
          .prompt{font-size:15px;color:#9fb2c6}
          .big{font-size:26px;font-weight:800;margin:12px 0;min-height:34px}
          .opt{display:block;width:100%;text-align:left;background:#0d1925;border:1px solid rgba(255,255,255,.12);color:#e9f0f7;border-radius:12px;padding:13px 15px;margin:9px 0;cursor:pointer;transition:.12s}
          .opt:hover{border-color:#6bb0f0}
          .opt.correct{background:#1f5135;border-color:#3aa564}.opt.wrong{background:#5a2330;border-color:#c0556a}
          .row{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:14px 0}
          .muted{color:#8597a9}.good{color:#5fcf86}.bad{color:#e88}
          .cat{margin:20px 0 4px;color:#6bb0f0;font-weight:700}
          table{width:100%;border-collapse:collapse}td{padding:9px 12px;border-bottom:1px solid rgba(255,255,255,.07);vertical-align:top}
          td.de{font-weight:600;width:48%}td.en{color:#9fb2c6}
          a.card2{display:block;text-decoration:none;background:#111e2b;border:1px solid rgba(255,255,255,.08);border-radius:12px;padding:13px 15px;color:#e9f0f7}
          a.card2:hover{border-color:#6bb0f0}a.card2 span{display:block;color:#8597a9;font-size:13px;margin-top:3px}
          .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:12px}
          h2{color:#6bb0f0;margin-top:22px}
          .burst{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:60px;pointer-events:none;opacity:0}
          .pop{animation:pop .7s ease-out}
          @keyframes pop{0%{opacity:0;transform:scale(.4)}30%{opacity:1;transform:scale(1.1)}100%{opacity:0;transform:scale(1.4) translateY(-20px)}}
          .iconbtn{background:#16273a;border:1px solid rgba(255,255,255,.12);color:#cfe0f2;border-radius:8px;padding:8px 12px;cursor:pointer;font-size:18px}
          .combo{position:absolute;top:10px;right:14px;font-weight:800;color:#f2b04a}
        </style></head><body>
          <header><div class="mark">AI</div><h1>Workplace German</h1></header>

          <div class="hud">
            <span class="pill">Lvl <span id="hudLevel">1</span></span>
            <div class="xpbar"><div class="xpfill" id="hudXp"></div></div>
            <span class="pill"><span class="muted">XP</span> <span id="hudXpNum">0</span></span>
            <span class="pill">🔥 <span id="hudStreak">0</span></span>
            <span class="pill"><span class="muted">Due</span> <span id="hudDue">0</span></span>
          </div>

          <div class="tabs">
            <div class="tab active" data-t="practice">⚡ Practice</div>
            <div class="tab" data-t="review">🧠 Review</div>
            <div class="tab" data-t="learn">🃏 Learn</div>
            <div class="tab" data-t="phrases">📋 Phrases</div>
            <div class="tab" data-t="resources">🔗 Resources</div>
          </div>

          <div id="voiceWarn" style="display:none;background:#3a2e12;border:1px solid #6b5320;border-radius:10px;padding:10px 14px;margin:0 0 14px;color:#f2b04a;font-size:13px">
            ⚠︎ No German voice is installed, so audio uses English pronunciation.
            Install one: <b>System Settings → Accessibility → Spoken Content → System Voice → Manage Voices…</b> and download a German (Deutsch) voice, then reopen this page.
          </div>

          <section id="practice">
            <div class="row">
              <select id="scenario" style="max-width:260px"></select>
              <button class="btn" id="startBtn">Start 12-question round →</button>
            </div>
            <p class="muted">Interleaved mix of multiple-choice, fill-in-the-blank, listening, and typing. Harder answers earn more XP; due cards earn a recall bonus.</p>
            <div id="arena"></div>
          </section>

          <section id="review" hidden>
            <p class="muted">Spaced-repetition review — only the cards that are due today (Leitner system).</p>
            <button class="btn" id="reviewBtn">Start review →</button>
            <div id="arenaR"></div>
          </section>

          <section id="learn" hidden>
            <div class="row"><select id="learnCat" style="max-width:260px"></select></div>
            <div class="card">
              <button class="iconbtn" id="speak" style="position:absolute;top:10px;left:14px">🔊</button>
              <div class="prompt" id="lEn">—</div>
              <div class="big" id="lDe"></div>
              <div class="muted" id="lCat"></div>
            </div>
            <div class="row"><button class="btn" id="lReveal">Show German</button><button class="btn alt" id="lNext">Next →</button></div>
          </section>

          <section id="phrases" hidden>
            <div class="row"><select id="catFilter" style="max-width:260px"></select></div>
            <div id="phraseList"></div>
          </section>

          <section id="resources" hidden>
            <h2>Deutsche Welle (free)</h2>
            <div class="grid">
              <a class="card2" href="https://learngerman.dw.com/en/overview">DW Learn German<span>A1–C1 courses</span></a>
              <a class="card2" href="https://learngerman.dw.com/en/nicos-weg/c-36519789">Nicos Weg<span>Story-based A1→B1</span></a>
              <a class="card2" href="https://www.dw.com/de/deutsch-lernen/nachrichten/s-8030">Langsam gesprochene Nachrichten<span>Slow news + transcripts</span></a>
            </div>
            <h2>Workplace German (Berufsdeutsch)</h2>
            <div class="grid">
              <a class="card2" href="https://www.goethe.de/de/spr/ueb/daz.html">Goethe: Deutsch am Arbeitsplatz<span>Free workplace course</span></a>
              <a class="card2" href="https://www.goethe.de/en/spr/ueb.html">Goethe practice<span>Free exercises</span></a>
              <a class="card2" href="https://www.deutschakademie.de/online-deutschkurs/">DeutschAkademie<span>20,000+ grammar drills</span></a>
            </div>
            <h2>Listening & dictionaries</h2>
            <div class="grid">
              <a class="card2" href="https://www.youtube.com/@EasyGerman">Easy German<span>Street interviews</span></a>
              <a class="card2" href="https://context.reverso.net/translation/german-english/">Reverso Context<span>Words in real sentences</span></a>
              <a class="card2" href="https://dict.leo.org/german-english/">LEO<span>Dictionary + forum</span></a>
            </div>
          </section>

        <script>
        const DATA = \(json).map((x,i)=>({i,c:x.c,d:x.d,e:x.e}));
        const cats=[...new Set(DATA.map(x=>x.c))];
        const $=id=>document.getElementById(id);
        const rand=n=>Math.floor(Math.random()*n);
        const shuffle=a=>{for(let i=a.length-1;i>0;i--){const j=rand(i+1);[a[i],a[j]]=[a[j],a[i]];}return a;};
        const DAY=86400000;

        // ---- State (localStorage) ----
        const KEY='aithings_de_v2';
        let S=load();
        function load(){try{return JSON.parse(localStorage.getItem(KEY))||{}}catch(e){return {}}}
        function save(){try{localStorage.setItem(KEY,JSON.stringify(S))}catch(e){}}
        S.xp=S.xp||0; S.streak=S.streak||0; S.lastDay=S.lastDay||''; S.box=S.box||{}; S.due=S.due||{};

        function todayStr(){const d=new Date();return d.getFullYear()+'-'+(d.getMonth()+1)+'-'+d.getDate();}
        function levelFor(xp){return Math.floor(Math.sqrt(xp/40))+1;}
        function xpForLevel(l){return 40*(l-1)*(l-1);}
        function dueCount(){const now=Date.now();return DATA.filter(x=>(S.due[x.i]||0)<=now).length;}
        function dueItems(){const now=Date.now();return DATA.filter(x=>(S.due[x.i]||0)<=now);}

        function schedule(idx,correct){
          const ints=[0,1,3,7,16]; // Leitner intervals (days) for boxes 1..5
          let b=S.box[idx]||1;
          b=correct?Math.min(b+1,5):1;
          S.box[idx]=b;
          S.due[idx]=Date.now()+ints[b-1]*DAY;
        }
        function award(base,correct,wasDue){
          if(!correct)return 0;
          let gain=base+(wasDue?5:0);
          S.xp+=gain; save(); renderHud();
          return gain;
        }
        function bumpStreak(){
          const t=todayStr();
          if(S.lastDay===t)return;
          // forgiving: consecutive day increments; a gap just restarts at 1 (no penalty messaging)
          const y=new Date(Date.now()-DAY); const ys=y.getFullYear()+'-'+(y.getMonth()+1)+'-'+y.getDate();
          S.streak=(S.lastDay===ys)?S.streak+1:1;
          S.lastDay=t; save(); renderHud();
        }
        function renderHud(){
          const lvl=levelFor(S.xp), cur=xpForLevel(lvl), next=xpForLevel(lvl+1);
          $('hudLevel').textContent=lvl; $('hudXpNum').textContent=S.xp; $('hudStreak').textContent=S.streak;
          $('hudXp').style.width=Math.min(100,((S.xp-cur)/(next-cur))*100)+'%';
          $('hudDue').textContent=dueCount();
        }

        // ---- Audio + speech ----
        let actx;
        function beep(ok){try{actx=actx||new (window.AudioContext||window.webkitAudioContext)();const o=actx.createOscillator(),g=actx.createGain();o.connect(g);g.connect(actx.destination);o.type='sine';o.frequency.value=ok?660:160;g.gain.value=0.05;o.start();o.stop(actx.currentTime+0.13);}catch(e){}}

        // German voice — getVoices() is empty until voices load, so cache it and
        // refresh on voiceschanged. Without a real de voice the browser would
        // read German with English pronunciation.
        let deVoice=null;
        function loadVoices(){
          try{
            const vs=speechSynthesis.getVoices()||[];
            deVoice=vs.find(v=>v.lang&&v.lang.toLowerCase().indexOf('de')===0)||null;
            const warn=document.getElementById('voiceWarn');
            if(warn) warn.style.display=(vs.length&&!deVoice)?'block':'none';
          }catch(e){}
        }
        if(typeof speechSynthesis!=='undefined'){ loadVoices(); speechSynthesis.onvoiceschanged=loadVoices; setTimeout(loadVoices,300); }
        function speak(text){
          try{
            if(!deVoice)loadVoices();
            const u=new SpeechSynthesisUtterance(text);
            u.lang='de-DE'; u.rate=0.92;
            if(deVoice)u.voice=deVoice;
            speechSynthesis.cancel();
            speechSynthesis.speak(u);
          }catch(e){}
        }

        function norm(s){
          s=(s||'').toLowerCase();
          const map={'ä':'a','ö':'o','ü':'u','ß':'ss'};
          s=s.replace(/[äöüß]/g,m=>map[m]);
          ['.',',','!','?',';',':','-',"'",'"'].forEach(ch=>{s=s.split(ch).join('');});
          return s.replace(/ +/g,' ').trim();
        }

        // ---- Exercise generators ----
        function otherEnglish(not,n){return shuffle(DATA.filter(x=>x.e!==not)).slice(0,n).map(x=>x.e);}
        function mcqDeEn(it){return {kind:'mcq',base:10,promptTop:'Choose the English',promptBig:it.d,speakText:it.d,options:shuffle([it.e,...otherEnglish(it.e,3)]),answer:it.e};}
        function mcqEnDe(it){const opts=shuffle([it.d,...shuffle(DATA.filter(x=>x.d!==it.d)).slice(0,3).map(x=>x.d)]);return {kind:'mcq',base:10,promptTop:'Choose the German',promptBig:it.e,options:opts,answer:it.d};}
        function listen(it){return {kind:'mcq',base:12,promptTop:'🔊 Listen, then choose the English',promptBig:'••• tap 🔊 •••',speakText:it.d,autospeak:true,options:shuffle([it.e,...otherEnglish(it.e,3)]),answer:it.e};}
        function cloze(it){
          const words=it.d.split(' ');
          const idxs=words.map((w,i)=>({w,i})).filter(o=>o.w.replace(/[.,!?;:]/g,'').length>3);
          if(idxs.length<1) return mcqDeEn(it);
          const pick=idxs[rand(idxs.length)];
          const target=pick.w.replace(/[.,!?;:]/g,'');
          const blanked=words.map((w,i)=>i===pick.i?'_____':w).join(' ');
          // distractors: content words of similar length from other German sentences
          const pool=[...new Set(DATA.filter(x=>x.i!==it.i).flatMap(x=>x.d.split(' ')).map(w=>w.replace(/[.,!?;:]/g,'')).filter(w=>w.length>3&&w.toLowerCase()!==target.toLowerCase()))];
          const distract=shuffle(pool).slice(0,3);
          return {kind:'mcq',base:15,promptTop:'Fill the blank — '+it.e,promptBig:blanked,options:shuffle([target,...distract]),answer:target};
        }
        function typeHeard(it){return {kind:'type',base:20,promptTop:'🔊 Type what you hear',promptBig:'••• tap 🔊 •••',speakText:it.d,autospeak:true,answer:it.d,hintEn:it.e};}

        function makeQuestion(it){
          const gens=[mcqDeEn,mcqEnDe,listen,cloze,typeHeard];
          const weights=[2,2,2,3,2];
          let r=rand(weights.reduce((a,b)=>a+b,0)),k=0; while(r>=weights[k]){r-=weights[k];k++;}
          const q=gens[k](it); q.item=it; return q;
        }

        // ---- Session engine ----
        function buildPool(scenario,count,onlyDue){
          let pool = onlyDue ? dueItems() : DATA.filter(x=>!scenario||x.c===scenario);
          if(onlyDue && scenario) pool=pool.filter(x=>x.c===scenario);
          if(pool.length===0) return [];
          // prioritize due items, then fill; interleave scenarios by shuffling
          const now=Date.now();
          const due=shuffle(pool.filter(x=>(S.due[x.i]||0)<=now));
          const rest=shuffle(pool.filter(x=>(S.due[x.i]||0)>now));
          return [...due,...rest].slice(0,count);
        }

        function runSession(mountId,pool){
          const mount=$(mountId);
          if(pool.length===0){mount.innerHTML='<div class="card"><div class="big">All caught up ✅</div><div class="muted">No cards due right now. Try a Practice round.</div></div>';return;}
          let qi=0,correct=0,combo=0,xpGain=0;
          function render(){
            if(qi>=pool.length){finish();return;}
            const q=makeQuestion(pool[qi]);
            const wasDue=(S.due[q.item.i]||0)<=Date.now();
            let html='<div class="card"><div class="combo">'+(combo>1?('🔥 x'+combo):'')+'</div>';
            html+='<div class="row" style="justify-content:space-between"><span class="muted">'+(qi+1)+' / '+pool.length+'</span><button class="iconbtn" id="say">🔊</button></div>';
            html+='<div class="prompt">'+q.promptTop+'</div><div class="big">'+q.promptBig+'</div>';
            if(q.kind==='mcq'){html+='<div id="opts"></div>';}
            else{html+='<input id="typed" placeholder="Type the German…" autocomplete="off"><div class="row"><button class="btn" id="check">Check</button><span class="muted">'+(q.hintEn||'')+'</span></div>';}
            html+='<div class="burst" id="burst"></div></div>';
            mount.innerHTML=html;
            const sayBtn=$('say'); if(sayBtn)sayBtn.onclick=()=>q.speakText&&speak(q.speakText);
            if(q.autospeak&&q.speakText)setTimeout(()=>speak(q.speakText),250);
            if(q.kind==='mcq'){
              const box=$('opts');
              q.options.forEach(o=>{const b=document.createElement('button');b.className='opt';b.textContent=o;b.onclick=()=>{
                if(b.dataset.done)return; document.querySelectorAll('#opts .opt').forEach(x=>x.dataset.done=1);
                const ok=(o===q.answer); mark(box,ok,q.answer); settle(q,ok,wasDue);
              };box.appendChild(b);});
            }else{
              const submit=()=>{const ok=norm($('typed').value)===norm(q.answer); $('typed').disabled=true;
                $('typed').style.borderColor=ok?'#3aa564':'#c0556a'; if(!ok){const h=document.createElement('div');h.className='muted';h.style.marginTop='8px';h.innerHTML='Answer: <b>'+q.answer+'</b>';$('typed').after(h);} settle(q,ok,wasDue);};
              $('check').onclick=submit; $('typed').addEventListener('keydown',e=>{if(e.key==='Enter')submit();}); $('typed').focus();
            }
          }
          function mark(box,ok,answer){
            box.querySelectorAll('.opt').forEach(x=>{if(x.textContent===answer)x.classList.add('correct');});
            if(!ok)box.querySelectorAll('.opt').forEach(x=>{}); // wrong highlight handled by click
          }
          function settle(q,ok,wasDue){
            beep(ok); schedule(q.item.i,ok);
            if(ok){correct++;combo++;const g=award(q.base,true,wasDue);xpGain+=g;burst('✅ +'+g);}
            else{combo=0;burst('❌');}
            save(); renderHud();
            setTimeout(()=>{qi++;render();},ok?700:1100);
          }
          function burst(txt){const b=$('burst');if(!b)return;b.textContent=txt;b.classList.remove('pop');void b.offsetWidth;b.classList.add('pop');}
          function finish(){
            bumpStreak();
            const acc=Math.round(100*correct/pool.length);
            mount.innerHTML='<div class="card"><div class="big">Round complete! 🎉</div>'+
              '<div class="row" style="justify-content:center;gap:22px"><span class="pill">✅ '+correct+'/'+pool.length+' ('+acc+'%)</span><span class="pill">+'+xpGain+' XP</span><span class="pill">🔥 '+S.streak+'</span></div>'+
              '<div class="row" style="justify-content:center"><button class="btn" id="again">Again →</button></div></div>';
            $('again').onclick=()=>{const sc=$('scenario').value;runSession(mountId,buildPool(sc,12,mountId==='arenaR'));};
          }
          render();
        }

        // ---- Tabs ----
        document.querySelectorAll('.tab').forEach(t=>t.onclick=()=>{
          document.querySelectorAll('.tab').forEach(x=>x.classList.remove('active'));t.classList.add('active');
          ['practice','review','learn','phrases','resources'].forEach(s=>$(s).hidden=(s!==t.dataset.t));
        });

        function fillCats(sel,withAll){sel.innerHTML=(withAll?['<option value="">All scenarios</option>']:[]).concat(cats.map(c=>'<option>'+c+'</option>')).join('');}
        fillCats($('scenario'),true); fillCats($('learnCat'),true); fillCats($('catFilter'),true);

        $('startBtn').onclick=()=>runSession('arena',buildPool($('scenario').value,12,false));
        $('reviewBtn').onclick=()=>runSession('arenaR',buildPool('',12,true));

        // ---- Learn (flashcards) ----
        let lcard=null;
        function pickLearn(){const f=$('learnCat').value;const pool=DATA.filter(x=>!f||x.c===f);lcard=pool[rand(pool.length)];$('lEn').textContent=lcard.e;$('lDe').textContent='';$('lCat').textContent=lcard.c;}
        $('lReveal').onclick=()=>{if(lcard){$('lDe').textContent=lcard.d;speak(lcard.d);}};
        $('lNext').onclick=pickLearn; $('learnCat').onchange=pickLearn;
        $('speak').onclick=()=>{if(lcard&&$('lDe').textContent)speak(lcard.d);else if(lcard)speak(lcard.d);};
        pickLearn();

        // ---- Phrases ----
        function renderPhrases(){const f=$('catFilter').value;const pool=DATA.filter(x=>!f||x.c===f);let html='',last='';
          pool.forEach(x=>{if(x.c!==last){html+='<div class="cat">'+x.c+'</div>';last=x.c;}html+='<table><tr><td class="de">'+x.d+'</td><td class="en">'+x.e+'</td></tr></table>';});
          $('phraseList').innerHTML=html;}
        $('catFilter').onchange=renderPhrases; renderPhrases();

        renderHud();
        </script>
        </body></html>
        """
    }
}

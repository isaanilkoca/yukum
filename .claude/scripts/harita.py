#!/usr/bin/env python3
# Yüküm haritası: graphify grafiğinden SADECE iOS sınıflarını + backend/DB durumunu tek HTML'e döker.
# Çalıştır: python3 .claude/scripts/harita.py  → graphify-out/yukum-harita.html (önce: graphify update .)
import json, re, glob, os, html
root = os.getcwd()
g = json.load(open('graphify-out/graph.json'))
N = {n['id']: n for n in g['nodes']}
def isios(n): return str(n.get('source_file','')).startswith('ios/Yukum/Yukum/')
classes = {i: n for i, n in N.items() if isios(n) and n.get('_callable_class')}
def owner(i):                      # düğümü ait olduğu sınıfa çevir (metot → sınıf)
    if i in classes: return i
    n = N.get(i)
    if not n or not isios(n): return None
    for c in classes:
        if i.startswith(c + '_'): return c
    return None
agg = {}
for e in g['links']:
    if e['relation'] not in ('calls', 'references', 'imports'): continue
    a, b = owner(e['source']), owner(e['target'])
    if a and b and a != b: agg[(a, b)] = agg.get((a, b), 0) + 1
def layer(n):
    f = n['source_file']
    if '/View/' in f or f.endswith(('ContentView.swift', 'YukumApp.swift')): return 'view'
    if n['label'].endswith('Service') or n['label'] in ('Session', 'AuthError'): return 'service'
    return 'model'
COL = {'view': '#4C8BF5', 'service': '#F5A623', 'model': '#2EB67D'}
nodes = [{'id': i, 'label': n['label'], 'color': COL[layer(n)], 'shape': 'box', 'font': {'color': '#fff'}, 'group': layer(n)} for i, n in classes.items()]
edges = [{'from': a, 'to': b, 'value': c, 'arrows': 'to'} for (a, b), c in agg.items()]

# --- backend: uçlar (controller dosyalarından), migration'lar, tablolar
eps = []
for f in sorted(glob.glob('backend/src/Yukum.Api/Controllers/*.cs')):
    s = open(f).read()
    base = (re.search(r'\[Route\("([^"]+)"\)\]', s) or [None, ''])[1]
    for m in re.finditer(r'\[(Http(Get|Post|Delete|Put))(?:\("([^"]*)"\))?\]\s*(?:\[[^\]]*\]\s*)*?(?:\[Authorize(?:\(Roles = ([^)]*)\))?\])?', s):
        path = m.group(3) or ''
        full = path.replace('~', '') if path.startswith('~') else (base + ('/' + path if path else ''))
        eps.append((m.group(2).upper(), full.replace('v{version:apiVersion}', 'v1').replace(':guid', ''), (m.group(4) or 'herkese açık/giriş').replace('RoleNames.', '').replace('"', ''), os.path.basename(f).replace('Controller.cs', '')))
migs = [os.path.basename(f)[:-3].split('_', 1) for f in sorted(glob.glob('backend/src/Yukum.Infrastructure/Persistence/Migrations/2*_*.cs')) if 'Designer' not in f]
TABLES = [('Users / Roles / UserRoles', 'Identity: hesaplar'), ('ShipperProfiles, CarrierProfiles, Vehicles, CarrierServiceCities', 'profiller'), ('RefreshTokens', 'tablo var, uç henüz yok (D4)'),
          ('Cities (81), Districts (973)', 'sabit il/ilçe verisi'), ('Listings', 'ilanlar (Open / Assigned)'), ('Offers', 'teklifler (Pending / Accepted / Rejected + geçmiş bayrakları)')]
log = [l for l in open('docs/Ilerleme_Gunlugu.md').read().splitlines() if l.startswith('- (31 Ekim')][-4:]
def esc(s): return html.escape(s)
page = f'''<!doctype html><html lang="tr"><meta charset="utf-8"><title>Yüküm Haritası</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/vis-network/9.1.2/standalone/umd/vis-network.min.js"></script>
<style>body{{font:14px -apple-system,sans-serif;margin:0;background:#fafafa;color:#222}}header{{padding:12px 20px;background:#10243F;color:#fff}}
nav button{{margin:8px 4px 0 0;padding:8px 14px;border:0;border-radius:6px;background:#2b4468;color:#fff;cursor:pointer}}nav button.on{{background:#F26B1D}}
section{{display:none;padding:16px 20px}}section.on{{display:block}}#net{{height:75vh;background:#fff;border:1px solid #ddd;border-radius:8px}}
table{{border-collapse:collapse;background:#fff;margin:8px 0 20px}}td,th{{border:1px solid #ddd;padding:6px 10px;text-align:left}}th{{background:#eef}}
.k span{{display:inline-block;padding:2px 8px;border-radius:4px;color:#fff;margin-right:8px}}code{{background:#eee;padding:1px 5px;border-radius:3px}}</style>
<header><b>Yüküm Haritası</b> · iOS sınıf bağlantıları + backend/DB durumu
<nav><button id="b1" class="on" onclick="t(1)">iOS grafiği</button><button id="b2" onclick="t(2)">Backend &amp; DB durumu</button></nav></header>
<section id="s1" class="on"><p class="k"><span style="background:#4C8BF5">View (ekran)</span><span style="background:#F5A623">Service (API'ye konuşan)</span><span style="background:#2EB67D">Model (paket kalıbı)</span> Ok: "kullanır". Sürükle, yakınlaştır, düğüme tıkla.</p><div id="net"></div></section>
<section id="s2"><h3>Şu an geldiğimiz yer (son günlük satırları)</h3><ul>{''.join('<li>'+esc(l[2:])+'</li>' for l in log)}</ul>
<h3>DB tabloları</h3><table><tr><th>Tablo</th><th>Ne</th></tr>{''.join(f'<tr><td>{esc(a)}</td><td>{esc(b)}</td></tr>' for a,b in TABLES)}</table>
<h3>Migration'lar (sırayla uygulandı)</h3><table><tr><th>Zaman</th><th>Ad</th></tr>{''.join(f'<tr><td>{a}</td><td>{b}</td></tr>' for a,b in migs)}</table>
<h3>API uçları ({len(eps)})</h3><table><tr><th>Yöntem</th><th>Adres</th><th>Kim</th><th>Controller</th></tr>{''.join(f'<tr><td>{m}</td><td><code>{esc(p)}</code></td><td>{esc(r)}</td><td>{c}</td></tr>' for m,p,r,c in eps)}</table>
<p>Elle denemek: Scalar <code>http://localhost:5054/scalar</code> · SQL sorguları: <code>docs/sql/teklifler.sql</code></p></section>
<script>function t(n){{for(const i of [1,2]){{document.getElementById('s'+i).className=i==n?'on':'';document.getElementById('b'+i).className=i==n?'on':''}}}}
new vis.Network(document.getElementById('net'),{{nodes:new vis.DataSet({json.dumps(nodes)}),edges:new vis.DataSet({json.dumps(edges)})}},
{{physics:{{solver:'forceAtlas2Based',stabilization:{{iterations:250}}}},edges:{{smooth:true,color:'#999'}},interaction:{{hover:true}}}});</script></html>'''
open('graphify-out/yukum-harita.html', 'w').write(page)
print(f'iOS sınıf: {len(nodes)}, bağlantı: {len(edges)}, uç: {len(eps)}, migration: {len(migs)}')

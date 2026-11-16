load("tools/lib.js");
load("tools/model.js");
var OUT = arguments[0] + "/out";
var NAME = arguments.length > 1 ? arguments[1] : "MER_UniShare";
var Dir = Java.type("desenho.formas.FormaNaoRetangularBase$Direcao");
var Ligacao = Java.type("diagramas.conceitual.Ligacao");
var Relacionamento = Java.type("diagramas.conceitual.Relacionamento");
var EW = 190, EH = 60, DW = 150, DH = 50, LINE_H = 16;
var CARD = { "1,1": TC.C11, "0,1": TC.C01, "1,n": TC.C1N, "0,n": TC.C0N };

function gx(v){ return Math.round(OX + v[0]*GX + (v.length > 2 ? v[2] : 0)); }
function gy(v){ return Math.round(OY + v[1]*GY + (v.length > 3 ? v[3] : 0)); }

var frame = startApp(); var ed = frame.getEditor(); var d;
edt(function(){ d = ed.Novo(Tipo.tpConceitual); });

function itemsSnapshot(){ return new java.util.ArrayList(d.getListaDeItens()); }
function newItems(before){ var r=[]; var it=d.getListaDeItens(); for (var i=0;i<it.size();i++){ var o=it.get(i); if(!before.contains(o)) r.push(o);} return r; }

// define a polilinha de uma ligação (lista de pontos do lado "fromForma" até a outra ponta)
var LADO = { L:0, T:1, R:2, B:3 };
function setLine(l, fromForma, pts, side){
  var ps = l.getPontos();
  var guard = 0;
  while (ps.size() < pts.length && guard++ < 20) { l.InserirPonto(0); ps = l.getPontos(); }
  var seq = pts.slice();
  while (seq.length < ps.size()) seq.splice(seq.length-1, 0, seq[seq.length-2]); // repete o penúltimo (colinear)
  var forward = (ps.get(0).getEm() == fromForma) || (ps.get(ps.size()-1).getEm() != fromForma && ps.get(0).getEm() != null && ps.get(0).getEm() !== undefined && false);
  if (ps.get(ps.size()-1).getEm() == fromForma) forward = false; else if (ps.get(0).getEm() == fromForma) forward = true; else print("WARN: ponta nao encontrada para "+fromForma.getTexto());
  for (var k=0;k<ps.size();k++){
    var p = forward ? seq[k] : seq[seq.length-1-k];
    ps.get(k).setLocation(Math.round(p[0])-3, Math.round(p[1])-3);
  }
  if (side) (forward ? ps.get(0) : ps.get(ps.size()-1)).setLado(LADO[side]);
  l.reSetBounds();
}

function sidePoint(e, side, off){
  var l=e.getLeft(), t=e.getTop(), w=e.getWidth(), h=e.getHeight(), cx=l+w/2, cy=t+h/2;
  if (side=="T") return [cx+off, t];
  if (side=="B") return [cx+off, t+h];
  if (side=="L") return [l, cy+off];
  return [l+w, cy+off];
}

// rota ortogonal: ponto na entidade -> vias -> vértice do losango
function route(e, side, off, vias, cx, cy){
  var P = sidePoint(e, side, off);
  var pts = [P];
  var horiz = (side=="L" || side=="R");
  var cur = P;
  for (var i=0;i<vias.length;i++){
    var V = [gx(vias[i]), gy(vias[i])];
    if (Math.abs(V[0]-cur[0]) > 1 && Math.abs(V[1]-cur[1]) > 1){
      var E = horiz ? [V[0], cur[1]] : [cur[0], V[1]];
      pts.push(E); horiz = !horiz;
    } else horiz = Math.abs(V[1]-cur[1]) <= 1;
    pts.push(V); cur = V;
  }
  var vx, vy;
  if (horiz){
    if (Math.abs(cur[1]-cy) <= 1){ vx = cur[0] < cx ? cx-DW/2 : cx+DW/2; vy = cy; pts.push([vx,vy]); }
    else { pts.push([cx, cur[1]]); vx = cx; vy = cur[1] < cy ? cy-DH/2 : cy+DH/2; pts.push([vx,vy]); }
  } else {
    if (Math.abs(cur[0]-cx) <= 1){ vx = cx; vy = cur[1] < cy ? cy-DH/2 : cy+DH/2; pts.push([vx,vy]); }
    else { pts.push([cur[0], cy]); vx = cur[0] < cx ? cx-DW/2 : cx+DW/2; vy = cy; pts.push([vx,vy]); }
  }
  // remove pontos repetidos consecutivos
  var clean=[pts[0]]; for (var i=1;i<pts.length;i++){ var a=clean[clean.length-1]; if (Math.abs(a[0]-pts[i][0])>0.5 || Math.abs(a[1]-pts[i][1])>0.5) clean.push(pts[i]); }
  return clean;
}

function addAttrs(owner, list, mode, anchor){
  // mode: "BR" (abaixo-direita), "TR" (acima-direita), "REL" (acima do losango)
  var made = [];
  for (var i=0;i<list.length;i++){
    var nm = list[i];
    var at = d.ExternalRealiseComando(Cmd.cmdAtributo, new Point(owner.getLeft()+owner.getWidth()/2, owner.getTop()+owner.getHeight()/2));
    at.setTexto(nm.replace("*","").replace("?",""));
    if (nm.indexOf("*")>=0) at.setIdentificador(true);
    if (nm.indexOf("?")>=0) at.setOpcional(true);
    at.setDirecaoLigacao(Dir.Left);
    made.push(at);
  }
  var n = made.length;
  for (var i=0;i<n;i++){
    var at = made[i], busX, baseY, cyA;
    if (mode=="REL"){
      busX = owner.getLeft()+owner.getWidth()/2; baseY = owner.getTop(); cyA = baseY - 25 - i*LINE_H;
    } else if (mode=="TR"){
      busX = owner.getLeft()+owner.getWidth()-15; baseY = owner.getTop(); cyA = baseY - 18 - (n-1-i)*LINE_H;
    } else {
      busX = owner.getLeft()+owner.getWidth()-15; baseY = owner.getTop()+owner.getHeight(); cyA = baseY + 18 + i*LINE_H;
    }
    var left = busX + 12, top = Math.round(cyA - 7);
    at.DoMove(left - at.getLeft(), top - at.getTop());
    var l = at.getListaDeLigacoes().get(0);
    setLine(l, owner, [[busX, baseY], [busX, cyA], [at.getLeft(), cyA]]);
  }
  return made;
}

var E = {};
edt(function(){
  for (var k in ENT){
    var s = ENT[k], w = s.w || EW, h = s.h || EH;
    var cx = gx(s.g), cy = gy(s.g);
    var e = d.ExternalRealiseComando(Cmd.cmdEntidade, new Point(Math.round(cx-w/2), Math.round(cy-h/2)));
    e.setTexto(k);
    e.SetBounds(Math.round(cx-w/2), Math.round(cy-h/2), w, h);
    E[k] = e;
  }
});

edt(function(){
  for (var i=0;i<REL.length;i++){
    var r = REL[i];
    var A = E[r.a[0]], B = E[r.b[0]];
    if (!A || !B){ print("ERRO entidade inexistente em "+r.n); continue; }
    var before = itemsSnapshot();
    d.Relacione(A, B);
    var nw = newItems(before), R = null, ligs = [];
    for (var j=0;j<nw.length;j++){ if (nw[j] instanceof Relacionamento) R = nw[j]; else if (nw[j] instanceof Ligacao) ligs.push(nw[j]); }
    if (!R || ligs.length != 2){ print("ERRO relacionamento "+r.n+" itens="+nw.length); continue; }
    R.setTexto(r.n);
    var cx = gx(r.d), cy = gy(r.d);
    R.DoMove(Math.round(cx-DW/2) - R.getLeft(), Math.round(cy-DH/2) - R.getTop());
    var ends = [r.a, r.b];
    for (var q=0;q<2;q++){
      var spec = ends[q], ent = E[spec[0]];
      var lig = null;
      for (var j=0;j<2;j++){ var la = ligs[j].getFormaPontaA(), lb = ligs[j].getFormaPontaB(); if ((la==ent && lb==R) || (lb==ent && la==R)) { if (A==B && q==1 && lig==null && ligs[j]==ligs[0]) continue; lig = ligs[j]; } }
      if (!lig){ print("ERRO ligacao nao achada "+r.n+"/"+spec[0]); continue; }
      var pts = route(ent, spec[2], spec[3], spec.length>4 ? spec[4] : [], cx, cy);
      if (spec.length > 4) lig.SuperSetInteligente(false); // rota manual com vias: brModelo não deve recalcular
      setLine(lig, ent, pts, spec[2]);
      lig.getCard().setCard(CARD[spec[1]]);
    }
    if (r.attrs) addAttrs(R, r.attrs, "REL");
    r._R = R;
  }
});

edt(function(){
  for (var k in ENT){ addAttrs(E[k], ENT[k].attrs, ENT[k].side || "BR"); }
});

edt(function(){
  var it = d.getListaDeItens();
  for (var i=0;i<it.size();i++){ var o = it.get(i); if (o instanceof Ligacao && o.getCard() != null) { try { o.getCard().Posicione(); } catch(e) {} } }
  d.repaint();
});

edt(function(){
  saveXml(d, OUT + "/" + NAME + ".xml");
  d.setNome(NAME);
  print("salvar brM3=" + d.Salvar(new java.io.File(OUT + "/" + NAME + ".brM3"), false));
  savePng(d, OUT + "/" + NAME + ".png", 3150, 2250);
  var cnt = {}; var it = d.getListaDeItens();
  for (var i=0;i<it.size();i++){ var c = it.get(i).getClass().getSimpleName(); cnt[c] = (cnt[c]||0)+1; }
  print("ITENS " + JSON.stringify(cnt));
});
java.lang.System.exit(0);

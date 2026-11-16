load("tools/lib.js");
load("tools/mr_model.js");
var OUT = arguments[0] + "/out";
var NAME = arguments.length > 1 ? arguments[1] : "MR_UniShare";
var Conv = Java.type("controlador.conversor.conversorConceitualParaLogico");
var Tab = Java.type("diagramas.logico.Tabela");
var Cons = Java.type("diagramas.logico.Constraint"), CT = Java.type("diagramas.logico.Constraint$CONSTRAINT_TIPO");
var CARD = { "1,1": TC.C11, "0,1": TC.C01, "1,n": TC.C1N, "0,n": TC.C0N };
var LADO = { L:0, T:1, R:2, B:3 };
var TW = 290, ROW_H = 22, HEAD_H = 30;

function gx(v){ return Math.round(MOX + v[0]*MGX + (v.length > 2 ? v[2] : 0)); }
function gy(v){ return Math.round(MOY + v[1]*MGY + (v.length > 3 ? v[3] : 0)); }
function has(flags, f){ return (" " + (flags||"") + " ").indexOf(" " + f + " ") >= 0; }
function campo(t, nome){ var cs = t.getCampos(); for (var i=0;i<cs.size();i++) if (cs.get(i).getTexto()==nome) return cs.get(i); return null; }
function pkCons(t){ var cs=t.getConstraints(); for (var i=0;i<cs.size();i++) if (cs.get(i).getTipo()==CT.tpPK) return cs.get(i); return null; }
function sidePoint(e, side, off){
  var l=e.getLeft(), t=e.getTop(), w=e.getWidth(), h=e.getHeight(), cx=l+w/2, cy=t+h/2;
  if (side=="T") return [cx+off, t];
  if (side=="B") return [cx+off, t+h];
  if (side=="L") return [l, cy+off];
  return [l+w, cy+off];
}
// polilinha ortogonal: filha (lado) -> vias -> pai (lado)
function route(child, cs, coff, parent, ps, poff, vias){
  var P = sidePoint(child, cs, coff), Q = sidePoint(parent, ps, poff);
  var pts = [P], cur = P, horiz = (cs=="L" || cs=="R");
  for (var i=0;i<vias.length;i++){
    var V = [gx(vias[i]), gy(vias[i])];
    if (Math.abs(V[0]-cur[0]) > 1 && Math.abs(V[1]-cur[1]) > 1){ pts.push(horiz ? [V[0],cur[1]] : [cur[0],V[1]]); horiz = !horiz; }
    else horiz = Math.abs(V[1]-cur[1]) <= 1;
    pts.push(V); cur = V;
  }
  if (Math.abs(Q[0]-cur[0]) > 1 && Math.abs(Q[1]-cur[1]) > 1) pts.push((ps=="T" || ps=="B") ? [Q[0],cur[1]] : [cur[0],Q[1]]);
  pts.push(Q);
  var clean=[pts[0]]; for (var i=1;i<pts.length;i++){ var a=clean[clean.length-1]; if (Math.abs(a[0]-pts[i][0])>0.5 || Math.abs(a[1]-pts[i][1])>0.5) clean.push(pts[i]); }
  return clean;
}
function setLine(l, fromForma, pts, sideFrom, sideTo){
  var ps = l.getPontos(), guard = 0;
  while (ps.size() < pts.length && guard++ < 20) { l.InserirPonto(0); ps = l.getPontos(); }
  var seq = pts.slice();
  while (seq.length < ps.size()) seq.splice(seq.length-1, 0, seq[seq.length-2]);
  var forward = ps.get(0).getEm() == fromForma;
  if (!forward && ps.get(ps.size()-1).getEm() != fromForma) print("WARN ponta nao encontrada " + fromForma.getTexto());
  for (var k=0;k<ps.size();k++){ var p = forward ? seq[k] : seq[seq.length-1-k]; ps.get(k).setLocation(Math.round(p[0])-3, Math.round(p[1])-3); }
  (forward ? ps.get(0) : ps.get(ps.size()-1)).setLado(LADO[sideFrom]);
  (forward ? ps.get(ps.size()-1) : ps.get(0)).setLado(LADO[sideTo]);
  l.reSetBounds();
}

var frame = startApp(); var ed = frame.getEditor(); var d;
edt(function(){ d = ed.Novo(Tipo.tpLogico); });
var conv = new Conv();
var fDest = Conv.class.getDeclaredField("destino"); fDest.setAccessible(true);
var ligue = Conv.class.getDeclaredMethod("Ligue", [Tab.class, Tab.class]); ligue.setAccessible(true);

var T = {};
edt(function(){
  fDest.set(conv, d);
  for (var k in TAB){
    var s = TAB[k];
    var h = HEAD_H + s.f.length*ROW_H + 8;
    var cx = gx(s.g), cy = gy(s.g);
    var t = d.ExternalRealiseComando(Cmd.cmdTabela, new Point(Math.round(cx-TW/2), Math.round(cy-h/2)));
    t.setTexto(k);
    for (var i=0;i<s.f.length;i++){
      var f = s.f[i], c = t.Add(f[0]);
      c.setTipo(f[1]);
      if (has(f[2],"NULL")) c.setComplemento("NULL");
      if (has(f[2],"PK")) { c.setKey(true); t.ProcesseIrKey(c); }
    }
    t.setMostrarConstraints(false);
    t.setAutosize(false);
    t.SetBounds(Math.round(cx-TW/2), Math.round(cy-h/2), TW, h);
    T[k] = t;
  }
});

edt(function(){
  for (var i=0;i<FKS.length;i++){
    var fk = FKS[i], child = T[fk[0]], parent = T[fk[2]];
    var cc = campo(child, fk[1]), pc = parent.getCampos().get(0);
    var lin = ligue.invoke(conv, child, parent);
    var cons = new Cons(child); cons.setTipo(CT.tpFK);
    cons.setNome("fk_" + fk[0] + "_" + fk[1].replace(/^id_/, "")); cons.setNomeada(true);
    cons.Add(pc, cc, lin, pkCons(parent));
    cons.Valide();
    cc.SetFkey(true);
    lin.SuperSetInteligente(false);
    setLine(lin, child, route(child, fk[5], fk[6], parent, fk[7], fk[8], fk.length > 9 ? fk[9] : []), fk[5], fk[7]);
    var cardChild = lin.getFormaPontaA() == child ? lin.getCardA() : lin.getCardB();
    var cardParent = lin.getFormaPontaA() == child ? lin.getCardB() : lin.getCardA();
    cardParent.setCard(CARD[fk[3]]); cardChild.setCard(CARD[fk[4]]);
    try { lin.ajusteSeta(); } catch(e) {}
    try { cardChild.Posicione(); cardParent.Posicione(); } catch(e) {}
    if (!cons.isValidado()) print("FK INVALIDA " + fk.slice(0,3).join(" "));
  }
  for (var k in TAB){ var s = TAB[k]; for (var i=0;i<s.f.length;i++) if (has(s.f[i][2],"UQ")) { var c = campo(T[k], s.f[i][0]); c.setUnique(true); T[k].ProcesseIrUnique(c); } }
  for (var k in T){ var s=TAB[k]; T[k].SetBounds(T[k].getLeft(), T[k].getTop(), TW, HEAD_H + s.f.length*ROW_H + 8); }
  d.repaint();
});

edt(function(){
  var n = 0; for (var k in T){ var cs = T[k].getConstraints(); for (var i=0;i<cs.size();i++) if (cs.get(i).getTipo()==CT.tpFK) n++; }
  print("FKs geradas: " + n);
  saveXml(d, OUT + "/" + NAME + ".xml");
  d.setNome(NAME);
  print("salvar brM3=" + d.Salvar(new java.io.File(OUT + "/" + NAME + ".brM3"), false));
  savePng(d, OUT + "/" + NAME + ".png", 3300, 2700);
  var cnt = {}; var it = d.getListaDeItens();
  for (var i=0;i<it.size();i++){ var c = it.get(i).getClass().getSimpleName(); cnt[c] = (cnt[c]||0)+1; }
  print("ITENS " + JSON.stringify(cnt));
  for (var k in T) if (T[k].getHeight() != HEAD_H + TAB[k].f.length*ROW_H + 8) print("altura alterada: " + k + " " + T[k].getHeight());
});
java.lang.System.exit(0);

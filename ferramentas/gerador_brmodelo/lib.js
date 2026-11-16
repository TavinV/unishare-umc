var SU = javax.swing.SwingUtilities;
var Cmd = Java.type("controlador.Controler$Comandos");
var Tipo = Java.type("controlador.Diagrama$TipoDeDiagrama");
var TC = Java.type("desenho.preAnyDiagrama.PreCardinalidade$TiposCard");
var Point = java.awt.Point;
var FP = Java.type("principal.FramePrincipal");
function startApp(){
  Java.type("principal.Aplicacao").main([]);
  var frame=null;
  for (var t=0;t<60 && frame==null;t++){ java.lang.Thread.sleep(500); var fs=java.awt.Frame.getFrames(); for (var i=0;i<fs.length;i++) if (fs[i] instanceof FP && fs[i].isVisible()) frame=fs[i]; }
  java.lang.Thread.sleep(1500); return frame;
}
function edt(f){ var err=null, r; SU.invokeAndWait(function(){ try{ r=f(); }catch(e){ err=e; } }); if(err){ print("ERR "+err); if (err.printStackTrace) err.printStackTrace(); if (err.stack) print(err.stack);} return r; }
function savePng(d, path, w, h){
  var img = new java.awt.image.BufferedImage(w,h,java.awt.image.BufferedImage.TYPE_INT_RGB);
  var g=img.createGraphics(); g.setRenderingHint(java.awt.RenderingHints.KEY_ANTIALIASING, java.awt.RenderingHints.VALUE_ANTIALIAS_ON); g.setRenderingHint(java.awt.RenderingHints.KEY_TEXT_ANTIALIASING, java.awt.RenderingHints.VALUE_TEXT_ANTIALIAS_ON);
  g.setColor(java.awt.Color.WHITE); g.fillRect(0,0,w,h); d.ExternalPaint(g); g.dispose();
  javax.imageio.ImageIO.write(img,"png",java.nio.file.Paths.get(path).toFile());
}
function saveXml(d, path){ var x = Java.type("controlador.Diagrama").SaveToXml(d, false); java.nio.file.Files.write(java.nio.file.Paths.get(path), x.getBytes("UTF-8")); return x; }
function priv(o, cls, name){ var f = java.lang.Class.forName(cls).getDeclaredField(name); f.setAccessible(true); return f.get(o); }

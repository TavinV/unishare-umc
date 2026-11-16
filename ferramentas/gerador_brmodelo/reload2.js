load("tools/lib.js"); var OUT = arguments[0] + "/out"; var N = arguments[1]; var W = parseInt(arguments[2]), H = parseInt(arguments[3]);
var DG = Java.type("controlador.Diagrama");
var frame = startApp(); var ed = frame.getEditor();
edt(function(){ var d = DG.LoadFromFile(new java.io.File(OUT + "/" + N + ".brM3"), ed); print(N + " recarregado=" + (d!=null) + " itens=" + d.getListaDeItens().size()); savePng(d, OUT + "/" + N + "_reload.png", W, H); });
java.lang.System.exit(0);

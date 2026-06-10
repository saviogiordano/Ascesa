# Ascesa — App Icon

Icona dell'app **Ascesa** pronta per Xcode, in formato moderno a singola dimensione (1024×1024): Xcode genera automaticamente tutte le misure necessarie a partire dal master 1024.

## Contenuto

```
AppIcon.appiconset/
├── Contents.json              ← configurazione del catalogo asset
├── AppIcon-1024.png           ← variante standard (chiara), opaca
├── AppIcon-1024-Dark.png      ← variante modalità scura (sfondo trasparente)
└── AppIcon-1024-Tinted.png    ← variante "tinta" iOS 18 (grigi su trasparente)
AppIcon-source.svg             ← sorgente vettoriale editabile
make_icons.py                  ← script per ri-esportare i PNG dall'SVG/geometria
```

## Come usarla in Xcode

1. Nel progetto apri `Assets.xcassets`.
2. Se esiste già un `AppIcon`, eliminalo (clic destro → Remove).
3. Trascina la cartella `AppIcon.appiconset` dentro `Assets.xcassets` (oppure copiala nella cartella del catalogo dal Finder).
4. Seleziona il target → tab **General** → sezione **App Icons and Launch Screen** → assicurati che **App Icon Source** sia impostato su `AppIcon`.
5. Compila: Xcode genererà tutte le risoluzioni per iPhone/iPad/App Store dal file 1024.

Requisiti consigliati: Xcode 15 o successivo. Le varianti scura/tinta richiedono Xcode 16 / iOS 18; su versioni precedenti viene usata solo la variante standard, senza errori.

## Note tecniche importanti

- La variante **standard** è un quadrato pieno **senza trasparenza e senza angoli arrotondati**: iOS applica automaticamente la maschera con gli angoli. Non aggiungere tu l'arrotondamento.
- Le varianti **dark** e **tinted** hanno lo sfondo trasparente: è corretto, il sistema disegna lo sfondo dietro l'artwork.
- Niente testo dentro l'icona e nessun riferimento a marchi di terzi (es. TACX/Garmin), come richiesto dalle linee guida App Store.

## Palette

| Elemento | Colore | HEX |
|----------|--------|-----|
| Sfondo | indaco profondo | `#1E2A52` |
| Area sotto la salita | indaco medio | `#2E4288` |
| Profilo + "sole" di vetta | ambra | `#FFB84D` |

Suggerimento: riusa `#1E2A52` come colore dominante nella dashboard di allenamento per un'identità coerente dall'icona alla schermata live.

## Modificare l'icona

Modifica `AppIcon-source.svg` (è vettoriale, scala senza perdita) e poi rigenera i PNG:

```bash
pip install Pillow
python3 make_icons.py
```

Lo script rende a 4× e riduce a 1024 con ricampionamento LANCZOS per bordi nitidi.

// Verteidigungspräsentation Wallbreaker
// Migration von presentation.odp nach Typst (16:9, 33.867cm x 19.05cm)
// Vorlage: Polizei Berlin Design (Headerband + Navigationsrand, Farbe #002266)
//
// Ausrichtung: Das Kolloquium wendet sich an Prüfer, die die Arbeit vollständig
// kennen. Die Präsentation ist daher eine umformulierte Darstellung, kein
// Grundlagen-Vortrag, und folgt dem roten Faden:
//   Motivation, Idee, Projekt, Umsetzung in Kürze, Durchsuchungsmaßnahme, Fazit.

#set page(
  width: 33.867cm,
  height: 19.05cm,
  margin: 0pt,
  fill: white,
)

#set text(font: ("Berlin Type Office", "Arial", "Liberation Sans"), lang: "de", size: 14.5pt)

#import "quellen.typ": quellen, bild-quelle, quellen-inhalt

#let navy = rgb("#002266")
#let nav-items = (
  "Motivation",
  "Idee",
  "Umsetzung",
  "Einsatz",
  "Fazit",
)

#let header() = {
  rect(width: 100%, height: 2.049cm, fill: navy)
  place(left + top, dx: 0.301cm, dy: 0.278cm)[
    #image("assets/polizei-berlin.png", width: 4.018cm)
  ]
  place(right + top, dx: -0.506cm, dy: 0.465cm)[
    #image("assets/berlin.png", width: 3.391cm)
  ]
}

#let sidebar(active: none) = {
  place(left + top, dy: 3.2cm)[
    #rect(width: 5.435cm, height: 15.849cm, fill: navy)
  ]
  for (i, item) in nav-items.enumerate() {
    place(left + top, dx: 0.485cm, dy: 4.354cm + i * 1.272cm)[
      #text(
        size: 18pt,
        weight: if i == active { "bold" } else { "regular" },
        fill: white,
      )[#item]
    ]
  }
  place(left + bottom, dx: 0.2cm, dy: -0.144cm)[
    #text(size: 14pt, weight: "bold", fill: white)[#context counter(page).display()]
  ]
}

#let content-width = 26.697cm

#let bullets(items) = {
  stack(
    spacing: 15pt,
    ..items.map(it => [
      #box(width: 14.5pt)[#align(left)[#sym.bullet]]
      #text(size: 14.5pt)[#it]
    ]),
  )
}

#let figure-img(path, w: 23.5cm) = {
  align(center)[
    #image(path, width: w)
  ]
}

#let slide(active: 0, body) = {
  header()
  sidebar(active: active)
  place(left + top, dx: 6.124cm, dy: 3.3cm)[
    #block(width: content-width, height: 16.2cm, clip: false)[
      #set par(leading: 9pt, justify: false)
      #body
    ]
  ]
}

// =====================================================================
// Folie 1: Titelfolie
// =====================================================================
#header()
#sidebar()

#place(left + top, dx: 6.124cm, dy: 3.0cm)[
  #block(width: content-width)[
    #set par(leading: 13.56pt)
    #align(center)[
      #text(size: 26pt, weight: "bold")[Polizei Berlin]
      #linebreak()
      #text(size: 26pt, weight: "bold")[LKA 712]
    ]
  ]
]

#place(left + top, dx: 6.124cm, dy: 6.4cm)[
  #block(width: content-width)[
    #align(center)[
      #text(size: 30pt, weight: "bold")[Bachelorarbeit Verteidigung]
      #v(6pt)
      #text(size: 17pt)[Entwicklung eines Mikrocontroller-Systems zur]
      #linebreak()
      #text(size: 17pt)[passiven WLAN-Signalanalyse bei polizeilichen Durchsuchungsmaßnahmen]
    ]
  ]
]

#place(left + top, dx: 6.124cm, dy: 11.5cm)[
  #block(width: content-width)[
    #align(center)[
      #text(size: 16pt)[Alexander Betke]
      #linebreak()
      #text(size: 13pt)[Betreuer: Prof. Dr. Arthur Zimmermann, Dipl.-Ing. (FH) Gero Gebert]
      #linebreak()
      #text(size: 13pt)[2\. September 2026]
    ]
  ]
]

#pagebreak()

// =====================================================================
// Folie 2: Versteckte IoT-Geräte im Alltag
// =====================================================================
#slide(active: 0)[
  #align(center)[
    #text(size: 17pt, fill: rgb("#333"))[Versteckte Kameras und Mikrofone sind ein reales Problem]
  ]
  #v(8pt)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 1cm,
    align(center)[#bild-quelle("assets/kamera_in_gemälde.webp", height: 11.5cm)],
    align(center)[#bild-quelle("assets/hidden_camera_in_charger.jpg", height: 11.5cm)],
  )
]

#pagebreak()

// =====================================================================
// Folie 3: Warum das System gebraucht wird
// =====================================================================
#slide(active: 0)[
  #align(center)[
    #text(size: 17pt, fill: rgb("#333"))[Versteckte Funkkomponenten müssen im Raum auffindbar sein]
  ]
  #v(8pt)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 1cm,
    align(center)[#image("assets/motivation_geruchliche_ortung.svg", width: 12.3cm)],
    align(center)[#image("assets/motivation_funkortung.svg", width: 12.3cm)],
  )
]

#pagebreak()

// =====================================================================
// Folie 4: Wie die Idee entstand
// =====================================================================
#slide(active: 1)[
  #align(center)[
    #text(size: 17pt, fill: rgb("#333"))[Problemstellung]
  ]
  #v(8pt)
  #grid(
    columns: (1fr, 1.4fr),
    column-gutter: 1cm,
    align(center)[#bild-quelle("assets/person_holding_laptop.jpg", height: 11.5cm)],
    [
      #v(10pt)
      #bullets((
        [Funkaktivität wird bislang mit einem Laptop und Wireshark im Monitor-Modus analysiert.],
        [Technisch funktionsfähig, im Einsatz aber unhandlich.],
        [Ein aufgeklappter Laptop schränkt die Bewegung in engen Wohnräumen ein.],
        [Bindet eine Fachkraft an die Bedienung.],
      ))
    ],
  )
]

#pagebreak()

// =====================================================================
// Folie 5: Literaturanalyse
// =====================================================================
#slide(active: 1)[
  #align(center)[
    #text(size: 17pt, fill: rgb("#333"))[Literaturanalyse]
  ]
  #v(8pt)
  #figure-img("assets/literaturluecke.svg")
]

#pagebreak()

// =====================================================================
// Folie 6: Implementierungsübersicht
// =====================================================================
#slide(active: 2)[
  #align(center)[
    #text(size: 17pt, fill: rgb("#333"))[Implementierungsübersicht]
  ]
  #v(8pt)
  #figure-img("assets/umsetzung_gesamt.svg")
]

#pagebreak()

// =====================================================================
// Folie 7: Durchsuchungsmaßnahme
// =====================================================================
#slide(active: 3)[
  #align(center)[
    #text(size: 17pt, fill: rgb("#333"))[Durchsuchungsmaßnahme]
  ]
  #v(8pt)
  #pad(left: 4cm)[
    #image("assets/einsatz_grundriss.svg", height: 14.2cm)
  ]
]

#pagebreak()

// =====================================================================
// Folie 8: Fazit und Ausblick
// =====================================================================
#slide(active: 4)[
  #align(center)[
    #text(size: 17pt, fill: rgb("#333"))[Fazit und Ausblick]
  ]
  #v(8pt)
  #figure-img("assets/ausblick_roadmap.svg")
  #v(10pt)
  #align(center)[
    #text(size: 15pt, weight: "bold", fill: rgb("#002266"))[Ergebnis]
  ]
  #v(4pt)
  #align(center)[
    #text(size: 13pt)[Passive WLAN-Ortung auf Mikrocontroller-Basis ist im Einsatz realisierbar und löst die Unhandlichkeit von Laptop und Wireshark]
  ]
]

#pagebreak()

// QUELLEN
#header()
#sidebar()

#place(left + top, dx: 6.124cm, dy: 3.3cm)[
  #block(width: content-width, height: 16.2cm, clip: false)[
    #set par(leading: 9pt, justify: false)
    #quellen-inhalt
  ]
] <quellen-slide>

#pagebreak()

// ABSCHLUSS
#header()
#sidebar()

#place(left + top, dx: 6.124cm, dy: 7.0cm)[
  #block(width: content-width)[
    #align(center)[
      #text(size: 30pt, weight: "bold")[Vielen Dank]
      #v(8pt)
      #text(size: 18pt)[Fragen und Diskussion]
    ]
  ]
]


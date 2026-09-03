// Quellenverzeichnis für die Präsentation
// Ordnet jedem Bildpfad eine Quelle (Nummer, Bezeichnung, URL) zu.
// Über die Funktion bild-quelle wird jedes verwendete Bild automatisch
// mit einem Verweis auf die Quellenfolie annotiert.

#let quellen = (
  "assets/kamera_in_gemälde.webp": (
    nr: "1",
    tag: "DER SPIEGEL",
    quelle: "DER SPIEGEL: Smartphone-App spürt versteckte Spionagekameras auf (LAPD)",
    url: "https://www.spiegel.de/netzwelt/netzpolitik/laser-assisted-photography-detection-lapd-smartphone-app-spuert-versteckte-spionagekameras-auf-a-8318b023-0fad-40a8-a210-1c041a14d0a1",
  ),
  "assets/hidden_camera_in_charger.jpg": (
    nr: "2",
    tag: "ISC SANS",
    quelle: "ISC SANS: How to Find Hidden Cameras in your AirBNB",
    url: "https://isc.sans.edu/diary/How+to+Find+Hidden+Cameras+in+your+AirBNB/24834",
  ),
  "assets/person_holding_laptop.jpg": (
    nr: "3",
    tag: "Pexels",
    quelle: "Tetteh, S. E. (2023). Man standing and using a laptop [Photograph]. Pexels.",
    url: "https://www.pexels.com/photo/man-standing-and-using-a-laptop-18188382/",
  ),
)

#let quellen-label = "quellen-slide"

// Bild mit automatischer Quellenangabe.
// Zeichnet das Bild und darunter einen Verweis auf die Quellenfolie.
#let bild-quelle(path, ..args) = {
  let eintrag = quellen.at(path)
  block(above: 4pt, below: 4pt)[
    #image(path, ..args)
    #v(2pt)
    #text(size: 8pt, fill: rgb("#666"))[#link(<quellen-slide>)[#eintrag.tag [#eintrag.nr]]]
  ]
}

// Inhalt der Quellenfolie, die jede verwendete Quelle je Bild aufführt.
#let quellen-inhalt = {
  align(center)[#text(size: 17pt, weight: "bold")[Quellen]]
  v(8pt)
  for (path, eintrag) in quellen {
    block(above: 5pt)[
      #text(size: 12pt)[[#eintrag.nr] #link(eintrag.url)[#eintrag.quelle]]
    ]
  }
}

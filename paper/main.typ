#import "template.typ": code-block, footfigref, get-word-count, print-bibliography, project
#import "glossar.typ": glossary-entries
#import "@preview/glossarium:0.5.10": (
  count-refs, get-entry-back-references, gls, glspl, make-glossary, print-glossary, register-glossary,
)

#show: project.with(
  documentType: "Bachelorarbeit",
  topic: "Entwicklung eines Mikrocontroller-Systems zur passiven WLAN-Signalanalyse bei polizeilichen Durchsuchungsmaßnahmen",
  subtopic: "",
  studentName: "Alexander Betke",
  matrikelNr: "77203378972",
  company: "Polizei Berlin",
  jahrgang: "2023",
  fachbereich: "Duales Studium Wirtschaft · Technik",
  studiengang: "Informatik",
  betreuerHS: "Prof. Dr. Arthur Zimmermann",
  betreuerUnt: "Diplom-Ingenieur (FH) Gero Gebert",
  wordCount: auto,
  submissionDate: "31. Juli 2026",
  logoHWR: none,
  logoCompany: sys.inputs.at("logo", default: "assets/Polizeistern_Berlin.svg"),
  glossary-entries: glossary-entries,
)

#let code-figure(
  body,
  caption: none,
  supplement: [Listing],
  size: 10pt,
) = figure(
  block(
    width: 100%,
    fill: rgb("f8f9fa"),
    stroke: 0.5pt + rgb("cccccc"),
    inset: 8pt,
    radius: 3pt,
    align(left)[
      #set text(size: size)
      #body
    ],
  ),
  caption: caption,
  supplement: supplement,
  kind: "code",
)// --- Front Matter (Roman page numbers) ---
#heading(level: 1, numbering: none)[Abstract] <abstract>
Bei polizeilichen Durchsuchungsmaßnahmen stellt das schnelle und zielgerichtete Auffinden versteckter digitaler Beweismittel eine kritische Herausforderung dar. Diese Arbeit befasst sich mit der Entwicklung eines kostengünstigen, portablen Hardware-Prototyps auf Basis des @ESP32 zur passiven @WLAN[]-Signalanalyse. Das System befähigt Einsatzkräfte vor Ort, aktive, @WLAN[]-fähige Endgeräte in der unmittelbaren Umgebung nicht-invasiv aufzuspüren.

Das System verwendet eine zweigeteilte Architektur. Eine @no_std Rust-Firmware auf dem Mikrocontroller erfasst @WLAN[]-Pakete im Monitor-Modus. Eine plattformübergreifende Benutzeroberfläche auf Basis von Flutter verarbeitet die Signalstärke (@RSSI) für mobile Endgeräte. Zur Vermeidung von Paketverlusten werden die extrahierten Metadaten (Quell-@MAC, Ziel-@MAC und @RSSI) über @BLE an das Smartphone gestreamt.

Eine magnetische MagSafe-Halterung fixiert den Mikrocontroller samt Stromversorgung an der Smartphone-Rückseite und ermöglicht eine einhändige Bedienung. Die Evaluation im Feldtest untersucht Reichweite, Erkennungsgeschwindigkeit, Akkulaufzeit und Anwenderfreundlichkeit. Zudem werden die Auswirkungen der @MAC[]-Adressen-Randomisierung auf die passive Geräteidentifikation analysiert.

#outline(title: "Inhaltsverzeichnis", depth: 3, indent: 1.5em)

#heading(level: 1, numbering: none)[Abbildungsverzeichnis] <ch:abbildungsverzeichnis>
#outline(title: none, target: figure)

#let tab-col-width = 5em
#let acronym-print-gloss(
  entry,
  show-all: false,
  disable-back-references: false,
  deduplicate-back-references: false,
  minimum-refs: 1,
  description-separator: ": ",
  user-print-title: none,
  user-print-description: none,
  user-print-back-references: none,
) = {
  if show-all == true or count-refs(entry.at("key")) >= minimum-refs {
    grid(
      columns: (tab-col-width, 1fr),
      column-gutter: 0.5em,
      strong(entry.at("short")),
      [#entry.at("description")#context if not disable-back-references {
          " "
          user-print-back-references(entry, deduplicate: deduplicate-back-references)
        }],
    )
  }
}
#let short-only-title(entry) = strong(entry.at("short"))

#heading(level: 1, numbering: none)[Akronyme] <ch:akronyme-list>
#print-glossary(
  glossary-entries.filter(e => e.group == "acronyms"),
  user-print-group-heading: (..args) => [],
  user-print-gloss: acronym-print-gloss,
)

// --- Main Matter ---

#set page(numbering: "1")
#counter(page).update(1)

= Einleitung <ch:einleitung>

== Ausgangslage und Problemstellung
Digitale Beweismittel wie Smartphones, Tablets, mobile Datenspeicher, Smart-Home-Komponenten, Router, NAS-Systeme oder Netzwerkkameras spielen bei polizeilichen Durchsuchungsmaßnahmen eine zentrale Rolle. Diese Asservate enthalten häufig prozessrelevante Spuren, darunter verschlüsselte Chatverläufe, Finanztransaktionen, Krypto-Wallets, Standort-Logs oder Bilddokumente. Das physische Auffinden dieser elektronischen Bauteile stellt Einsatzkräfte vor Ort vor Herausforderungen. Beschuldigte nutzen Verstecke in Wohn- und Geschäftsräumen, beispielsweise Hohlräume in Trockenbauwänden, doppelte Böden, abgehängte Decken oder Alltagsgegenstände, um Speichermedien vor dem Zugriff der Ermittlungsbehörden zu verbergen @Prasad_2021[S. 152408].

Die Durchsuchung von Objekten erfolgt gemäß den Bestimmungen der §§ 102 ff. StPO und erfordert hohes Durchsuchungstempo bei gleichzeitiger Sorgfalt in der Beweissicherung. Werden verdeckte Speichermedien oder aktive Steuerungsknoten nicht rechtzeitig lokalisiert, besteht das Risiko, dass externe Datenverbindungen Löschanweisungen an Zielgeräte übermitteln oder flüchtige Daten im Arbeitsspeicher durch Trennung der Stromzufuhr verloren gehen.

Das Aufspüren relevanter Asservate stützt sich bislang primär auf die manuelle Durchsuchung durch Einsatzkräfte vor Ort. Kleinstgeräte wie Micro-SD-Karten, USB-Sticks oder IoT-Sensorknoten lassen sich visuell kaum detektieren, besonders wenn sie in Möbelstücken oder hinter Wänden verborgen sind. Als biologisches Hilfsmittel kommen bei polizeilichen Durchsuchungsmaßnahmen vereinzelt speziell ausgebildete Datenträgerspürhunde zum Einsatz, welche auf die geruchliche Wahrnehmung spezifischer chemischer Ausdünstungen von Speichermedien und Halbleiterbauteilen wie Polycarbonat konditioniert sind @Marquardt_2018[S. 16]. Diese olfaktorische Ortungsmethode unterliegt jedoch physikalischen und methodischen Restriktionen. Bei baulich verdeckten oder tief in Wänden eingemauerten Asservaten verhindert das dichte Mauerwerk das Entstehen einer hinreichenden Geruchsglocke im Raum, wodurch die chemischen Ausdünstungen des Zielgeräts unterhalb der geruchlichen Wahrnehmungsschwelle der Hundenase verbleiben @Marquardt_2018[S. 16].

In zeitgemäßen Gebäudestrukturen erschweren geschirmte Kabelkanäle, verdeckte Wand- und Deckensysteme sowie mehrgeschossige Verbauungen das physische Auffinden von Funkkomponenten @Sundar_2020[S. 3]. Ein technisches Signalsniffing agiert demgegenüber objektiviert und unabhängig von geruchlichen Ausdünstungen sowie visuellen Raumstrukturen. Solange ein verborgenes Asservat im laufenden Betrieb Hochfrequenzsignale aussendet, durchdringen elektromagnetische Wellen auch dichte Baustrukturen und ermöglichen eine flächendeckende Erfassung unabhängig von subjektiven Suchmusterpräferenzen @Sundar_2020[S. 3].

Erste Versuche, die Funkaktivität von Zielgeräten mithilfe von Standard-Laptops und der Software Wireshark im Monitor-Modus zu analysieren, erwiesen sich in der Einsatzpraxis als unhandlich. Der Transport eines aufgeklappten Laptops während der Durchsuchung eines engen Wohnraums schränkt die Bewegungsfreiheit der Einsatzkräfte ein und setzt fundierte Fachkenntnisse zur manuellen Paketinterpretation voraus.

Standardisierte drahtlose Schnittstellen ermöglichen das messtechnische Aufspüren. Elektronische Endgeräte sind mit Schnittstellen für @WLAN nach IEEE 802.11 ausgestattet und befinden sich im laufenden Betrieb in Sende- und Empfangsbereitschaft @Waltari_2018[S. 2]. Selbst ohne bestehende Verbindung zu einem @AP senden diese Geräte in regelmäßigen Zeitabständen unverschlüsselte Probe Requests aus, um nach bekannten Funknetzen zu suchen @Waltari_2018[S. 3]. Da diese Datenpakete über das Medium Luft übertragen und passiv empfangen werden, lässt sich die physische Anwesenheit eines Gerätes ohne aktiven Eingriff in das Zielnetzwerk feststellen.

== Zielsetzung
Diese Bachelorarbeit konzipiert, implementiert und evaluiert einen tragbaren Hardware-Prototyp zur passiven @WLAN[]-Signalanalyse. Das System basiert auf dem @SoC @ESP32, der ein Wi-Fi-Funkmodul mit Monitor-Mode-Unterstützung aufweist @Espressif_esp32. Die Sensor-Firmware wird in Rust als @no_std Anwendung unter Nutzung der Treiber `esp-hal` und `esp-radio` umgesetzt @Espressif_nostd.

Die Steuerung des Sensorsystems und die Anzeige der @RSSI erfolgen über eine mobile Applikation auf Basis von Flutter @Flutter_docs_description. Die Datenübertragung zwischen Mikrocontroller und Mobilgerät nutzt ein @BLE @GATT[]-Notification-Protokoll, bei dem die extrahierten Datenpakete (Quell-@MAC, Ziel-@MAC und @RSSI) blockweise an das Endgerät übermittelt werden. Die Hardware-Komponenten werden über eine magnetische MagSafe-Halterung an der Rückseite des Smartphones befestigt, was die Ein-Hand-Bedienung im Einsatz ermöglicht.

Das entwickelte Gesamtsystem wird im Rahmen von Feldtests hinsichtlich seiner Ortungsleistung, Akkulaufzeit und Anwenderfreundlichkeit evaluiert. Die Erprobung umfasst eine kontrollierte Messreihe in einem Büroflur sowie einen Feldtest während einer polizeilichen Durchsuchungsmaßnahme.



== Systematische Literaturübersicht <ch:literaturuebersicht>

=== Motivation und Methodik nach PRISMA 2020
Die Literaturrecherche nach den Leitlinien der @PRISMA 2020 @Page_2021 erschließt den Forschungsstand zu passiver Funkerfassung, RSSI-Ortung und MAC-De-Randomisierung, um die Architekturentscheidungen des Prototyps wissenschaftlich zu begründen.

=== Suchstrategie, Datenbanken und Auswahlkriterien
Die Literaturrecherche wurde über die fünf wissenschaftlichen Datenbanken *Web of Science*, *Unpaywall*, *Directory of Open Access Journals* (DOAJ), *Directory of Open Access Resources* (ROAD) sowie die *Elektronische Zeitschriftenbibliothek* (EZB) durchgeführt. Die Suchmatrix kombinierte Stichwörter aus drei zentralen Themenkomplexen mittels Boolescher Operatoren:

#align(center)[
  `("Wi-Fi sniffing" OR "WLAN sniffing" OR "passive Wi-Fi monitoring")` \
  `AND ("indoor triangulation" OR "indoor localization" OR "proximity tracing")` \
  `AND ("MAC Address Randomization" OR "MAC de-randomization" OR "fingerprinting")`
]

Die Recherche wurde auf Publikationen in deutscher und englischer Sprache beschränkt. Zur Erfassung der historischen Entwicklung sowie grundlegender Standardisierungen wurden bei der initialen Datenbankabfrage keine zeitlichen Schranken gesetzt. Die Selektion der Relevanz erfolgte anhand prähinterlegter Kriterien:

*Einschlusskriterien (IK):*
1. Fokussierung auf die passive Erfassung von IEEE 802.11 Management-Rahmen (siehe #link(<ch:grundlagen>)[Kapitel 2.1]).
2. Verfahren zur RSSI-basierten Entfernungsschätzung oder Nahbereichsortung in Innenräumen.
3. Methoden zur Identifikation und Verknüpfung von Endgeräten unter Berücksichtigung von MAC-Randomisierung und Fingerprinting.
*Ausschlusskriterien (AK):*
1. Arbeiten, die primär auf aktiven Netzwerkinteraktionen basieren (z. B. aktives Pinging), da diese dem Grundsatz der Nicht-Invasivität im polizeilichen Einsatzkontext widersprechen.
2. Veraltete Arbeiten mit überholten Technologiestandards, die für moderne Betriebssysteme keine Relevanz mehr besitzen.

=== Selektionsablauf und PRISMA-Flussdiagramm
Der schrittweise Selektionsprozess ist im PRISMA-2020-Flussdiagramm in @fig:prisma dargestellt. Über die fünf abgefragten wissenschaftlichen Datenbanken wurden initial insgesamt $n = 252$ Datensätze identifiziert, deren Verteilung in @tab:prisma-datenbanken aufgeschlüsselt ist. Vor Beginn des Screenings wurden $n = 143$ Duplikate sowie $n = 4$ Einträge aus sonstigen Gründen (fehlender Open-Access-Volltextzugang) entfernt, sodass $n = 105$ eindeutige Datensätze verblieben.

#figure(
  table(
    columns: (1.8fr, 1fr),
    align: (left, center),
    [*Datenbank / Register*], [*Identifizierte Einträge ($n$)*],
    [Unpaywall], [107],
    [ROAD (Directory of Open Access Resources)], [45],
    [Web of Science], [41],
    [EZB (Elektronische Zeitschriftenbibliothek)], [35],
    [DOAJ (Directory of Open Access Journals)], [24],
    [*Gesamtsumme*], [*252*],
  ),
  caption: [Übersicht der primär identifizierten Datensätze nach Datenbanken],
) <tab:prisma-datenbanken>


Im anschließenden Titel- und Abstract-Screening wurden $n = 81$ Arbeiten ausgeschlossen, die primär aktive Ortungsverfahren behandelten oder veraltete Technologiestandards zugrunde legten. Von den verbleibenden $n = 24$ zur Volltextbeschaffung vorgesehenen Berichten konnten $n = 7$ Berichte nicht abgerufen werden. Die anschließende Eignungsprüfung der $n = 17$ im Volltext bewerteten Arbeiten ergab keine weiteren Ausschlüsse ($n = 0$), sodass das finale Literaturkorpus exakt $n = 17$ Publikationen umfasst.

#figure(
  image(
    "./prisma/PRISMA_2020_flow_diagram_new_SRs_v1.svg",
    width: 100%,
  ),
  caption: [PRISMA-2020-Flussdiagramm der systematischen Literaturübersicht],
) <fig:prisma>

#pagebreak()
=== Detaillierte Analyse und kritische Einordnung der Kernarbeiten
Fünf Kernarbeiten aus dem Literaturkorpus begründen die Entwurfsentscheidungen des Prototyps.

#heading(
  level: 4,
  numbering: none,
)[A Case Study on the Monitor Mode Passive Capturing of WLAN Packets in an On-the-Move Setup]
Diese Studie untersucht die Performanz der passiven 802.11-Paketerfassung im Monitor-Modus bei mobilen Erfassungsszenarien (@OTM) im Vergleich zu statischen Messpunkten. Die Autoren belegen empirisch, dass mobile Sniffer-Knoten neben Probe Requests auch Steuerrahmen wie CTS- und ACK-Frames effizient erfassen und auswerten können @Prasad_2021[S. 152409]. Dynamische Bewegungspfade reduzieren zudem den Einfluss der MAC-Adressen-Randomisierung, da temporäre Adressen beim Vorbeigehen an Zielobjekten meist nur innerhalb eines einzelnen Zeitfensters erfasst werden @Prasad_2021[S. 152410]. Diese Ergebnisse begründen den mobilen Erfassungsansatz, bei dem der Sensor während der Raumdurchsuchung mitgeführt wird, um aktive Endgeräte im Vorbeigehen passiv zu erfassen @Prasad_2021[S. 152410].

#heading(level: 4, numbering: none)[A Case Study of WiFi Sniffing Performance Evaluation]
Die Arbeit widmet sich der quantitativen Bewertung von Hardware- und Firmware-Architekturen zur WLAN-Paketerfassung auf eingebetteten Mikrocontrollersystemen. Durch den experimentellen Vergleich verschiedener Kanal-Hopping-Strategien mit der Fixierung auf Einzelkanäle zeigen die Autoren, dass eine verweilzeitoptimierte Kanalumschaltung (Dwell Time) entscheidend ist, um Verlustraten im Funkmedium zu minimieren und Speicherengpässe bei hohen Paketraten zu vermeiden @Li_2020[S. 129226]. Dwell Times unterhalb von 50 ms führen durch synthetische Einschwingzeiten des HF-Front-Ends zu Paketverlusten, während Verweilzeiten über 200 ms die Erfassungswahrscheinlichkeit auf den übrigen Kanälen verschlechtern @Li_2020[S. 129228]. Daraus leitet sich das verweilzeitoptimierte 100-ms-Kanal-Hopping der @no_std Rust-Firmware auf dem ESP32 mit thread-sicherer @RAM[]-Pufferung ab, um Paketverluste im 2,4-GHz- und 5-GHz-Band zu minimieren @Li_2020[S. 129226].

#heading(level: 4, numbering: none)[A Study of MAC Address Randomization in Mobile Devices and When it Fails]
In dieser Untersuchung werden die Anonymisierungsmechanismen moderner mobiler Betriebssysteme bei der Aussendung von Probe Requests analysiert und systematische Schwachstellen aufgedeckt. Es wird nachgewiesen, dass das unveränderte @IE im Frame Body zusammen mit spezifischen Sende-Bursts und kohärenten Sequenznummern gerätespezifische Merkmale offenlegt @Martin_2017[S. 367]. Zudem belegen die Messungen, dass die Rotationsintervalle zufälliger MAC-Adressen bei inaktiven Scans meist mehr als eine Stunde betragen @Martin_2017[S. 368]. Für den polizeilichen Durchsuchungskontext rechtfertigt dies die Annahme, dass Mobilgeräte während eines zeitlich begrenzten Einsatzes von 15 bis 30 Minuten eine konstante temporäre Adresse beibehalten, was eine verlässliche Zuordnung zwischen empfangener Signaladresse und physischem Asservat erlaubt @Martin_2017[S. 367].

#heading(level: 4, numbering: none)[Noncooperative 802.11 MAC Layer Fingerprinting and Tracking of Mobile Devices]
Diese Veröffentlichung präsentiert Verfahren zum non-kooperativen Tracking von Mobilgeräten anhand unverschlüsselter 802.11-Header-Parameter. Durch die statistische Auswertung fortlaufender Sequenznummern und feldbasierter Fingerabdrücke demonstrieren die Autoren, dass zusammenhängende Sendersitzungen auch ohne aktiven Eingriff in das Funknetzwerk verknüpft werden können @Robyns_2017[S. 3]. Die aufgezeigten Prinzipien fließen in die Verarbeitungslogik der Flutter-Applikation ein, um empfangene Quell-MACs, Ziel-MACs und Sequenzparameter in Echtzeit zu filtern, Duplikate zu verwerfen und Gerätesitzungen für die Einsatzkraft abzugrenzen @Robyns_2017[S. 4].

#heading(level: 4, numbering: none)[New signal location method based on signal-range data for proximity tracing tools]
Die Arbeit stellt ein geometrisches Modell zur Signalortung und Distanzabschätzung in Innenräumen auf Basis von 802.11-Empfangssignalstärken (RSSI) vor. Es wird gezeigt, dass der RSSI-Signalgradient trotz komplexer Gebäudestrukturen, Mehrwegeausbreitung und Materialdämpfung als mathematischer Indikator für die physische Distanz zwischen Sender und Empfänger dient @Montanha_2021[S. 2]. Das Modell begründet die Übersetzung des RSSI-Gradienten in gestufte haptische Vibrationsmuster, um Einsatzkräfte ohne Blickbindung an das Display an den Versteckort des Asservats heranzuführen @Montanha_2021[S. 4].

= Technische Grundlagen <ch:grundlagen>

== Grundlagen der drahtlosen Kommunikation (IEEE 802.11)
Das @WLAN basiert auf den Spezifikationen der IEEE-802.11-Familie. Die Signalübertragung erfolgt über elektromagnetische Funkwellen im 2,4-GHz- sowie im 5-GHz-Frequenzband. In Europa stehen im 2,4-GHz-Band 13 Kanäle (Kanäle 1 bis 13) und im 5-GHz-Band 19 Kanäle (Kanäle 36 bis 140) zur Verfügung. In Deutschland unterliegt ein Großteil der 5-GHz-Kanäle der @DFS, weshalb Aussendungen bei der Erkennung vorrangiger Radarsignale gesetzlich unterdrückt werden müssen @bnetzA_vfg136_2022[S. 3]. Die Ausnutzung dieses Steuerungsmechanismus zur Reduktion der zu scannenden Kanäle wird im #link(<ch:fazit>)[Fazit] erörtert.

Innerhalb des 802.11-Standards unterscheidet das Übertragungsprotokoll zwischen Daten-, Steuer- und Management-Rahmen. Für die passive Signalanalyse sind insbesondere die unverschlüsselten Management-Rahmen von zentraler Bedeutung. Mobilgeräte nutzen beim aktiven Scanning unverschlüsselte Probe Request Frames, um automatisch nach verfügbaren Funknetzwerken in ihrer Umgebung zu suchen @Mishra_2023[S. 1]. Im Rahmenkopf (Header) dieser Probe Requests wird die Quell-@MAC[]-Adresse des aussendenden Geräts unverschlüsselt übertragen @Waltari_2018[S. 208]. Diese physikalische Adresse dient der entwickelten Systemarchitektur als primärer Identifikator zur Erfassung und Abgrenzung aktiver Geräte im Raum.

== Wi-Fi-Sniffing und Betriebsmodi der Funkhardware
Wi-Fi-Sniffing bezeichnet das passive Erfassen von 802.11-Rohdatenrahmen aus dem Funkmedium ohne aktive Netzwerkverbindung @Li_2020[S. 129225], @Prasad_2021[S. 152409]. Im Monitor-Modus empfängt der Funkadapter unverschlüsselte Rahmen auf der eingestellten Frequenz und leitet deren Steuer- und Identifikationsparameter an die Verarbeitungssoftware weiter @Li_2020[S. 129225]. Eine Funknetzwerkkarte kann in verschiedenen Betriebsmodi betrieben werden, die sich bezüglich der Hardware-Filterung empfangener Pakete unterscheiden.

#figure(
  table(
    columns: (1.3fr, 2fr, 2.1fr),
    align: (left, left, left),
    [*Betriebsmodus*], [*Funktion*], [*Relevanz für die Signalanalyse*],
    [Managed Mode],
    [Filtert alle Pakete heraus, deren Ziel-MAC nicht der eigenen Adresse entspricht.],
    [Ungeeignet für die Passiverfassung fremder Geräte.],

    [Promiscuous Mode],
    [Empfängt sämtliche Datenrahmen des Netzwerks, mit dem die Karte verbunden ist.],
    [Eingeschränkt (erfordert Kopplung mit einem @AP).],

    [Monitor Mode],
    [Deaktiviert jegliche Paketfilterung. Lauscht rein passiv auf allen 802.11-Rohrahmen.],
    [Zwingend erforderlich für das passive Signalsniffing.],
  ),
  caption: [Vergleich der Betriebsmodi von WLAN-Netzwerkadaptern],
) <tab:betriebsmodi>

Für den passiven Sensor-Knoten eignet sich ausschließlich der Monitor Mode, da nur dieser Modus 802.11-Management-Rahmen ohne Netzwerkkopplung empfängt @Prasad_2021[S. 152409]. In den Hardware- und API-Dokumentationen von Espressif Systems werden die Begriffe Promiscuous Mode und Monitor Mode begrifflich synonym verwendet, wobei beide Bezeichnungen den in dieser Arbeit definierten, ungefilterten Monitor-Modus beschreiben @Espressif_esp32.

== Struktur der MAC-Adresse
Die @MAC[]-Adresse dient als eindeutige physische Kennung einer Netzwerkschnittstelle auf der Datensicherungsschicht des OSI-Referenzmodells @Martin_2017[S. 365]. Eine Standard-IEEE-802.11-@MAC[]-Adresse besteht aus 48 Bits (6 Oktetten), dargestellt in hexadezimaler Form (z.~B. `01:C3:F0:67:2D:CE`).

#figure(
  image("assets/mac_struktur.svg", width: 85%),
  caption: [Aufbau einer 48-Bit IEEE 802.11 MAC-Adresse mit OUI, NIC und Steuerungsbits. Modifiziert nach #cite(<Martin_2017>, form: "prose", supplement: [S. 366])],
) <fig:mac-struktur>

Die mathematische Struktur unterteilt sich in den @OUI (erste 24 Bits), welcher von der IEEE an Hardwarehersteller vergeben wird, und die *NIC-Identifier* (verbleibende 24 Bits), die als individuelle Seriennummer dienen @Martin_2017[S. 366]. Im ersten Byte signalisiert Bit 1 den Adressierungstyp. Eine `0` kennzeichnet eine @UAA, während eine `1` eine @LAA ausweist @Martin_2017[S. 366].

== MAC-Randomisierung
Um die Erstellung von Bewegungsprofilen durch passive Funk-Sniffer zu verhindern, führten Betriebssystemhersteller wie Apple, Google und Microsoft Mechanismen zur automatischen @MAC[]-Adressen-Randomisierung bei Umgebungsscans ein @Apple_2021. Hierbei generiert das Gerät temporäre @MAC[]-Adressen mit gesetztem LAA-Bit (Bit 1 = `1`), um die echte UAA-Hardwareadresse zu verschleiern @Martin_2017[S. 365].

Für die Anwendung bei polizeilichen Durchsuchungsmaßnahmen ist die zeitliche Frequenz dieser Randomisierung entscheidend @Pronello_2025[S. 96]. Die Wechselintervalle temporärer @MAC[]-Adressen betragen bei den meisten mobilen Betriebssystemen im inaktiven Scan-Zustand über eine Stunde @Pronello_2025[S. 96] @Prasad_2021[S. 152410]. Daraus leitet sich für den zeitlich begrenzten Durchsuchungseinsatz (ca. 30 bis 60 Minuten Dauer) die praxisgerechte Annahme ab, dass jede erfasste temporäre @MAC[]-Adresse für die Dauer der Maßnahme genau ein physisch im Raum vorhandenes Endgerät repräsentiert @Pronello_2025[S. 96] @Prasad_2021[S. 152410].

== RSSI (Signalstärkeindikation)
Der @RSSI ist ein vom Empfängerchip bereitgestellter Wert der empfangenen Hochfrequenzleistung @Prasad_2021[S. 152409]. Dieser Wert wird während der Präambel-Erfassung im analogen Empfangspfad des HF-Front-Ends ermittelt und dient dem Empfänger zur automatischen Verstärkungsregelung. Die Umrechnung der empfangenen Signalleistung $P_r$ in Milliwatt in die logarithmische Einheit dBm erfolgt nach der Standardbeziehung:

$ "RSSI"_"dBm" = 10 dot log_10 ( P_r / (1 "mW") ) $

Zur mathematischen Beschreibung der entfernungsabhängigen Signalabschwächung in geschlossenen Räumen wird in der Literatur das empirische Log-Distance-Path-Loss-Modell herangezogen @Montanha_2021[S. 2] @Sundar_2020[S. 3]:

$ "RSSI"(d) = "RSSI"(d_0) - 10 dot n dot log_10 ( d / d_0 ) + X_sigma $

Dabei bezeichnet $d$ die Distanz zwischen Sender und Sensor, $d_0$ die Referenzdistanz (1 Meter), $n$ den umgebungsabhängigen Pfadverlustexponenten ($n=2$ im Freiraum, $n=3$ bis $n=5$ in Innenräumen) und $X_sigma$ eine gaußverteilte Zufallsvariable für Abschattungseffekte (Shadowing) @Montanha_2021[S. 2] @Sundar_2020[S. 3].

In realen Gebäuden schwächen Baumaterialien das Signalfeld unterschiedlich stark ab. Leichtbau-Trockenbauwände dämpfen das Signal um 2 dB bis 4 dB, Ziegelmauerwerk um 5 dB bis 8 dB und massive Stahlbetondecken um 12 dB bis 22 dB @Sundar_2020[S. 3]. Der menschliche Körper bewirkt durch seinen Wassergehalt eine Abschattung von 3 dB bis 6 dB @Georgievska_2019[S. 5].

== ESP32 (Hardware)
Ein Mikrocontroller ist ein kompaktes @SoC, welches @CPU, @RAM, Flash-Speicher sowie Peripherieschnittstellen auf einem einzelnen integrierten Schaltkreis vereint. Im Gegensatz zu vollwertigen Einplatinencomputern zeichnen sich Mikrocontroller durch einen geringen Energiebedarf, minimale Systemstartzeiten sowie eine deterministische Hardwareansteuerung aus.

Die ESP32-Serie umfasst 32-Bit-Mikrocontroller mit integrierten Wi-Fi- und Bluetooth-Transceivern sowie Hardware-Timern @Espressif_esp32. Sie unterstützen den Promiscuous- und Monitor-Modus der Funkhardware und bilden die Basis des entwickelten Sensors @Espressif_esp32.

== Rust & Flutter (Software)
Rust ist eine moderne Systemprogrammierungssprache, die durch ihr striktes Eigentumskonzept (Ownership) und ihr Typsystem garantierte Speichersicherheit zur Kompilierzeit bietet @Rust_docs_description. Im eingebetteten Bereich ermöglicht Rust unter Verwendung der @no_std[]-Direktive die Erstellung hochperformanter Bare-Metal-Firmware ohne Betriebssystem-Overhead und ohne Garbage Collector @Espressif_nostd. Als Bare-Metal-Firmware wird dabei Software bezeichnet, die direkt auf der physischen Mikrocontroller-Hardware ausgeführt wird, ohne auf ein Betriebssystem angewiesen zu sein. Häufige Ursachen von Systemabstürzen, wie etwa Null-Pointer-Dereferenzierungen, Pufferüberläufe oder Data Races, werden dadurch bereits vor der Ausführung konstruktionsbedingt ausgeschlossen @Espressif_nostd.

Flutter nutzt eine reaktive Softwarearchitektur und ermöglicht den Zugriff auf die @BLE[]-Schnittstellen des Mobilgeräts @Flutter_docs_description.

Die Rust-Firmware auf dem ESP32 übernimmt das Sniffing von 802.11-Rohpaketen und das Datastreaming via @BLE. Die Flutter-Applikation empfängt die Messwerte, filtert den RSSI-Gradienten und steuert das haptische Feedback.

= Anforderungsanalyse <ch:anforderungsanalyse>

== Polizeilicher Einsatzkontext und Rahmenbedingungen
Polizeiliche Durchsuchungsmaßnahmen zur Auffindung und Sicherstellung digitaler Asservate finden im Ermittlungsdienst unter anspruchsvollen operativen, zeitlichen und rechtlichen Rahmenbedingungen statt. Die vollstreckenden Einsatzkräfte stehen vor Ort regelmäßig unter erheblichem zeitlichen Handlungsdruck. Bei verdunkelungsgefährdeten Lagen besteht stets das konkrete Risiko, dass Beschuldigte oder externe Akteure über bestehende Datenverbindungen Fernlöschbefehle (Remote Wipes), automatisierte Skripte oder verschlüsselte Löschroutinen an aktive Zielgeräte übermitteln, sobald das Betreten des Objekts bemerkt wird. Die räumlichen Einsatzumgebungen zeichnen sich zudem durch eine hohe Varianz und Komplexität aus. Sie reichen von unübersichtlichen, stark verschachtelten Mehrzimmerwohnungen über mehrgeschossige Gewerbekomplexe bis hin zu verwinkelten Keller- und Werkstattarealen mit starken elektromagnetischen Abschirmungen durch Bau- und Isolierstoffe.

Aus IT-forensischer Sicht erfordert das Vorgehen am Durchsuchungsort ein absolut nicht-invasives Handeln. Das einzusetzende technische Instrumentarium sollte nach IT-forensischen Grundsätzen nicht aktiv in bestehende Funknetzwerke eingreifen, eigene Datenpakete in das Funkmedium injizieren oder eigenständig Verbindungsanfragen an Zielgeräte aussenden. Jegliche aktive Hochfrequenz-Interaktion birgt das Risiko, beweisrelevante Systemzustände auf den Zielasservaten unumkehrbar zu verändern oder anti-forensische Schutzmechanismen auszulösen. Zugleich wird hohe Diskretion gefordert. Das Messsystem soll ein unauffälliges, kompaktes Äußeres aufweisen, um Außenstehenden keine Rückschlüsse auf die angewandte Ermittlungstaktik zu ermöglichen. Für die Integration in den Einsatzablauf muss das System ohne zeitaufwendige Konfigurationsschritte innerhalb von wenigen Sekunden nach dem Einschalten betriebsbereit sein.

Die Eigensicherung der durchsuchenden Kräfte besitzt während des gesamten Einsatzes oberste Priorität. Die Nutzung technischer Hilfsmittel darf die visuelle Aufmerksamkeit des Anwenders nicht binden, um eine kognitive Überlastung oder das Entstehen eines gefahrträchtigen Blickverlusts zu vermeiden. Aus diesem Grund bildet die haptische Signalvermittlung über abgestufte Vibrationsmuster eine fundamentale Grundanforderung für die Verwendbarkeit im Feld. Das haptische Feedback soll die Einsatzkraft in die Lage versetzen, Räumlichkeiten, Möbelstücke und Baustrukturen systematisch abzusuchen und den Signalstärke-Gradienten zu verfolgen, während der Blick frei im Raum verbleibt und die zweite Hand zur Eigensicherung einsatzbereit gehalten werden kann.

== Datenschutzanforderungen
Ein zentrales Fundament der Systemkonzeption soll das Prinzip der lokalen Datenhoheit bilden. Sämtliche vom ESP32-Sensor zu erfassenden 802.11-Metadaten sollen über eine direkte @BLE[]-Verbindung ausschließlich an das gekoppelte Smartphone der Einsatzkraft übertragen werden. Das System muss vollständig autark und isoliert von externen Netzwerkinfrastrukturen arbeiten. Es dürfen zu keinem Zeitpunkt Datenübertragungen an externe Server, Cloud-Dienste oder Plattformen von Drittanbietern stattfinden. Es muss gewährleistet sein, dass die Kontrolle über alle empfangenen Signaldaten zu jedem Zeitpunkt uneingeschränkt bei den vollstreckenden Einsatzkräften vor Ort verbleiben.

Im Sinne des datenschutzrechtlichen Gebots der Datensparsamkeit und Verhältnismäßigkeit soll sich die Datenerhebung auf das technisch absolut erforderliche Minimum beschränken. Die zu entwickelnde Sensor-Firmware soll aus den abgefangenen Probe Request Frames gezielt sowohl die unverschlüsselte Quell-@MAC[]-Adresse als auch die Empfänger-@MAC[]-Adresse aus dem Paketkopf ermitteln und zusammen mit dem vom Empfängerchip gemessenen @RSSI bereitstellen. Es dürfen keinerlei Nutzdaten, Anwendungsinhalte, IP-Adressen oder private Netzwerkkennungen ausgewertet oder verarbeitet werden. Die Erfassung soll rein dem physikalischen Auffinden von Funksendern im Raum dienen und den Zugriff auf schützenswerte Kommunikationsinhalte konstruktionsbedingt ausschließen.

Ebenso soll die Architektur ein striktes Zero-Logging-Prinzip mit flüchtiger Speicherung verfolgen. Sämtliche während einer Suchmaßnahme erfassten Quell- und Ziel-@MAC[]-Adressen sowie Signalverläufe sollen ausschließlich im @RAM der Geräte gehalten werden, um den Live-Gradienten zu berechnen und das haptische Feedback zu steuern. Nach dem Beenden der Suchanwendung oder dem Ausschalten des Mikrocontrollers sollen alle temporär gehaltenen Sitzungsdaten unverzüglich und rückstandslos gelöscht werden. Es dürfen keine dauerhaften Aufzeichnungen auf nicht-flüchtigem Speicher hinterlassen werden, was den Schutz unbeteiligter Personen in der Funkumgebung gewährleistet.

== Hardwareanforderungen
An die Hardware-Komponenten des Gesamtsystems werden spezifische funktionale und ergonomische Anforderungen gestellt. Das zu konzipierende Sensor-Modul erfordert eine Mikrocontroller-Einheit, die das passive Abfangen von 802.11-Management-Rahmen im Monitor-Modus sowohl im 2,4-GHz- als auch im 5-GHz-Frequenzband unterstützt. Bei einer vergleichenden Betrachtung der im Markt befindlichen @ESP32[]-Modellreihen von Espressif Systems zeigt sich, dass frühere Generationen (wie der ESP32-C3, ESP32-S3 oder ESP32-C6) ausschließlich das 2,4-GHz-Spektrum abdecken @Espressif_esp32. Die neu entwickelte @ESP32[]-C5-Serie stellt derzeit die einzige Hardwareoption innerhalb der Produktfamilie dar, die nativerweise Dual-Band-Funktionalität (2,4 GHz und 5 GHz) mit voller Unterstützung für den WLAN-Promiscuous- und Monitor-Modus auf einem einzelnen Chip vereint @Espressif_esp32.

#figure(
  table(
    columns: (1.2fr, 1fr, 1fr, 1.4fr),
    align: (left, left, left, left),
    [*Modell*], [*Taktfrequenz*], [*SRAM*], [*Wi-Fi Standard*],
    [ESP32-C3], [160 MHz], [400 KB], [Wi-Fi 4 (2,4 GHz)],
    [ESP32-S3], [240 MHz], [512 KB], [Wi-Fi 4 (2,4 GHz)],
    [ESP32-C6], [160 MHz], [512 KB], [Wi-Fi 6 (2,4 GHz)],
    [ESP32-C5], [240 MHz], [512 KB], [Wi-Fi 6 (2,4 & 5 GHz)],
  ),
  caption: [Vergleich der ESP32-Mikrocontroller-Serien in chronologischer Reihenfolge],
) <tab:esp32-vergleich>

Aus Erwägungen der praktischen Handhabbarkeit wird für die Visualisierung der Messdaten ein mobiles Endgerät benötigt, das drahtlos mit dem ESP32-Sensor kommuniziert. Ausgehend von aktuellen Ausstattungstrends bei Polizeibehörden soll die physische Integration über eine kombinierte Halterungslösung erfolgen. Eine MagSafe-kompatible Magnetverbindung in Verbindung mit einer integrierten Powerbank soll eine doppelte Funktion erfüllen. Sie fixiert den ESP32-Sensor fest und ergonomisch an der Rückseite des iPhones für eine Ein-Hand-Bedienung und stellt gleichzeitig die kontinuierliche Stromversorgung des Sensors sowie die Laufzeitverlängerung des Smartphones während langwieriger Raumdurchsuchungen sicher. Dadurch bleiben alle Bauteile als kompakte Einheit miteinander verbunden.

== Softwareanforderungen
Aufgrund der Bevorzugung von iPhone-Geräten im polizeilichen Einsatzumfeld muss die zu entwickelnde Mobil-Applikation vollständig kompatibel mit dem Betriebssystem Apple iOS sein und die spezifischen @BLE[]-Schnittstellen (iOS CoreBluetooth Framework) ansprechen können. Um eine nachhaltige und plattformunabhängige Softwarearchitektur zu gewährleisten, wird der Einsatz des plattformübergreifenden Entwicklungs-Frameworks Flutter gefordert @Flutter_docs_description. Dadurch kann die Software primär für iOS bereitgestellt werden, bleibt jedoch ohne grundlegende Quellcode-Anpassungen auch für Android-Systeme einsetzbar.

Auf der Mikrocontroller-Seite wird eine deterministische Bare-Metal-Firmware gefordert, die in der Systemprogrammiersprache Rust unter Nutzung der @no_std[]-Direktive zu erstellen ist @Espressif_nostd. Die Software muss frei von Betriebssystem-Overhead arbeiten, um eintreffende 802.11-Rohpakete im Interrupt-Kontext ohne Pufferüberläufe zu verarbeiten.

Das Kommunikationsprotokoll zwischen Sensor und Smartphone muss als @BLE[]-@GATT[]-Server konzipiert werden, welcher eine erweiterte @MTU[]-Aushandlung (bis zu 247 Byte) unterstützt. Dadurch sollen extrahierte Datenpakete (bestehend aus Quell-@MAC[]-Adresse, Ziel-@MAC[]-Adresse und @RSSI[]-Wert) in Batches zusammengefasst und verlustfrei via @GATT[]-Notifications gestreamt werden. Auf dem Smartphone muss die Applikation die eintreffenden RSSI-Signale in Echtzeit digital filtern und den Signal-Gradienten latenzarm (unter 300 ms) in eine dynamische Verlaufsdarstellung der Signalstärke sowie haptische Vibrationssignale für den Anwender übersetzen.

Als funktionale Erweiterung wird gefordert, dass die Anwendungssoftware anhand der ermittelten @MAC[]-Adresse automatisch den jeweiligen Hardware-Hersteller bestimmen kann. Hierzu soll die Mobil-Applikation aus dem ersten 3-Byte-Block der Adresse den @OUI extrahieren und mit einer lokal integrierten Hersteller-Datenbank abgleichen. Dadurch wird den Einsatzkräften direkt in der Benutzeroberfläche der herstellerspezifische Klartextname (wie beispielsweise Apple, Samsung, Google oder Espressif) angezeigt, um die Zuordnung und Unterscheidung aktiver Funkgeräte am Durchsuchungsort zu unterstützen @Martin_2017[S. 366].

Ebenso soll die Benutzeroberfläche der Mobil-Applikation ein historisches Zeitverlaufsdiagramm zur Signalstärkenanalyse bereitstellen. Für jedes fokussierte Zielgerät soll die Software die empfangenen @RSSI[]-Messwerte auf der y-Achse über der zeitlichen x-Achse in Form eines dynamischen Graphen visualisieren, wie in @fig:app-tracking dargestellt. Diese Verlaufsdarstellung soll es der Einsatzkraft ermöglichen, die zeitliche Entwicklung und historische Signalstärkenveränderung wie Signalamplituden, Spitzenwerte und Pegelabfälle während der Raumdurchsuchung nachzuvollziehen. Dadurch kann der Anwender rückwirkend transparent analysieren, zu welchem Zeitpunkt und in welchem Bereich des Objekts das Funksignal des gesuchten Asservats am stärksten empfangen wurde.

Für die gezielte Abgrenzung relevanter Zielgeräte in stark frequentierten Funkumgebungen wird zudem eine selektive MAC-Adressfilterung gefordert. Die Mobil-Applikation muss sowohl einen Empfänger-@MAC[]-Adressfilter als auch einen Sender-@MAC[]-Adressfilter bereitstellen. Der Empfänger-Filter soll es dem Anwender ermöglichen, die Anzeige gezielt auf Funkrahmen zu beschränken, die an eine bestimmte Empfänger-@MAC[]-Adresse (wie etwa die Kennung eines vor Ort vorgefundenen WLAN-Routers) adressiert sind, um stäkeres Hintergrundrauschen und artfremde Funkrahmen aus Nachbarwohnungen effektiv auszublenden. Der Sender-Filter soll wiederum die Isolierung und kontinuierliche Verfolgung der Aussendungen einer einzelnen Quell-@MAC[]-Adresse gestatten.

= Systementwurf und Architektur <ch:architektur>

== Gesamtarchitektur
Aus der #link(<ch:anforderungsanalyse>)[Anforderungsanalyse] leitet sich die Konzeption des Gesamtsystems als entkoppelte Zwei-Schichten-Architektur ab. Die untere Schicht bildet der physische Sensor-Knoten auf Basis des @ESP32[]-C5 Mikrocontrollers, welcher für das zeitkritische Signalsniffing und die Rohdaten-Aufbereitung im Funkmedium zuständig ist @Li_2020[S. 129226]. Die obere Schicht umfasst das Mobilgerät mit der entwickelten Flutter-Applikation, welche die Benutzeroberfläche bereitstellt, die Signalverarbeitung durchführt und das haptische Feedback an die Einsatzkraft ausgibt.

#figure(
  image("assets/gesamtarchitektur.svg", width: 95%),
  caption: [Beziehungsmodell der Gesamtarchitektur zwischen ESP32-Sensor-Knoten und Mobilgerät],
) <fig:gesamtarchitektur>

In @fig:gesamtarchitektur ist die funktionale Aufgabenverteilung zwischen den beiden Systemkomponenten dargestellt.

Der @ESP32[]-C5 Sensor-Knoten agiert als autarke Erfassungseinheit im Raum. Das erste Funktionsmodul beinhaltet das 802.11 Monitor-Mode Sniffing, welches den passiven Empfang von Funkrahmen im 2,4-GHz- und 5-GHz-Frequenzband durchführt. Das zweite Modul steuert das Kanal-Hopping mit einer automatisierten Umschaltung und einer Verweilzeit von 100 ms pro Kanal. Als drittes Modul übernimmt das Frame Header Parsing die gezielte Extrahierung der Quell-@MAC[]-Adresse, der Ziel-@MAC[]-Adresse sowie des empfangenen @RSSI[]-Wertes. Das vierte Modul bildet der @BLE[]-@GATT[]-Server, welcher die drahtlose Bluetooth-Verbindung zum Smartphone bereitstellt.

Das Mobilgerät mit der entwickelten Flutter-Applikation dient als Steuerungs- und Auswerteeinheit für die Einsatzkräfte. Der integrierte @BLE[]-Client empfängt und parst den eintreffenden Datenverkehr vom Sensor. Die nachgelagerte Signalverarbeitung bereitet die empfangenen @RSSI[]-Werte für die visuelle Anzeige auf. Das Modul zur @OUI[]-Auflösung gleicht die Adressköpfe ab, um potenzielle Hardware-Hersteller direkt in der Anwendung darzustellen @Martin_2017[S. 366]. Abschließend generiert das Modul für haptisches Feedback dynamische Vibrationsmuster auf Basis der aktuellen Signalstärke, um den Anwender bei der Raumdurchsuchung intuitiv zu leiten.

== Hardwarearchitektur
Die Hardwarearchitektur konzentriert sich auf die innere Funktionslogik der auf dem @ESP32[]-C5 Mikrocontroller ausgeführten Bare-Metal-Firmware. Der funktionale Ablauf wird über ein Eingabe-Verarbeitungs-Ausgabe-Modell (EVA-Modell) strukturiert, wie in @fig:hardwarearchitektur-io dargestellt.

#figure(
  image("assets/hardwarearchitektur_io.svg", width: 95%),
  caption: [Eingabe-Verarbeitungs-Ausgabe-Modell der Hardware- und Firmware-Architektur des ESP32-Sensors],
) <fig:hardwarearchitektur-io>

Der Verarbeitungsablauf der Hardware-Firmware gliedert sich in drei aufeinander abgestimmte Phasen.

1. *Eingaben (Inputs)*: Die primäre Eingabe bilden die unverschlüsselten 802.11-Elektromagnetiksignale (Probe Request Management Frames) aus der Funkumgebung. Als zweite Eingabe dient ein interner Hardware-Timer, welcher im 100-ms-Takt die Impulssignale zur Kanalumschaltung bereitstellt. Über die Funkschnittstelle nimmt das System zudem @BLE[]-Kontrollbefehle entgegen, darunter die @MTU[]-Aushandlung des Mobilgeräts.

2. *Firmware-Verarbeitung (Processing)*: Die Kernverarbeitung auf dem ESP32-C5 ist in drei getrennte Operationsblöcke unterteilt. Der erste Block umfasst die Paketfilterung für @MAC und @RSSI, welche eintreffende Rahmen im Monitor Mode analysiert und Quell-@MAC[]-Adresse, Ziel-@MAC[]-Adresse sowie Signalstärke isoliert. Der zweite Block steuert das Multiband Kanal-Hopping mit automatisierten Frequenzwechseln über das 2,4-GHz- und 5-GHz-Spektrum. Der dritte Block beinhaltet die @BLE[]-@GATT[]-Serververwaltung zur Aufrechterhaltung der Verbindungsbereitschaft, Steuerung der Endpoints und Verwaltung des Datendurchsatzes.

3. *Ausgaben (Outputs)*: Als Resultat der Verarbeitung stellt die Firmware zwei Hauptausgaben bereit. Dazu zählen die extrahierten Paketdaten in Form strukturierter Datensätze sowie der gefilterte @BLE[]-@GATT[] Notification Stream zur drahtlosen Übertragung an die Smartphone-App.

Während klassische EVA-Modelle in der Regel eine dedizierte Speicherungsschicht zur dauerhaften Datenhaltung umfassen, wird auf eine solche Komponente im vorliegenden Entwurf bewusst verzichtet. Da sämtliche verarbeiteten Messdaten im Sinne des Datenschutzkonzepts ausschließlich im @RAM vorgehalten werden, ist eine dauerhafte Speicherungsschicht auf dem Sensor-Knoten konstruktionsbedingt nicht vorhanden. Durch die volatile Datenhaltung führt jede Trennung der Energieversorgung zu einer unmittelbaren Löschung aller verarbeiteten Funkdaten auf dem Mikrocontroller.

== Softwarearchitektur
Die Softwarearchitektur beschreibt die Struktur und den inneren Datenfluss der mobilen Flutter-Applikation auf dem Smartphone der Einsatzkraft. Auch das Softwarekonzept folgt einer klaren Eingabe-Verarbeitungs-Ausgabe-Gliederung, wie in @fig:softwarearchitektur-io schematisch gezeigt.

#figure(
  image("assets/softwarearchitektur_io.svg", width: 95%),
  caption: [Eingabe-Verarbeitungs-Ausgabe-Modell der Softwarearchitektur der mobilen Flutter-Applikation],
) <fig:softwarearchitektur-io>

Die Verarbeitungslogik der mobilen Software gliedert sich in folgende Systemkomponenten.

1. *Eingaben (Inputs)*: Als kontinuierlicher Dateneingang dient der über @BLE empfangene @GATT Notification Stream mit den gebündelten Rohdatenpaketen. Ergänzend verarbeitet die Applikation Benutzereingaben über die Touch-Oberfläche zur Auswahl des aktiven @ESP32[]-Sensors sowie zur Steuerung und Konfiguration der Tracking-Funktionen.

2. *App-Verarbeitung (Processing)*: Die Kernverarbeitung der Mobil-Applikation umfasst drei Hauptschritte. Die De-Serialisierung zerlegt die eintreffenden Datenpakete im Speicher. Das digitale @RSSI[]-Filter berechnet geglättete Signal-Gradienten und speichert historische Amplituden im Zeitverlaufspuffer. Die @OUI[]-Herstellerauflösung ermittelt über den ersten 3-Byte-Block der Quell-@MAC[]-Adresse den zugehörigen Hardware-Hersteller @Martin_2017[S. 366].

3. *Speicherung (Storage)*: Im Gegensatz zum Sensor-Knoten verfügt die Softwarearchitektur auf dem Smartphone über eine dedizierte Speicherungsschicht. Diese umfasst die lokal auf dem Endgerät hinterlegte @OUI[]-Hersteller-Datenbank. Die Zuweisungstabelle wird bei Systemstart eingelesen und lokal im Anwendungsspeicher vorgehalten, um eine verzögerungsfreie Herstellerauflösung im Feld zu gewährleisten.

4. *Ausgaben (Outputs)*: Die Software stellt zwei primäre Ausgabekanäle bereit. Die visuelle Ausgabe erfolgt über den dynamischen @RSSI[]-Zeitverlaufsgraphen zur historischen Amplitudenanalyse. Die haptische Ausgabe liefert abgestufte Vibrationsmuster und haptische Signale zur blickfreien Orientierung der Einsatzkraft.

== Interkommunikationsablauf
Zur Detaillierung des Zusammenspiels zwischen der physischen Hardware und der mobilen Software beschreibt das Interkommunikationsmodell den dynamischen Datenaustausch über die @BLE Schnittstelle. @fig:interkommunikationsdiagramm stellt diesen zeitlichen Ablauf in Form eines Sequenzdiagramms dar.

#figure(
  image("assets/interkommunikationsdiagramm.svg", width: 70%),
  caption: [Sequenzdiagramm der Interkommunikation zwischen ESP32-C5 Sensor-Knoten und Mobiltelefon],
) <fig:interkommunikationsdiagramm>

Der Kommunikationsprozess gliedert sich in drei aufeinanderfolgende Abschnitte.

1. *Initialisierung und Verbindungsaufbau*: Nach dem Systemstart sendet der @ESP32[]-C5 Sensor in einer kontinuierlichen Schleife @BLE[]-Advertising-Pakete aus, um seine Bereitschaft zu signalisieren. Das Mobilgerät erkennt den Broadcast, sendet eine Verbindungsanfrage und baut die Kommunikationsverbindung mit dem Sensor auf.

2. *Kontinuierliche GATT-Datenübertragung*: Während der aktiven Raumdurchsuchung erfasst der Mikrocontroller passiv Funkrahmen im Monitor Mode und übermittelt die gefilterten Metadaten des WLAN-Verkehrs fortlaufend über @GATT[]-Notifications an das Mobiltelefon. Die Anwendung verarbeitet die eintreffenden Daten in Echtzeit zur Aktualisierung des Verlaufsgraphen sowie der haptischen Rückmeldung.

3. *Verbindungsabbruch*: Nach Beendigung der Durchsuchungsmaßnahme wird der reguläre Verbindungsabbruch durch die Mobil-Applikation initiiert. Erfolgt der Abbruch unvorhergesehen, etwa durch ein abruptes Ausschalten des Mobilgeräts oder den Verlust der Funkabdeckung ohne ordnungsgemäßen Abmeldehandshake, erkennt der @ESP32[]-Sensor-Knoten diesen Zustand über ein internes @BLE[]-Supervision-Timeout und wechselt automatisch zurück in den betriebsbereiten Advertising-Zustand.

= Implementierung <ch:implementierung>

== Physischer Aufbau
Der physische Aufbau des Hardware-Prototyps umfasst die Auslegung des Mikrocontroller-Boards, die Integration der mobilen Stromversorgung sowie die mechanische und elektrische Kopplung der Komponenten an ein Apple iPhone 14 Pro.

=== Mikrocontroller-Board und Platinengeometrie
@fig:esp32-coin zeigt das eingesetzte @ESP32[]-C5 Development Kit im direkten Größenvergleich mit einer 1-Euro-Münze.

#figure(
  image("assets/ESP32NextToCoin.png", width: 55%),
  caption: [ESP32-C5 Development Kit im Größenvergleich mit einer 1-Euro-Münze],
) <fig:esp32-coin>

Das Development Board nutzt den @ESP32[]-C5 Dual-Band-@SoC von Espressif Systems. Die Platine misst 51,5 mm $times$ 25,5 mm bei einer Höhe von 4,5 mm. Auf dem Substrat sind der 32-Bit RISC-V Single-Core-Prozessor (240 MHz Taktfrequenz), 512 KB SRAM sowie 4 MB SPI-Flash-Speicher integriert @Espressif_c5_datasheet. Das HF-Front-End speist eine aufgedruckte 2,4/5-GHz-MIMO-Leiterplatten-Mäander-Antenne, welche den simultanen Empfang auf beiden Frequenzbändern ohne externe Stabantennen ermöglicht @Espressif_c5_datasheet. Die Strom- und Datenschnittstelle wird über einen integrierten USB-C-UART-Brückenbaustein bereitgestellt. Im Größenvergleich mit der dargestellten 1-Euro-Münze (Durchmesser 23,25 mm) wird deutlich, dass der Flächenbedarf des Mikrocontrollers geringer ausfällt als das Gehäuse der mobilen Stromversorgung (siehe @fig:powerbank-next-phone).

=== Energieversorgung und MagSafe-Kopplung
Als mobile Stromversorgung kommt die in @fig:powerbank-next-phone gezeigte Anker Nano Power Bank (5K, MagGo, Slim) zum Einsatz @Anker_MagGo_Slim.

#figure(
  image("assets/PowerbankNextToPhone.png", width: 60%),
  caption: [Anker Nano MagGo Slim Powerbank neben dem iPhone 14 Pro],
) <fig:powerbank-next-phone>

Die Akku-Einheit besitzt eine elektrische Nennkapazität von 5.000 mAh (18,5 Wh) bei Abmessungen von 102 mm $times$ 70,6 mm $times$ 8,6 mm und einer Masse von 122 g @Anker_MagGo_Slim. Die Stromabgabe erfolgt wahlweise über den seitlichen USB-C-Port (5 V bei 3 A) oder induktiv über ein integriertes Qi2-Ladefeld mit bis zu 15 W @Anker_MagGo_Slim. An der Rückseite der Akku-Einheit befindet sich ein Magnetring, welcher kompatibel zum MagSafe-Standard von Apple ist.

@fig:powerbank-attached veranschaulicht die flache Bauhöhe der Akku-Einheit im montierten Zustand an der Rückseite des iPhone 14 Pro.

#figure(
  image("assets/PowerbankAttatchedToPhone.png", width: 55%),
  caption: [Flache MagSafe-Befestigung der Powerbank an der Rückseite des iPhone 14 Pro],
) <fig:powerbank-attached>

Durch die magnetische Befestigung haftet die Akku-Einheit zentriert auf der Rückseite des Smartphones. Die Gehäusetiefe von 8,6 mm erweitert das Gesamtprofil nur geringfügig, sodass der Schwerpunkt des Gesamtsystems nahe an der Handfläche des Anwenders verbleibt.

=== Verkabelung und Systemintegration
@fig:whole-setup zeigt das vollständig verkabelte und betriebsbereite Gesamtsystem.

#figure(
  image("assets/WholeSetupConnectedWithCable.png", width: 60%),
  caption: [Vollständiges Gesamtsystem mit verkabeltem ESP32-C5 Sensor-Knoten und iPhone 14 Pro],
) <fig:whole-setup>

Der @ESP32[]-C5 Sensor ist über ein kurzes USB-C-Kabel mit dem Stromausgang der Powerbank verbunden. Das Kabel verläuft dicht am Gehäuserand, um das Verfangen an Hindernissen oder Kleidungsteilen zu verhindern. Eine grün leuchtende Onboard-LED signalisiert die korrekte Spannungsversorgung und den Abschluss der Firmware-Initialisierung. Der Status-Indikator wechselt nach dem Anlegen der Betriebsspannung von einem Blinkmuster in ein dauerhaftes Leuchten, sobald die Peripherietreiber geladen wurden und der @BLE[]-@GATT[]-Server betriebsbereit ist. Die MagSafe-Halterung fixiert den Sensor und die Akku-Einheit als kompakte Baugruppe am iPhone 14 Pro, sodass die Einsatzkraft das Gesamtsystem einhändig führen und bedienen kann.

=== Leistungsaufnahme und Energiebilanz
Die Energiebilanz des Gesamtsystems ergibt sich aus den Leistungsaufnahmen des Mikrocontroller-Boards und den Wandlungsverlusten der mobilen Stromversorgung.

Auf Bauteilebene unterscheidet das Datenblatt des @ESP32[]-C5 getrennte Peak-Stromaufnahmen für die HF-Schnittstellen bei einer Betriebsspannung von 3,3 V. Für Wi-Fi 2,4 GHz RX liegt die Stromaufnahme zwischen 94 mA und 101 mA, für Wi-Fi 5 GHz RX zwischen 120 mA und 128 mA sowie für den BLE-Empfänger bei 85 mA @Espressif_c5_datasheet. Da das interne Time-Division-Coexistence-Verfahren der Firmware die Funkeinheiten im Zeitmultiplex betreibt, treten diese Spitzenströme nicht gleichzeitig auf @Espressif_c5_datasheet. Da das Datenblatt keinen mittleren Stromwert für den kombinierten Dual-Band/BLE-Betrieb angibt, wird für die Gesamtsystembetrachtung ein Planungswert von ca. 200 mA bei 5,0 V an der USB-Schnittstelle des Development Kits angesetzt; dieser berücksichtigt den Duty-Cycle der Funkmodule sowie den Overhead von LDO-Spannungsregler und USB-UART-Brücke. Es handelt sich ausdrücklich um eine eigene Abschätzung, nicht um einen verifizierten Datenblatt- oder Messwert. Daraus ergibt sich eine mittlere Leistungsaufnahme von:

$ P_"ESP32" = U dot I_"ESP32" approx 5,0 "V" dot 0,20 "A" = 1,0 "W" $

Die Anker Nano MagGo Slim Powerbank besitzt laut Hersteller eine Nennkapazität von 5.000 mAh; bei der für diese Zellchemie typischen Spannung von 3,87 V entspricht dies einer Nennenergie von 19,35 Wh, was auch durch unabhängige Messungen bestätigt wird @Anker_MagGo_Slim. Aufgrund von DC-DC-Wandlungsverlusten und induktiven Übertragungsverlusten gibt der Hersteller die real nutzbare Abgabemenge mit ca. 55-65 % der Nennkapazität an, im Folgenden vereinfachend mit dem Mittelwert von 60 % angesetzt @Anker_MagGo_Slim. Die nutzbare Netto-Energie beträgt somit:

$ E_"nutzbar" = 19,35 "Wh" dot 0,60 approx 11,61 "Wh" $

Für den autarken Messbetrieb des @ESP32[]-C5 Sensors resultiert daraus eine kontinuierliche Betriebsdauer von:

$ t_"Sensor" = E_"nutzbar" / P_"ESP32" = (11,61 "Wh") / (1,0 "W") approx 11,6 "Stunden" $

Wird das gekoppelte iPhone 14 Pro während des Durchsuchungseinsatzes zusätzlich simultan über die MagSafe-Schnittstelle geladen (Qi2-Laden mit bis zu $P_"iPhone,MagSafe" = 15,0 "W"$), steigt die Gesamtleistungsaufnahme auf:

$ P_"Kombi,MagSafe" = P_"ESP32" + P_"iPhone,MagSafe" = 1,0 "W" + 15,0 "W" = 16,0 "W" $

Unter dieser Volllast ergibt sich eine kombinierte Mindestlaufzeit von:

$
  t_"Kombi,MagSafe" = E_"nutzbar" / P_"Kombi,MagSafe" = (11,61 "Wh") / (16,0 "W") approx 0,73 "Stunden" approx 44 "Minuten"
$

Dieser Wert ist eine Worst-Case-Abschätzung, da sie durchgehende Ladung mit der jeweiligen Spitzenleistung unterstellt; in der Praxis reduziert die thermische Regelung der Powerbank (Graphenkühlung, NTC-Chips) die Ladeleistung bei steigender Temperatur, sodass die real erzielbare Kombi-Laufzeit tendenziell etwas höher liegt. Zudem ist herstellerseitig nicht spezifiziert, ob die volle Wireless-Ausgangsleistung dauerhaft parallel zum USB-C-Ausgang anliegen kann; die genannten Werte gelten daher als obere Leistungs- bzw. untere Laufzeitgrenze.

Für den polizeilichen Einsatz bedeutet dies, dass die Powerbank primär als ganztägige Stromversorgung für den Sensor-Knoten dient (ca. 11,6 Stunden) und im Bedarfsfall eine gezielte Teilnachladung des iPhone 14 Pro während lokaler Raumdurchsuchungen für ca. 30 bis 45 Minuten ermöglicht (je nach Lademodus), bevor die Kapazität der Powerbank für den kombinierten Betrieb erschöpft ist.


== Mobil-Applikation
Die Benutzeroberfläche der mobilen Flutter-Applikation bildet die zentrale Bedien- und Auswerteeinheit für die Einsatzkräfte vor Ort. Sie verarbeitet die über @BLE empfangenen Funksignale des Sensor-Knotens und bereitet diese für die operative Nutzung auf.

=== Startbildschirm
Das Design der Benutzeroberfläche folgt der visuellen Gestaltungssprache des Bauhaus-Stils, welche auf funktionaler Klarheit, reduzierten geometrischen Formen und hohen Kontrasten basiert. Durch den Verzicht auf dekorative Grafikelemente steht die schnelle Erfassbarkeit der Signaldaten im Vordergrund.

Für den praktischen Einsatz stehen zwei Farbmodi zur Verfügung, wie in @fig:app-homescreen dargestellt.

#figure(
  grid(
    columns: (1fr, 1fr),
    gutter: 12pt,
    image("assets/SCREENSHOT_HOME_LIGHT.PNG", width: 85%), image("assets/SCREENSHOT_HOME_DARK.PNG", width: 85%),
  ),
  caption: [Startbildschirm der Mobil-Applikation im direkten Vergleich zwischen Hellmodus (links) und Dunkelmodus (rechts)],
) <fig:app-homescreen>

Der Dunkelmodus (Dark Mode) ist für Durchsuchungsmaßnahmen in abgedunkelten Objekten optimiert. Er verhindert ungewollte Lichtemissionen des Smartphone-Displays und reduziert die Augenermüdung bei längeren Einsätzen. Der Dunkelmodus eignet sich dadurch besonders für lichtempfindliche Einsatzszenarien. Der Hellmodus (Light Mode) bietet bei heller Umgebungsbeleuchtung maximale Ablesbarkeit.

Auf dem Startbildschirm listet die Anwendung alle erreichbaren @BLE[]-Sensoren in Reichweite auf. Durch Antippen eines gelisteten Geräts stellt die Software die drahtlose Verbindung zum ausgewählten Sensor-Knoten her. Die Schaltfläche für die Einstellungen in der unteren Leiste verfügt über ein dynamisches Hinweissymbol in Form eines orangefarbenen Punkts. Dieses Symbol wird automatisch eingeblendet, wenn die lokal installierte @OUI[]-Hersteller-Datenbank seit mehr als sieben Tagen nicht aktualisiert wurde, um den Anwender an eine Erneuerung des Datenbestands zu erinnern.

=== Hauptanzeige
Nach erfolgreicher Verbindungsherstellung wechselt die Anwendung in die Hauptanzeige, die in @fig:app-overview abgebildet ist.

#figure(
  image("assets/SCREENSHOT_OVERVIEW_LIGHT.PNG", width: 45%),
  caption: [Hauptanzeige der Mobil-Applikation mit Echtzeit-Übersicht erfasster Funkrahmen und MAC-Filteroptionen],
) <fig:app-overview>

In dieser Ansicht konsolidiert die Software die eintreffenden Rohdaten des @ESP32[]-Sensors in eine strukturierte Echtzeit-Übersicht aktiver @WLAN[]-Geräte. Um spezifische Datenströme in dicht belegten Funkumgebungen gezielt zu isolieren, stellt die Benutzeroberfläche zwei dedizierte Filterfunktionen bereit. Über den Empfänger-Filter ("RCV FILTER") lassen sich gezielt Funkrahmen filtern, die an eine bestimmte Zieladresse wie beispielsweise einen vor Ort betriebenen WLAN-Router gerichtet sind. Der Quell-Filter ("TARGET LOCK SELECTOR") ermöglicht wiederum die gezielte Eingrenzung auf die Übertragungen eines konkreten verdächtigen Sendergeräts.

=== RSSI-Zeitverlaufsgraphen
Wählt die Einsatzkraft ein bestimmtes Endgerät aus der Hauptanzeige aus, öffnet sich die in @fig:app-tracking gezeigte Tracking-Detailansicht.

#figure(
  image("assets/SCREENSHOT_TRACKING_LIGHT.PNG", width: 45%),
  caption: [Tracking-Ansicht mit integriertem RSSI-Zeitverlaufsgraphen und automatischer OUI-Herstellerauflösung],
) <fig:app-tracking>

In dieser Ansicht wird die Hauptanzeige um einen dynamischen @RSSI[]-Zeitverlaufsgraphen erweitert. Dieser Graph visualisiert den historischen Verlauf der empfangenen Signalstärke auf der y-Achse über der zeitlichen x-Achse gemäß den im #link(<ch:anforderungsanalyse>)[Anforderungskatalog] definierten Vorgaben. Anhand des Kurvenverlaufs kann die Einsatzkraft Signalspitzen und Abfälle bei der Annäherung an ein Versteck nachvollziehen.

Parallel dazu liest die Verarbeitungslogik den ersten 3-Byte-Block der beobachteten @MAC[]-Adresse aus und gleicht diesen @OUI mit der integrierten Hersteller-Datenbank ab @Martin_2017[S. 366]. Das Ergebnis dieser Auflösung wird als Klartextname des Hardware-Herstellers wie beispielsweise Apple oder Samsung direkt oberhalb des Verlaufsdiagramms eingeblendet, was die Zuordnung des gesuchten Asservats am Durchsuchungsort unterstützt. Kann ein Herstellermodell nicht aufgelöst werden, bleibt das entsprechende Textfeld in der Benutzeroberfläche leer.

=== Einstellungen
Über das Einstellungen-Symbol auf dem Startbildschirm gelangt der Anwender in das Konfigurationsmenü, welches in @fig:app-settings dargestellt ist.

#figure(
  image("assets/SCREENSHOT_SETTINGS_LIGHT.PNG", width: 45%),
  caption: [Konfigurationsanzeige zur Steuerung des haptischen Feedbacks und zur Verwaltung der OUI-Hersteller-Datenbank],
) <fig:app-settings>

== Typsichere Datenstrukturen
Für die drahtlose Datenübertragung zwischen der embedded Rust-Firmware (@no_std[]) auf dem Mikrocontroller und der in Dart verfassten Flutter-Applikation ist ein identisches binäres Speicherlayout der verarbeiteten Datenpakete erforderlich. Abweichungen in der Byte-Reihenfolge (Endianness), der Feldanordnung oder dem Speicher-Alignment würden zu Verfälschungen der empfangenen Messwerte führen.

Zur Vermeidung manueller Übertragungsfehler nutzt das Projekt ein automatisiertes Codegenerierungswerkzeug. Als zentrale Definition dient das in @fig:code-payload-dart dargestellte Datenmodell der Mobil-Applikation, welches die Felder der Datenstruktur mit strukturellen Typanmerkungen versieht.

#code-figure(
  ```dart
  class SnifferPayload {
    // @type: [u8; 6]
    final Uint8List senderMac;
    // @type: [u8; 6]
    final Uint8List receiverMac;
    // @type: i8
    final int rssi;
  }
  ```,
  caption: [Spezifikation der zentralen Datenstruktur in der Mobil-Applikation],
) <fig:code-payload-dart>

Das Generierungsskript liest diese Spezifikation ein und erzeugt automatisch das in @fig:code-payload-rust gezeigte C-kompatible Rust-Struct für die Firmware.

#code-figure(
  ```rust
  #[repr(C, packed)]
  #[derive(Debug, Copy, Clone)]
  pub struct SnifferPayload {
      pub senderMac: [u8; 6],
      pub receiverMac: [u8; 6],
      pub rssi: i8,
  }
  ```,
  caption: [Generierte C-kompatible Datenstruktur in der Mikrocontroller-Firmware],
) <fig:code-payload-rust>

Durch das Attribut `#[repr(C, packed)]` wird sichergestellt, dass das System den Speicher ohne zusätzliche Füllbytes (Padding) anordnet. Das Gesamtpaket belegt somit auf beiden Plattformen exakt 13 Byte, wodurch Byte-Offset-Abweichungen und Padding-Inkompatibilitäten zwischen der Rust-Firmware und der Flutter-Applikation bereits zur Kompilierzeit vermieden werden. Die automatisierte Codegenerierung fungiert dabei als zentrale Single Source of Truth für das Schnittstellenschema.

Ferner folgt die Architektur der Datenverarbeitung dem Software-Entwurfsmuster *„Parse, don't validate“* nach Alexis King @King_2019. Anstatt unstrukturierte Byte-Arrays an verschiedenen Stellen im Quellcode durch verstreute Ad-hoc-Zugriffe und manuelle Offset-Prüfungen zu verarbeiten, wandelt die Mobil-Applikation eintreffende Datenströme direkt an den Systemgrenzen in typisierte Datenstrukturen um. Auf diese Weise wird die Strukturinformation einmalig beim Empfang der Funkdaten im Typsystem verankert und steht im gesamten weiteren Programmablauf typsicher zur Verfügung @King_2019.

== BLE-Kommunikation zwischen Firmware und Mobilgerät
Der Datenaustausch zwischen dem Sensor-Knoten und dem Smartphone basiert auf dem @BLE[]-@GATT[]-Protokoll @Sundar_2020.

Auf Seiten der Mikrocontroller-Firmware initialisiert das System den @BLE[]-Stack, startet das Advertising und stellt einen @GATT[]-Server bereit, wie in @fig:code-ble-firmware skizziert.

#code-figure(
  ```rust
  // Pseudocode Firmware: GATT-Server & Notification-Burst
  let mut ble = BleServer::init("WALLBREAKER")?;

  loop {
      let batch = packet_queue.drain_up_to(18);
      if !batch.is_empty() {
          ble.send_notification(char_handle, &batch)?;
      }
  }
  ```,
  caption: [Pseudocode der GATT-Server-Initialisierung und Notification-Aussendung auf der Firmware],
) <fig:code-ble-firmware>

Der Sensor sammelt erfasste Funkrahmen in einer thread-sicheren Warteschlange. Sobald eine aktive BLE-Verbindung besteht, fasst die Firmware bis zu 18 Pakete à 13 Byte zu einem gemeinsamen Notification-Burst von 234 Byte zusammen @Li_2020[S. 129227].

Auf Seiten der Mobil-Applikation fordert die Anwendung beim Verbindungsaufbau eine erweiterte @MTU von 247 Byte an (`requestMtu(247)`), um eine Fragmentierung der Datenbursts auf der @BLE[]-Protokollschicht zu verhindern @Sundar_2020. Nach dem Abonnieren der @GATT[]-Notification liest die Software die eintreffenden Byte-Ströme im 13-Byte-Raster aus, wie in @fig:code-ble-mobile dargestellt.

#code-figure(
  ```dart
  // Pseudocode Mobile App: BLE-Verbindung & Stream-Parsing
  await device.connect();
  await device.requestMtu(247);

  device.subscribe(charUuid).listen((bytes) {
    for (final packetBytes in chunkBy13(bytes)) {
      final payload = SnifferPayload.fromBytes(packetBytes);
      processPayload(payload);
    }
  });
  ```,
  caption: [Pseudocode des BLE-Verbindungsaufbaus und Notification-Parsings in der Mobil-Applikation],
) <fig:code-ble-mobile>

== Kanal-Hopping-Algorithmus
Da der Hardware-Empfänger zu einem gegebenen Zeitpunkt jeweils nur eine Funkfrequenz verarbeiten kann, wechselt die Firmware den aktiven Empfangskanal in einer kontinuierlichen Schleife.

Die Verarbeitungslogik durchläuft dazu das in @fig:code-channel-hopping dargestellte statische Array `CHANNELS`, welches die Frequenzkanäle im 2,4-GHz- und 5-GHz-Band abdeckt @Li_2020[S. 129226].

#code-figure(
  ```rust
  // Pseudocode Firmware: Frequenzkanal-Hopping
  const CHANNELS: &[u8] = &[
      1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, // 2,4 GHz
      36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136, 140 // 5 GHz
  ];

  for &channel in CHANNELS.iter().cycle() {
      wifi.set_channel(channel)?;
      wait_millis(100); // 100 ms Dwell Time pro Kanal
  }
  ```,
  caption: [Pseudocode des Frequenzkanal-Hopping-Algorithmus der Firmware],
  size: 9.5pt,
) <fig:code-channel-hopping>

Die Verweilzeit (Dwell Time) pro Kanal beträgt im Quellcode exakt 100 ms. Diese Zeitspanne stellt einen messtechnischen Kompromiss dar @Li_2020[S. 129228], @Waltari_2018[S. 210]. Verweilzeiten unterhalb von 50 ms führen aufgrund der erforderlichen Einschwingzeit des physischen Frequenz-Synthesizers beim Umschalten zwischen den Funkbändern zu erhöhten Empfangsverlusten @Waltari_2018[S. 210]. Längere Verweilzeiten über 200 ms erhöhen hingegen das Risiko, Probe-Request-Aussendungen auf den übrigen Kanälen zu versäumen @Li_2020[S. 129228]. Bei einer Verweilzeit von 100 ms benötigt ein vollständiger Durchlauf über alle 32 Frequenzkanäle exakt 3,2 Sekunden, was eine verlässliche Erfassungswahrscheinlichkeit bei moderater Gesamtlatenz gewährleistet @Waltari_2018[S. 211].

== Signalverarbeitung für haptisches Lokalisierungsfeedback
Um die Einsatzkraft bei der Suche nach verborgenen Sendern im Raum zu leiten, verarbeitet die Mobil-Applikation die eintreffenden @RSSI[]-Signalstärkewerte in Echtzeit und wandelt diese in taktile Impulse um @Prasad_2021.

Die in @fig:code-haptic-trigger gezeigte Methode `_triggerLocatorHapticTick(rssi)` steuert die Frequenz und Intensität der haptischen Rückmeldung in Abhängigkeit von der gemessenen Signalstärke:

#code-figure(
  ```dart
  void _triggerLocatorHapticTick(int rssi) {
    final now = DateTime.now();
    if (_lastLocatorHapticTime != null &&
        now.difference(_lastLocatorHapticTime!) < const Duration(milliseconds: 300)) {
      return;
    }
    _lastLocatorHapticTime = now;

    if (rssi >= -40) {
      AppHaptics.heavy();   // Nahbereich: Hohe Impulsintensität
    } else if (rssi >= -60) {
      AppHaptics.medium();  // Mittlerer Abstand: Mittlere Impulsintensität
    } else {
      AppHaptics.light();   // Fernbereich: Subtiler Haptik-Impuls
    }
  }
  ```,
  caption: [Implementierung der abgestuften Haptiksteuerung in der Mobil-Applikation],
) <fig:code-haptic-trigger>

Um eine Überlastung der Sensorik und eine Ermüdung des Bedieners zu vermeiden, begrenzen wir die Auslösefrequenz auf ein Intervall von 300 ms.

Die Haptiksteuerung ist über die zentrale Hilfsklasse `AppHaptics` abstrahiert. Diese prüft vor jeder Ausführung das in den Einstellungen konfigurierbare Flag `AppHaptics.enabled` sowie die Hardware-Verfügbarkeit (`Haptics.canVibrate()`). Über den Plattform-Kanal steuert die Anwendung schließlich die nativen Vibrationsmodule des jeweiligen Betriebssystems an, um der Einsatzkraft eine Blick-freie Orientierung während der Raumdurchsuchung zu ermöglichen @Prasad_2021.










= Evaluation <ch:evaluation>

== Versuchsaufbau
Die praktische Überprüfung des Prototyps erfolgte in zwei unterschiedlichen Testumgebungen. Zum einen wurde eine kontrollierte Versuchsreihe in einem 20 Meter langen, fensterlosen Büroflur mit geschlossenen Türen durchgeführt. Zum anderen wurde das System im Rahmen einer realen polizeilichen Durchsuchungsmaßnahme auf seine Einsatztauglichkeit hin untersucht. Aus Vertraulichkeitsgründen und zum Schutz laufender Ermittlungen wird die Beschreibung der polizeilichen Einsatzmaßnahme in dieser Arbeit abstrahiert dargestellt und nicht durch konkrete Falldaten belegt.

Als Zielgerät für die kontrollierte Messreihe im 20-Meter-Bürogang diente ein Smartphone des Typs Samsung Galaxy S20, welches am Ende des Flurs auf fixer Höhe positioniert wurde. Das Testgerät wurde dabei in einer Höhe von 1,2 Metern positioniert, um Bodenreflexionen zu minimieren und eine konstante Abstrahlcharakteristik während der gesamten Versuchsreihe zu gewährleisten.

== Signalstärkemessungen
Beim kontrollierten Flurtest wurden die empfangenen @RSSI[]-Werte in definierten Distanzen von 0,5 Metern bis 20 Metern systematisch protokolliert. Die ermittelten Werte repräsentieren jeweils das arithmetische Mittel mehrerer Messreihen unter Ausschluss vereinzelter Extremwerte. In @tab:rssi-messungen sind die gemessenen Signalstärken in Abhängigkeit von der Distanz dargestellt.

#figure(
  table(
    columns: (1fr, 1fr),
    align: (center, center),
    [*Entfernung zum Zielgerät (m)*], [*Gemittelter RSSI-Wert (dBm)*],
    [0,5 m], [-27 dBm],
    [2,0 m], [-53 dBm],
    [5,0 m], [-66 dBm],
    [10,0 m], [-78 dBm],
    [20,0 m], [-92 dBm],
  ),
  caption: [Empirisch gemessene RSSI-Werte im 20-Meter-Bürogang],
) <tab:rssi-messungen>

Die Messdaten belegen einen kontinuierlichen Abfall der Signalstärke mit zunehmender Entfernung. Im Nahbereich von 0,5 Metern liegt der Signalpegel bei -27 dBm. Bei einer Distanz von 20 Metern erreicht der Empfangspegel mit ungefähr -92 dBm die Empfindlichkeitsgrenze des Hardware-Empfängers @Li_2020[S. 129227]. Mit steigender Distanz nahm die Varianz der Signalstärken einzelner Funkpakete spürbar zu. Diese Streuung erklärt sich durch Mehrwegeausbreitungen und Signalreflexionen an den Wänden des geschlossenen Flurs @Prasad_2021. Zudem überlagern sich direkt eintreffende und an Wänden reflektierte Funkwellen am Empfänger.

Die beobachtete Pegelabnahme folgt näherungsweise dem logarithmischen Freiraumpfadverlustmodell, wobei die Wände des Flurs eine Wellenleitung begünstigen. Im Grenzbereich ab 15 Metern Entfernung stieg die Verlustrate einzelner Probe Requests moderat an, da schwache Signale im analogen Front-End des @ESP32 unter das Rauschniveau fielen @Li_2020[S. 129227]. Durch den zeitnahen Empfang nachfolgender Pakete blieb die Trendberechnung des RSSI-Gradienten für die Richtungsorientierung jedoch durchgehend stabil.

== Praktische Durchsuchungsmaßnahme
Bei der realen polizeilichen Durchsuchungsmaßnahme befanden sich im Zielobjekt lediglich ein aktiver @WLAN[]-Router sowie ein einzelnes mit diesem Netzwerk verbundenes Endgerät. Aufgrund starker Funküberlagerungen aus umliegenden Wohngebäuden erfasste der Sensor zunächst eine hohe Anzahl artfremder Funkrahmen.

Zur Ausfilterung des Hintergrundrauschens wurde der in der Mobil-Applikation integrierte Empfänger-@MAC[]-Adressfilter aktiviert, welcher im #link(<ch:anforderungsanalyse>)[Anforderungskatalog] gefordert wurde. Der Filter schränkte die Datenanzeige gezielt auf diejenigen Funkrahmen ein, die an die Empfänger-@MAC[]-Adresse des vor Ort identifizierten Routers adressiert waren. Über den kontinuierlichen Signalstärkeanstieg im @RSSI[]-Zeitverlaufsgraphen konnte das gesuchte Endgerät schließlich hinter einem Möbelstück lokalisiert werden. Es handelte sich um einen @WLAN[]-Repeater.

Die integrierte @OUI[]-Herstellerauflösung zeigte bereits vor dem physischen Auffinden des Geräts den Herstellernamen des Repeaters in der Benutzeroberfläche an. Diese Vorabinformation unterstützte die Einsatzkräfte bei der gezielten Suche nach entsprechenden Bauformen im Raum. Es handelte sich dabei um eine nicht-randomisierte MAC-Adresse des Herstellers.

In sämtlichen Feldtests wurden systembedingt auch Funkpakete aus benachbarten Wohnungen mitgeschnitten. Eine exakte geografische Abgrenzung der erfassten Fremdpakete, beispielsweise die Unterscheidung zwischen direkt angrenzenden Nachbarwohnungen und gegenüberliegenden Gebäudeteilen, ist aufgrund der omnidirektionalen Abstrahlcharakteristik der verwendeten Antenne ohne zusätzliche Peilantennen nicht möglich.

== Systemperformanz, Startzeit und Betriebsdauer
Hinsichtlich der Systemperformanz bestätigten die Feldtests eine sehr kurze Rüstzeit. Der @ESP32[]-Mikrocontroller war nach dem Anstecken der Stromversorgung ohne spürbare Verzögerung in der Mobil-Applikation sichtbar und verbindungsbereit. Dieses Verhalten bestätigt das im #link(<ch:anforderungsanalyse>)[Anforderungskatalog] formulierte Kriterium der schnellen Einsatzbereitschaft bei polizeilichen Durchsuchungsmaßnahmen. Nach dem Einschalten benötigte der @ESP32[]-Sensor unter 100 ms zum Aufbau des @BLE[]-Advertisings. Auch nach provozierten Verbindungsabreißen beim Verlassen der Bluetooth-Reichweite stellte die Applikation die Datenverbindung beim erneuten Annähern innerhalb von wenigen Sekunden automatisch wieder her.

Die Stromversorgung über das MagSafe-Powerbank-Modul wies während aller Testreihen eine hohe Stabilität auf. Die Akkulaufzeit wurde in den Tests nicht bis zur vollständigen Entladung ausgereizt, hielt jedoch bei kontinuierlichem Messbetrieb in allen Durchläufen problemlos über 30 Minuten unterbrechungsfrei durch.

== Beobachtungen zur MAC-Adressen-Randomisierung
Während der polizeilichen Einsatzmaßnahme sowie in den Testreihen wurden Endgeräte beobachtet, die privatisierte @MAC[]-Adressen nutzten. Es konnte jedoch festgestellt werden, dass die verwendeten Kennungen während des aktiven Messzeitraums einer Durchsuchung konstant blieben und keine dynamischen Adresswechsel während des Verbindungsaufbaus auftraten.

Der wesentliche Nachteil der aktivierten Adressrandomisierung lag darin, dass bei lokal verwalteten Adressen (Local Bit im OUI gesetzt) der Klartextname des Herstellers nicht über die @OUI[]-Datenbank aufgelöst werden konnte @Martin_2017[S. 366]. Sobald jedoch reguläre Funkrahmen von @AP[]s oder Repeatereinheiten empfangen wurden, funktionierte die Herstellerauswertung zuverlässig.


= Fazit und Ausblick <ch:fazit>

== Zusammenfassung der Ergebnisse
Die Arbeit belegt, dass passive @WLAN[]-Signalanalyse auf Basis kostengünstiger Mikrocontroller-Hardware für polizeiliche Durchsuchungsmaßnahmen praktisch möglich ist. Die Kombination aus einer @no_std Rust-Firmware auf dem @ESP32[]-C5, einer Flutter-Mobil-Applikation und einer MagSafe-Halterung löst die unhandlichen Eigenschaften bisheriger Laptop- und Wireshark-Lösungen im Einsatzdienst. Die Feldtests bestätigen die praktische Eignung des Aufbaus. Durch die Verknüpfung von selektiver MAC-Filterung, visuellem RSSI-Zeitverlaufsgraphen und gestuftem haptischem Feedback ermöglicht der Prototyp die gezielte Ortung verborgener Funkkomponenten wie WLAN-Repeatern im Ein-Hand-Betrieb. Die Anforderungen an Betriebsdauer und Datenschutz werden durch mehr als 30 Minuten Akkulaufzeit im Volllastbetrieb sowie die volatile Datenverarbeitung im @RAM ohne dauerhafte Aufzeichnung erfüllt @Prasad_2021[S. 152408]. Das entwickelte System demonstriert somit die technische und operative Realisierbarkeit einer passiven, blickfreien Funkortung auf Mikrocontroller-Basis.

== Einsatzgrenzen und Kritik
Passive Messverfahren unterliegen physischen und rechtlich-technischen Rahmenbedingungen. Die Detektion setzt voraus, dass das Zielgerät im Funkmedium aktiv sendet. Bei deaktivierter WLAN-Schnittstelle, entladenem Akku oder aktivem Flugmodus erfolgt keine Signalabstrahlung, wodurch das Gerät messtechnisch unsichtbar bleibt @Pronello_2025[S. 82]. Zudem dämpfen massive Baustrukturen wie Stahlbetondecken (12 dB bis 22 dB Dämpfung) oder geschirmte Metallschränke das Funksignal stark ab @Sundar_2020[S. 3].

Bei privatisierten @MAC[]-Adressen verhindert das gesetzte LAA-Bit die Auflösung in der @OUI[]-Herstellerdatenbank, da keine weltweite Herstellerauskunft vorliegt @Apple_2021, @Martin_2017[S. 366]. Da die Wechselintervalle temporärer Adressen bei inaktiven Endgeräten meist über einer Stunde liegen, bleibt die Identität während einer typischen 30- bis 60-minütigen Durchsuchung in der Regel stabil @Martin_2017[S. 368], @Prasad_2021[S. 152412]. Dennoch kann ein Adresswechsel mitten in einer laufenden Durchsuchungsmaßnahme eintreffen, falls das Rotationsintervall des Zielgeräts bereits vor Einsatzbeginn lief. In diesem Fall führt die Adressrotation zu einem scheinbaren Signalverlust der bisher verfolgten @MAC[]-Adresse. Da das Endgerät jedoch kontinuierlich weiter sendet und unter einer neuen zufälligen @MAC[]-Adresse in der Übersicht der Mobil-Applikation erscheint, kann die Einsatzkraft die neu aufgetauchte Adresse auswählen und die Verfolgung fortsetzen. Der funktionale Nachteil beschränkt sich dabei auf den Verlust des bisherigen @RSSI[]-Zeitverlaufsgraphen der vorherigen Adresse. Da der entwickelte Sensor mit einer omnidirektionalen Antenne ausgestattet ist, lässt sich der Einfallswinkel des Signals nicht direkt bestimmen, weshalb die Richtungskontrolle primär über den zurückgelegten Bewegungspfad und den RSSI-Gradienten erfolgt.

== Ausblick auf Serienfertigung
Für die Überführung in den Regeldienst empfiehlt sich die Entwicklung eines maßgeschneiderten @PCB[]. Durch die Integration des @ESP32[]-@SoC, der Ladeschaltung sowie einer gedruckten Richtantenne oder einer ähnlichen Konstruktion auf einer gemeinsamen Leiterplatte lässt sich das Gesamtvolumen reduzieren. Eine gerichtete Antennenstruktur erhöht den Signalgewinn in Blickrichtung der Einsatzkraft und erleichtert die Erfassung schwacher Signale. Ein widerstandsfähiges Gehäuse, beispielsweise aus dem 3D-Druck, mit IP65-Schutzart oder einer ähnlichen Schutzklasse, schützt die Elektronik vor Staub, Spritzwasser und mechanischer Beanspruchung im Dienstgebrauch. Ein kompaktes Gehäusedesign erleichtert dabei das Mitführen des Sensor-Knotens während der Raumdurchsuchung.

== Zukünftige Weiterentwicklungen <sec:weiterentwicklungen>
Vier technische Ansätze bieten Potenzial für künftige Arbeiten:

1. *Multi-Knoten-Triangulation und UWB*: Der synchrone Betrieb mehrerer @ESP32[]-Sensoren ermöglicht die automatische Raumortung über Schnittpunkte von Kreisradien und Pfadverlustmodelle @Montanha_2021[S. 4], @Sundar_2020[S. 3]. Die Integration von #gls("UWB", display: [Ultra-Wideband-Transceivern (UWB)]) erlaubt durch Signallaufzeitmessungen (Time of Flight) eine hochpräzise Ortung im Sub-Meter-Bereich @Mary_2025[S. 333].
2. *Edge-ML De-Randomisierung*: Der Einsatz von Edge-Hardware mit integrierter @NPU ermöglicht die maschinelle Rekonstruktion randomisierter MAC-Adressen in Echtzeit. Algorithmen werten dabei verbleibende @IE im Frame Body, Burst-Muster und Sequenznummern aus, um rotierende temporäre Adressen einem physischen Zielgerät zuzuordnen @Baccichet_2024[S. 2], @CifuentesUrtubey_2024[S. 1668], @PerezHernandez_2024[S. 150860], @Robyns_2017[S. 4], @Uras_2020[S. 3].
3. *Erweiterung auf Wi-Fi 6E und Wi-Fi 7 (6 GHz)*: Da der @ESP32[]-C5 auf das 2,4-GHz- und 5-GHz-Band beschränkt ist @Espressif_c5_datasheet, sichert die künftige Integration von 6-GHz-Transceivern die Erfassung moderner WLAN-Standards in neu aufgebauten Netzwerkinfrastrukturen @Waltari_2018[S. 210].
4. *Kanalreduktion durch DFS-Signalsimulation*: Die gezielte Simulation normkonformer Radarsignale auf 5-GHz-Frequenzen veranlasst in der Umgebung aktive @AP[]s zum Ausweichen auf radarseitig unbeflossene Kanäle @bnetzA_vfg136_2022[S. 3]. Dies minimiert die Gesamtzahl der beim Kanal-Hopping aktiv zu scannenden 5-GHz-Kanäle, wodurch sich die effektive Verweilzeit pro verbliebenem Kanal erhöht und die Paket-Erfassungsrate des Sensors steigen könnte.



#heading(level: 1, numbering: none)[Literaturverzeichnis]
#v(-1em)
#text(size: 9pt, style: "italic")[(Letzter Aufruf aller Links & Internetquellen: 31.07.2026)]

#show bibliography: it => box(width: 0pt, height: 0pt, clip: true, it)
#bibliography("literatur.bib", title: none, style: "apa")
#print-bibliography("literatur.bib")


// --- Back Matter ---

#heading(level: 1, numbering: none)[KI-Verzeichnis] <ch:ki>

#figure(
  text(size: 8.5pt)[
    #table(
      columns: (1.1fr, 1.3fr, 0.9fr, 2.2fr),
      align: left,
      [*KI-basiertes Hilfsmittel*], [*Einsatzform*], [*Betroffene Teile der Arbeit*], [*Bemerkungen*],
      [Google Gemini],
      [Umformulierung von Textpassagen],
      [Gesamte Arbeit],
      [Prompt:\ "Ich arbeite derzeit an meiner Bachelorarbeit im Studiengang Informatik. Im Folgenden werde ich dir Textpassagen aus meiner Arbeit zur sprachlichen Überarbeitung bereitstellen. Bitte formuliere diese Absätze in einem präzisen, akademischen Ton um, um die Lesbarkeit und den Sprachfluss zu verbessern. Behalte technische Fachbegriffe sowie Formatierungsbefehle unverändert bei."],
    )
  ],
  caption: [Verzeichnis der verwendeten KI-basierten Hilfsmittel],
) <tab:ki>

#heading(level: 1, numbering: none)[Ehrenwörtliche Erklärung] <ch:erklaerung>

Hiermit versichere ich, dass ich die vorliegende Arbeit in allen Teilen selbstständig angefertigt und keine anderen als die in der Arbeit angegebenen Quellen und Hilfsmittel benutzt habe. Sämtliche wörtlichen oder sinngemäßen Übernahmen und Zitate, sowie alle Abschnitte, die mithilfe von KI-basierten Tools entworfen, verfasst und/oder bearbeitet wurden, sind kenntlich gemacht und nachgewiesen. Im Anhang meiner Arbeit habe ich sämtliche KI-basierte Hilfsmittel angegeben. Diese sind mit Produktnamen und formulierten Eingaben (Prompts) in einem KI-Verzeichnis ausgewiesen.

Ich bin mir bewusst, dass die Verwendung von Texten oder anderen Inhalten und Produkten, die durch KI-basierte Tools generiert wurden, keine Garantie für deren Qualität darstellt. Ich verantworte die Übernahme jeglicher von mir verwendeter maschinell generierter Passagen vollumfänglich selbst und trage die Verantwortung für eventuell durch die KI generierte fehlerhafte oder verzerrte Inhalte, fehlerhafte Referenzen, Verstöße gegen das Datenschutz- und Urheberrecht oder Plagiate.

#v(2cm)

#grid(
  columns: (1fr, 1.2fr),
  gutter: 2cm,
  align(center)[
    #v(1cm)
    #line(length: 100%, stroke: 0.5pt)
    #text(size: 10pt)[Ort, Datum]
  ],
  align(center)[
    #v(1cm)
    #line(length: 100%, stroke: 0.5pt)
    #text(size: 10pt)[Alexander Betke]
  ],
)

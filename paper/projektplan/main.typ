#set page(
  margin: 1.8cm,
)

#set text(
  font: "Liberation Sans",
  size: 10pt,
)

#set table(
  stroke: 0.6pt,
  inset: 5pt,
)

#let weeks = range(22, 32)

= 10-Wochen Projektplan

#table(
  columns: (4.8cm, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr, 1fr),
  align: (left + horizon),

  table.header(
    [*Aufgabe*],
    ..weeks.map(w => [*KW #w*]),
  ),

  [Projektplanung], [⭐], [⭐], [], [], [], [], [], [], [], [],

  [Recherche und Informationssammlung], [], [⭐], [⭐], [], [], [], [], [], [], [],

  [Software-/Hardware-Anforderungsanalyse], [], [], [⭐], [], [], [], [], [], [], [],

  [Implementierung eines Prototypen], [], [], [⭐], [⭐], [⭐], [], [], [], [], [],

  [Zwischenpräsentation], [], [], [], [], [], [⭐], [], [], [], [],

  [Umsetzung von Feedback und Feinschliff des Codes], [], [], [], [], [], [⭐], [⭐], [], [], [],

  [Eventueller Feldtest], [], [], [], [], [], [], [⭐], [], [], [],

  [Finalisierendes Verfassen der Bachelorarbeit], [], [], [], [], [], [], [], [⭐], [⭐], [⭐],

  [Dokumentation meines Fortschrittes], [⭐], [⭐], [⭐], [⭐], [⭐], [⭐], [⭐], [⭐], [⭐], [⭐],
)

= Bemerkungen:
Ich werde während der gesamten Projektzeit regelmäßig meinen Fortschritt dokumentieren (Bilder, Videos und Notizen) um mir dadurch die spätere Verfassung meiner Bachelorarbeit zu erleichtern!

Da das Zwischengespräch/-präsentation in der 4.-6. Woche stattfinden sollte, plane ich die Vorbereitung dafür in meiner 6ten Woche ein. Das gibt mir genug Zeit um die Ergebnisse meiner Implementierung zu präsentieren und Feedback einzuholen, welches ich dann in der 7.-9. Woche umsetzen kann.
Ein klarere Terminierung der Zwischenpräsentation folgt die nächsten Wochen per E-Mail von mir :)

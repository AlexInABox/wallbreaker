#import "@preview/glossarium:0.5.10": gls, make-glossary, print-glossary, register-glossary

#let plain-text(it) = {
  if type(it) == str {
    it
  } else if it == [ ] {
    " "
  } else if it.func() == list or it.func() == enum {
    it.children.map(plain-text).join(" ")
  } else if it.func() == ref {
    str(it.target)
  } else if it.func() == footnote {
    ""
  } else if it.func() == math.equation {
    ""
  } else if it.has("children") {
    it.children.map(plain-text).join("")
  } else if it.has("body") {
    plain-text(it.body)
  } else if it.has("text") {
    it.text
  } else {
    ""
  }
}

#let get-word-count() = {
  let content = read("main.typ")
  let body = if content.contains("= Einleitung") {
    "= Einleitung" + content.split("= Einleitung").at(1)
  } else {
    content
  }

  // Exclude Literature section (from Literaturverzeichnis to KI-Verzeichnis / Ehrenwörtliche Erklärung)
  let body-no-lit = if body.contains("Literaturverzeichnis") {
    let parts = body.split("Literaturverzeichnis")
    let before-lit = parts.at(0)
    let after-lit = parts.slice(1).join("Literaturverzeichnis")
    let after-clean = if after-lit.contains("KI-Verzeichnis") {
      "KI-Verzeichnis" + after-lit.split("KI-Verzeichnis").slice(1).join("KI-Verzeichnis")
    } else if after-lit.contains("Ehrenwörtliche Erklärung") {
      "Ehrenwörtliche Erklärung" + after-lit.split("Ehrenwörtliche Erklärung").slice(1).join("Ehrenwörtliche Erklärung")
    } else {
      ""
    }
    before-lit + after-clean
  } else {
    body
  }

  let lines = body-no-lit.split("\n")
  let count = 0
  let table-depth = 0
  let in-code = false

  for line in lines {
    let trimmed = line.trim()
    if trimmed == "" or trimmed.starts-with("//") {
      continue
    }

    if trimmed.starts-with("```") {
      in-code = not in-code
      continue
    }

    if in-code {
      continue
    }

    let open-parens = trimmed.clusters().filter(c => c == "(").len()
    let close-parens = trimmed.clusters().filter(c => c == ")").len()

    if trimmed.contains("table(") or trimmed.contains("#table(") {
      table-depth += open-parens - close-parens
      if table-depth < 0 { table-depth = 0 }
      continue
    }

    if table-depth > 0 {
      table-depth += open-parens - close-parens
      if table-depth < 0 { table-depth = 0 }
      continue
    }

    // Remove comments
    let clean-line = if trimmed.contains("//") and not trimmed.contains("://") {
      trimmed.split("//").at(0).trim()
    } else {
      trimmed
    }

    // Skip code fence lines
    if clean-line.starts-with("```") {
      continue
    }

    // Clean typst commands/markup
    clean-line = clean-line
      .replace(regex("^=+\\s*"), "")
      .replace(regex("@[A-Za-z0-9_]+"), m => m.text.slice(1))
      .replace(regex("#link\\([^\\)]*\\)\\s*\\[([^\\]]+)\\]"), m => m.text)
      .replace(regex("<[a-zA-Z0-9_:-]+>"), "")
      .replace(regex("\\$[^\\$]+\\$"), "")

    let words = clean-line
      .split(regex("\\s+|\\-|/"))
      .map(w => w.trim("()[]{}.,;:\"'!?`*#"))
      .filter(w => w != "" and not w.starts-with("#") and not w.starts-with("```"))

    count += words.len()
  }

  str(count)
}

#let project(
  documentType: "Praxistransferbericht I/II/III oder Studienprojekt I/II",
  topic: "Titel",
  subtopic: "Untertitel",
  studentName: "Vorname Name",
  matrikelNr: "7220XXXXXXX",
  company: "Unternehmen",
  jahrgang: "20XX",
  fachbereich: "Duales Studium Wirtschaft · Technik",
  studiengang: "Informatik",
  betreuerHS: "(Akademischer Titel) Vorname Name",
  betreuerUnt: "(Akademischer Titel) Vorname Name",
  wordCount: "XXXX",
  pageCount: "XX",
  submissionDate: "07. April 2025",
  logoHWR: "bilder/HWR.png",
  logoCompany: "bilder/FUBIT.png",
  glossary-entries: (),
  body,
) = {
  // 1. Setup layout for the Title Page (no headers/footers)
  set page(
    paper: "a4",
    margin: (top: 2.2cm, bottom: 2.2cm, left: 2.2cm, right: 2.2cm),
    header: none,
    footer: none,
  )

  [#block(width: 100%, breakable: false, [
    #align(center)[
      #v(0.2fr)

      // Subtle non-italic document type at the top
      #text(size: 14pt, weight: "thin", documentType)

      #v(0.5fr)

      // Title in divider lines matching the visual width of the topic text (natural spacing, centered)
      #layout(bounds => {
        context {
          let text-style(body) = text(font: "Times New Roman", size: 18pt, weight: "bold", hyphenate: false, body)

          let raw-text = plain-text(topic)
          let words = raw-text.split(" ")

          let lines = ()
          let current-line = ""
          for w in words {
            let test-line = if current-line == "" { w } else { current-line + " " + w }
            let test-size = measure(text-style(test-line))
            if test-size.width > bounds.width and current-line != "" {
              lines.push(current-line)
              current-line = w
            } else {
              current-line = test-line
            }
          }
          if current-line != "" { lines.push(current-line) }

          let max-w = 0pt
          for l in lines {
            let w = measure(text-style(l)).width
            if w > max-w { max-w = w }
          }

          align(center)[
            #box(width: max-w)[
              #line(length: 100%, stroke: 0.8pt)
              #align(center)[
                #text-style(lines.join("\n"))
                #if subtopic != none and subtopic != "" [
                  \ #v(0.4em)
                  #text(font: "Times New Roman", size: 14pt, weight: "regular", subtopic)
                ]
              ]
              #line(length: 100%, stroke: 0.8pt)
            ]
          ]
        }
      })

      #v(0.3fr)
      // Subheader: Hochschule, Duales Studium · Informatik, Polizei Berlin
      #text(size: 13pt)[
        Hochschule für Wirtschaft und Recht Berlin \
        Duales Studium #sym.dot #studiengang \
        #v(0.6em)
        #company
      ]

      #v(1fr)

      // Full name in bold and smaller matrikelnummer underneath
      #text(size: 16pt, weight: "bold", studentName) \
      #v(-0.5em)
      #text(size: 11pt, matrikelNr)

      #v(1fr)

      // City and submission date
      #text(size: 11pt, [Berlin, #submissionDate])

      #v(0.5fr)

      // Police logo from bilder/polizeilogos
      #if logoCompany != none and logoCompany != "" {
        image(logoCompany, height: 6cm)
      }

      #v(0.5fr)

      // Supervision section (no labels)
      #text(size: 11pt)[
        Betreut von \
        #if betreuerHS != none and betreuerHS != "" [ #betreuerHS \ ]
        #if betreuerUnt != none and betreuerUnt != "" [ #betreuerUnt ]
      ]
      #v(0.2fr)
    ]
  ]) <no-wc>]

  pagebreak()

  // 2. Setup layout for the main body
  set page(
    paper: "a4",
    margin: (top: 2cm, bottom: 2cm, left: 2cm, right: 2.3cm),
    header: context {
      // Check if this page has a level 1 heading starting on it
      let current-page = here().page()
      let headings-on-page = query(heading.where(level: 1)).filter(h => h.location().page() == current-page)

      block(height: 1.5em, width: 100%)[
        #if headings-on-page.len() == 0 {
          // Only show header if there is no level 1 heading starting on this page (plain style)
          let headings-before = query(selector(heading.where(level: 1)).before(here()))
          if headings-before.len() > 0 {
            let current-heading = headings-before.last()
            let body = current-heading.body
            let header-text = if current-heading.numbering != none {
              let num = numbering(current-heading.numbering, ..counter(heading).at(current-heading.location()))
              [#num #body]
            } else {
              body
            }
            grid(
              columns: (1fr, auto),
              align(left, text(size: 9pt, style: "italic", header-text)), align(right, none),
            )
            v(-6pt)
            line(length: 100%, stroke: 0.5pt)
          }
        }
      ]
    },
    footer: context {
      let numing = here().page-numbering()
      if numing != none {
        let page-num = counter(page).display(numing)
        align(center, text(size: 10pt, page-num))
      }
    },
  )

  // Front matter page numbering is Roman by default
  set page(numbering: "I")
  counter(page).update(1)

  // Paragraph spacing and leading
  set par(leading: 0.8em, justify: true, spacing: 1.2em)

  // Font settings: default is Times New Roman
  set text(font: "Times New Roman", size: 12pt, lang: "de")

  // Headings styling
  set heading(numbering: "1.1")
  show heading: set text(font: "Times New Roman", weight: "bold")
  show heading: it => {
    let before = 1.5em
    let after = 1.0em
    if it.level == 1 {
      before = 1.5em
      after = 1.0em
    } else if it.level == 2 {
      before = 1.2em
      after = 0.8em
    } else if it.level == 3 {
      before = 1.0em
      after = 0.6em
    }
    block(
      above: before,
      below: after,
      it,
    )
  }

  // Force pagebreak before level 1 headings, except front-matter or weak pagebreaks
  show heading.where(level: 1): it => {
    pagebreak(weak: true)
    it
  }

  // Captions styling
  show figure.caption: set text(size: 10pt)
  show figure.where(kind: table): set figure.caption(position: top)
  show figure.where(kind: image): set figure.caption(position: bottom)
  show figure.where(kind: "code"): set figure.caption(position: bottom)

  // Link styling: URLs are blue, internal links are black
  show link: it => {
    if type(it.dest) == str {
      set text(fill: blue)
      it
    } else {
      it
    }
  }

  // Apply glossarium rules and register entries
  show: make-glossary
  if glossary-entries.len() > 0 {
    register-glossary(glossary-entries)
  }

  body
}

// Helper: footfigref
#let footfigref(lbl) = {
  footnote[Abb. #ref(lbl) auf Seite #context {
      let elems = query(lbl)
      if elems.len() > 0 {
        let page = elems.first().location().page()
        [#page]
      } else { [?] }
    }]
}

// Helper: code-block
#let code-block(style: "default", caption: none, label: none, body) = {
  let fill-color = if style == "ps" { rgb("fffbf5") } else { rgb("1e1e1e") }
  let text-color = if style == "ps" { black } else { white }
  let stroke-border = if style == "ps" { none } else { (left: 0.5pt + white, right: 0.5pt + white) }
  let show-numbers = if style == "cli" { false } else { true }

  let content = align(left)[
    #block(
      fill: fill-color,
      stroke: stroke-border,
      inset: 8pt,
      width: 100%,
      {
        set text(fill: text-color, size: 9pt)
        set par(leading: 0.6em) // Adjust line spacing for standard blocks
        show raw.where(block: true): it => {
          if show-numbers {
            grid(
              columns: (auto, 1fr),
              column-gutter: 1.2em,
              row-gutter: 0.6em, // Spacing between lines
              ..it
                .lines
                .enumerate()
                .map(((i, line)) => (
                  text(fill: if style == "ps" { gray.darken(10%) } else { gray.lighten(30%) }, size: 8pt)[#(i + 1)],
                  raw(line.text, lang: it.lang),
                ))
                .flatten()
            )
          } else {
            it
          }
        }
        body
      },
    )
  ]

  if caption != none {
    let fig = figure(
      content,
      caption: caption,
      kind: "code",
      supplement: [Codeausschnitt],
    )
    if label != none {
      [#fig #label]
    } else {
      fig
    }
  } else {
    if label != none {
      [#content #label]
    } else {
      content
    }
  }
}

// Helper: print-bibliography
#let parse-bib(content) = {
  let entries = ()
  let lines = content.split("\n").filter(l => not l.trim().starts-with("%")).join("\n")
  let raw-parts = lines.split("@")

  for part in raw-parts {
    let part = part.trim()
    if part == "" { continue }
    if not part.contains("{") { continue }

    let type-part = lower(part.split("{").at(0).trim())
    let rest = part.slice(part.position("{") + 1)

    let entry-lines = rest.split("\n")
    if entry-lines.len() == 0 { continue }

    let first-line = entry-lines.at(0)
    let key = first-line.split(",").at(0).trim()

    let fields = (:)
    fields.insert("type", type-part)
    fields.insert("key", key)

    for line in entry-lines.slice(1) {
      let line = line.trim()
      if line == "" or line == "}" or line == "}," { continue }
      if not line.contains("=") { continue }

      let eq-idx = line.position("=")
      let field-name = lower(line.slice(0, eq-idx).trim())
      let field-val = line.slice(eq-idx + 1).trim()

      if field-val.ends-with(",") {
        field-val = field-val.slice(0, -1).trim()
      }

      if (
        (field-val.starts-with("{") and field-val.ends-with("}"))
          or (field-val.starts-with("\"") and field-val.ends-with("\""))
      ) {
        field-val = field-val.slice(1, -1)
      }

      if field-val.starts-with("{") and field-val.ends-with("}") {
        field-val = field-val.slice(1, -1)
      }

      field-val = field-val.replace("\\&", "&").replace("\\_", "_")

      fields.insert(field-name, field-val)
    }
    entries.push(fields)
  }
  return entries
}

#let format-authors(author-str) = {
  if author-str == none or author-str == "" { return "" }
  let authors = author-str.split(regex("\s+and\s+"))
  let formatted = ()

  for auth in authors {
    let auth = auth.trim()
    if auth == "" { continue }

    if auth.starts-with("{") and auth.ends-with("}") {
      formatted.push(auth.slice(1, -1))
      continue
    }

    if auth.contains(",") {
      let parts = auth.split(",")
      let last = parts.at(0).trim()
      let first = parts.slice(1).join(",").trim()
      let first-parts = first.split(regex("\s+"))
      let initials = first-parts
        .map(p => {
          if p.len() > 0 { p.slice(0, 1) + "." } else { "" }
        })
        .join(" ")
      formatted.push(last + ", " + initials)
    } else {
      let parts = auth.split(regex("\s+"))
      if parts.len() == 1 {
        formatted.push(parts.at(0))
      } else {
        let last = parts.last()
        let first-parts = parts.slice(0, -1)
        let initials = first-parts
          .map(p => {
            if p.len() > 0 { p.slice(0, 1) + "." } else { "" }
          })
          .join(" ")
        formatted.push(last + ", " + initials)
      }
    }
  }

  if formatted.len() == 0 {
    return ""
  } else if formatted.len() == 1 {
    return formatted.at(0)
  } else if formatted.len() == 2 {
    return formatted.at(0) + " & " + formatted.at(1)
  } else {
    let first-part = formatted.slice(0, -1).join(", ")
    return first-part + ", & " + formatted.last()
  }
}

#let get-source-type(entry) = {
  let t = entry.type
  if t == "article" {
    return "Artikel"
  } else if t == "inproceedings" {
    return "Konferenz"
  } else if t == "online" {
    return "Website"
  } else if t == "misc" {
    if entry.keys().contains("doi") {
      return "Paper"
    } else {
      return "Website"
    }
  }
  return "Sonstiges"
}

#let print-bibliography(bib-file) = context {
  let cites = query(selector(cite))
  let unique-keys = ()
  for c in cites {
    let k = str(c.key)
    if k not in unique-keys {
      unique-keys.push(k)
    }
  }

  let bib-data = parse-bib(read(bib-file))
  let cited-entries = bib-data.filter(e => e.key in unique-keys)

  cited-entries = cited-entries.sorted(key: e => {
    let author = e.at("author", default: "")
    let year = e.at("year", default: "")
    author + " " + year
  })

  set text(size: 9.5pt)

  for entry in cited-entries {
    let stype = get-source-type(entry)
    let type-cell = text(weight: "bold", fill: luma(100))[\[#stype\]]

    let authors = format-authors(entry.at("author", default: ""))
    let year = entry.at("year", default: "")
    let title = entry.at("title", default: "")
    let journal = entry.at("journal", default: "")
    let booktitle = entry.at("booktitle", default: "")
    let volume = entry.at("volume", default: "")
    let number = entry.at("number", default: "")
    let pages = entry.at("pages", default: "")
    let doi = entry.at("doi", default: "")
    let url = entry.at("url", default: "")

    let ref-text = [
      #emph(title)
    ]

    if authors != "" {
      ref-text += [\ #authors]
    }

    let extra-info = none
    if doi != "" {
      let clean-doi = doi
      if clean-doi.starts-with("https://doi.org/") {
        clean-doi = clean-doi.slice("https://doi.org/".len())
      } else if clean-doi.starts-with("http://doi.org/") {
        clean-doi = clean-doi.slice("http://doi.org/".len())
      }

      extra-info = block(above: 0.4em)[
        #text(size: 8.5pt, fill: luma(100))[
          *DOI:* #link("https://doi.org/" + clean-doi)[#clean-doi]
        ]
      ]
    } else if url != "" {
      extra-info = block(above: 0.4em)[
        #text(size: 8.5pt, fill: luma(100))[
          *URL:* #link(url)
        ]
      ]
    }

    let content-cell = [
      #ref-text
      #extra-info
    ]

    block(breakable: false, width: 100%, inset: (bottom: 0.8em))[
      #grid(
        columns: (65pt, 1fr),
        column-gutter: 1.5em,
        type-cell,
        content-cell,
      )
    ]
  }
}



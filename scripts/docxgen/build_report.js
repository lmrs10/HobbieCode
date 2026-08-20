const fs = require("fs");
const path = require("path");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, ImageRun,
  ExternalHyperlink, AlignmentType, BorderStyle, ShadingType,
  Table, TableRow, TableCell, WidthType, LevelFormat,
} = require("docx");

const specPath = process.argv[2];
const outPath = process.argv[3];
const spec = JSON.parse(fs.readFileSync(specPath, "utf-8"));

function imgDims(file) {
  const buf = fs.readFileSync(file);
  let width, height;
  if (file.toLowerCase().endsWith(".png")) {
    width = buf.readUInt32BE(16);
    height = buf.readUInt32BE(20);
  } else {
    // JPEG: scan markers for SOF0/SOF2
    let i = 2;
    while (i < buf.length) {
      if (buf[i] !== 0xff) { i++; continue; }
      const marker = buf[i + 1];
      if (marker === 0xc0 || marker === 0xc2) {
        height = buf.readUInt16BE(i + 5);
        width = buf.readUInt16BE(i + 7);
        break;
      }
      const len = buf.readUInt16BE(i + 2);
      i += 2 + len;
    }
  }
  const maxW = 560;
  const scale = width > maxW ? maxW / width : 1;
  return { width: Math.round(width * scale), height: Math.round(height * scale) };
}

function imgType(file) {
  return file.toLowerCase().endsWith(".png") ? "png" : "jpg";
}

const children = [];

// Title
children.push(new Paragraph({
  heading: HeadingLevel.TITLE,
  children: [new TextRun({ text: spec.title, bold: true })],
}));

// Metadata line
children.push(new Paragraph({
  spacing: { after: 200 },
  children: [
    new TextRun({ text: `Canal: ${spec.channel}  |  Publicado: ${spec.publishedDisplay}  |  Duración: ${spec.durationDisplay}`, italics: true, color: "666666", size: 20 }),
  ],
}));

children.push(new Paragraph({
  spacing: { after: 300 },
  children: [
    new TextRun({ text: "Enlace al vídeo: ", bold: true, size: 20 }),
    new ExternalHyperlink({
      link: spec.url,
      children: [new TextRun({ text: spec.url, style: "Hyperlink", size: 20 })],
    }),
  ],
}));

// Sections
for (const section of spec.sections) {
  children.push(new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 300, after: 150 },
    children: [new TextRun({ text: section.heading, bold: true })],
  }));
  for (const item of section.content) {
    if (typeof item === "string") {
      children.push(new Paragraph({
        spacing: { after: 120 },
        children: [new TextRun({ text: item })],
      }));
    } else if (item.bullets) {
      for (const b of item.bullets) {
        children.push(new Paragraph({
          numbering: { reference: "bullet-list", level: 0 },
          spacing: { after: 80 },
          children: [new TextRun({ text: b })],
        }));
      }
    }
  }
}

// Screenshots section
if (spec.screenshots && spec.screenshots.length) {
  children.push(new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 300, after: 150 },
    pageBreakBefore: true,
    children: [new TextRun({ text: "Capturas de pantalla", bold: true })],
  }));
  for (const shot of spec.screenshots) {
    const dims = imgDims(shot.file);
    children.push(new Paragraph({
      alignment: AlignmentType.CENTER,
      spacing: { before: 200, after: 80 },
      children: [
        new ImageRun({
          type: imgType(shot.file),
          data: fs.readFileSync(shot.file),
          transformation: dims,
        }),
      ],
    }));
    if (shot.caption) {
      children.push(new Paragraph({
        alignment: AlignmentType.CENTER,
        spacing: { after: 200 },
        children: [new TextRun({ text: shot.caption, italics: true, size: 18, color: "666666" })],
      }));
    }
  }
}

const doc = new Document({
  numbering: {
    config: [
      {
        reference: "bullet-list",
        levels: [
          { level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
            style: { paragraph: { indent: { left: 480, hanging: 260 } } } },
        ],
      },
    ],
  },
  sections: [
    {
      properties: { page: { size: { width: 11906, height: 16838 } } }, // A4
      children,
    },
  ],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync(outPath, buf);
  console.log("Written", outPath, buf.length, "bytes");
});

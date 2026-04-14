"""
Diplomax CM — PDF Generation Service
Generates embassy-ready, blockchain-certified PDF documents.
Uses ReportLab for layout + QR code embedding.
"""
import io
import os
import qrcode
from datetime import datetime
from typing import Optional

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import cm, mm
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle,
    HRFlowable, Image, KeepTogether,
)
from reportlab.lib.utils import ImageReader

from app.core.config import get_settings

settings = get_settings()

# Brand colours
GREEN_HEX = "#0F6E56"
GREEN_RGB = colors.HexColor(GREEN_HEX)
BLUE_RGB  = colors.HexColor("#185FA5")
GRAY_RGB  = colors.HexColor("#6B6B6B")
LIGHT_GREEN = colors.HexColor("#E1F5EE")


class PdfService:
    """Generates certified PDF documents for Diplomax CM."""

    # ── Standard certified document PDF ──────────────────────────────────────

    def generate_document_pdf(
        self,
        *,
        student_name: str,
        matricule: str,
        university_name: str,
        doc_type: str,
        title: str,
        degree: str,
        field: str,
        mention: str,
        issue_date: str,
        hash_sha256: str,
        blockchain_tx: Optional[str],
        rsa_signature: Optional[str],
        grades: Optional[list[dict]] = None,
        qr_verify_url: str,
        is_international: bool = False,
    ) -> bytes:
        """
        Generates a PDF for the document.
        If is_international=True, adds embassy-specific header and seal.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(
            buffer,
            pagesize=A4,
            rightMargin=2*cm,
            leftMargin=2*cm,
            topMargin=2*cm,
            bottomMargin=2*cm,
        )
        styles = getSampleStyleSheet()

        # Custom styles
        title_style = ParagraphStyle("DiplomaxTitle",
            fontName="Helvetica-Bold", fontSize=22,
            textColor=GREEN_RGB, alignment=TA_CENTER,
            spaceAfter=6)
        subtitle_style = ParagraphStyle("DiplomaxSubtitle",
            fontName="Helvetica", fontSize=13,
            textColor=GRAY_RGB, alignment=TA_CENTER,
            spaceAfter=4)
        section_style = ParagraphStyle("DiplomaxSection",
            fontName="Helvetica-Bold", fontSize=11,
            textColor=GREEN_RGB, spaceAfter=4, spaceBefore=10)
        body_style = ParagraphStyle("DiplomaxBody",
            fontName="Helvetica", fontSize=10,
            textColor=colors.black, spaceAfter=3)
        mono_style = ParagraphStyle("DiplomaxMono",
            fontName="Courier", fontSize=8,
            textColor=GRAY_RGB, spaceAfter=2)

        story = []

        # ── Header ────────────────────────────────────────────────────────────
        if is_international:
            story.append(Paragraph(
                "OFFICIAL ACADEMIC CERTIFICATION — FOR INTERNATIONAL USE",
                ParagraphStyle("IntlHeader", fontName="Helvetica-Bold", fontSize=10,
                    textColor=BLUE_RGB, alignment=TA_CENTER, spaceAfter=2)))
            story.append(HRFlowable(width="100%", thickness=2, color=BLUE_RGB))
            story.append(Spacer(1, 6))

        story.append(Paragraph("DIPLOMAX CM", title_style))
        story.append(Paragraph("Secure Academic Certification Platform — Cameroon", subtitle_style))
        story.append(HRFlowable(width="100%", thickness=1.5, color=GREEN_RGB))
        story.append(Spacer(1, 8))

        # ── University & Document type ─────────────────────────────────────────
        story.append(Paragraph(university_name.upper(), ParagraphStyle(
            "UnivName", fontName="Helvetica-Bold", fontSize=14,
            textColor=colors.black, alignment=TA_CENTER, spaceAfter=4)))
        story.append(Paragraph(f"Official {doc_type.title()}", ParagraphStyle(
            "DocTypeLabel", fontName="Helvetica", fontSize=12,
            textColor=GRAY_RGB, alignment=TA_CENTER, spaceAfter=12)))

        # ── Student info box ───────────────────────────────────────────────────
        student_data = [
            ["Student name:", student_name],
            ["Matricule:",    matricule],
            ["Programme:",    field or "—"],
            ["Degree:",       degree or "—"],
            ["Mention:",      mention or "—"],
            ["Issue date:",   issue_date],
        ]
        t = Table(student_data, colWidths=[5*cm, 11*cm])
        t.setStyle(TableStyle([
            ("FONTNAME",     (0,0), (0,-1), "Helvetica-Bold"),
            ("FONTNAME",     (1,0), (1,-1), "Helvetica"),
            ("FONTSIZE",     (0,0), (-1,-1), 10),
            ("TEXTCOLOR",    (0,0), (0,-1), GREEN_RGB),
            ("TEXTCOLOR",    (1,0), (1,-1), colors.black),
            ("ROWBACKGROUNDS",(0,0),(-1,-1), [LIGHT_GREEN, colors.white]),
            ("GRID",         (0,0), (-1,-1), 0.3, colors.lightgrey),
            ("TOPPADDING",   (0,0), (-1,-1), 5),
            ("BOTTOMPADDING",(0,0), (-1,-1), 5),
            ("LEFTPADDING",  (0,0), (-1,-1), 8),
        ]))
        story.append(t)
        story.append(Spacer(1, 12))

        # ── Document title ─────────────────────────────────────────────────────
        story.append(Paragraph(title, ParagraphStyle(
            "DocTitle", fontName="Helvetica-Bold", fontSize=13,
            textColor=colors.black, alignment=TA_CENTER,
            spaceAfter=12, spaceBefore=6,
            borderPad=8, borderColor=GREEN_RGB, borderWidth=1)))

        # ── Grades table (if present) ──────────────────────────────────────────
        if grades:
            story.append(Paragraph("Academic Record", section_style))
            grade_rows = [["Code", "Course", "Sem.", "Credits", "Grade", "Mention"]]
            total_credits = 0
            weighted_sum  = 0.0
            for g in grades:
                mention_g = _grade_mention(float(g["grade"]))
                grade_rows.append([
                    g.get("course_code",""),
                    g.get("course_name",""),
                    g.get("semester",""),
                    str(g.get("credits","3")),
                    str(g.get("grade","0")),
                    mention_g,
                ])
                total_credits += int(g.get("credits", 3))
                weighted_sum  += float(g.get("grade", 0)) * int(g.get("credits", 3))

            avg = weighted_sum / total_credits if total_credits else 0
            grade_rows.append(["", "WEIGHTED AVERAGE", "", str(total_credits),
                                f"{avg:.2f}", _grade_mention(avg)])

            gt = Table(grade_rows, colWidths=[2*cm, 6.5*cm, 1.5*cm, 1.8*cm, 1.6*cm, 2.6*cm])
            gt.setStyle(TableStyle([
                ("FONTNAME",     (0,0), (-1,0), "Helvetica-Bold"),
                ("FONTNAME",     (0,1), (-1,-2),"Helvetica"),
                ("FONTNAME",     (0,-1),(-1,-1),"Helvetica-Bold"),
                ("FONTSIZE",     (0,0), (-1,-1), 8.5),
                ("BACKGROUND",   (0,0), (-1,0),  GREEN_RGB),
                ("TEXTCOLOR",    (0,0), (-1,0),  colors.white),
                ("BACKGROUND",   (0,-1),(-1,-1), LIGHT_GREEN),
                ("ROWBACKGROUNDS",(0,1),(-1,-2), [colors.white, colors.HexColor("#F9F9F7")]),
                ("GRID",         (0,0), (-1,-1), 0.3, colors.lightgrey),
                ("TOPPADDING",   (0,0), (-1,-1), 4),
                ("BOTTOMPADDING",(0,0), (-1,-1), 4),
                ("LEFTPADDING",  (0,0), (-1,-1), 5),
            ]))
            story.append(gt)
            story.append(Spacer(1, 12))

        # ── Cryptographic proof ────────────────────────────────────────────────
        story.append(HRFlowable(width="100%", thickness=0.5, color=GRAY_RGB))
        story.append(Spacer(1, 6))
        story.append(Paragraph("Cryptographic Authentication", section_style))

        story.append(Paragraph(
            f"<b>SHA-256 Fingerprint:</b> {hash_sha256}", mono_style))
        if blockchain_tx:
            story.append(Paragraph(
                f"<b>Blockchain TX:</b> {blockchain_tx}", mono_style))
        if rsa_signature:
            short_sig = rsa_signature[:64] + "..."
            story.append(Paragraph(
                f"<b>RSA Signature:</b> {short_sig}", mono_style))

        story.append(Spacer(1, 6))
        story.append(Paragraph(
            "This document has been cryptographically signed by the issuing university "
            "and its SHA-256 hash has been permanently anchored on a Hyperledger Fabric "
            "blockchain. Any modification of this document will produce a different hash, "
            "making tampering immediately detectable.",
            ParagraphStyle("ProofText", fontName="Helvetica-Oblique", fontSize=8.5,
                textColor=GRAY_RGB, spaceAfter=8)))

        # ── QR code ───────────────────────────────────────────────────────────
        qr_img = _generate_qr_image(qr_verify_url, size=3*cm)
        qr_para = [
            [qr_img, Paragraph(
                f"<b>Verify online:</b><br/>{qr_verify_url}<br/><br/>"
                "<i>Scan this QR code to verify authenticity in real time.</i>",
                ParagraphStyle("QRText", fontName="Helvetica", fontSize=9,
                    textColor=GRAY_RGB))]
        ]
        qt = Table(qr_para, colWidths=[3.5*cm, 12.5*cm])
        qt.setStyle(TableStyle([
            ("VALIGN",       (0,0), (-1,-1), "MIDDLE"),
            ("LEFTPADDING",  (0,0), (-1,-1), 4),
        ]))
        story.append(qt)
        story.append(Spacer(1, 8))

        # ── International addendum ─────────────────────────────────────────────
        if is_international:
            story.append(HRFlowable(width="100%", thickness=1, color=BLUE_RGB))
            story.append(Spacer(1, 4))
            story.append(Paragraph("FOR OFFICIAL USE ABROAD", ParagraphStyle(
                "IntlTitle", fontName="Helvetica-Bold", fontSize=10,
                textColor=BLUE_RGB, alignment=TA_CENTER, spaceAfter=4)))
            story.append(Paragraph(
                "This document has been issued by a Cameroonian university accredited "
                "by the Ministère de l'Enseignement Supérieur (MINESUP) of the Republic "
                "of Cameroon. The cryptographic signatures and blockchain anchoring "
                "described above provide independently verifiable proof of authenticity "
                "without requiring contact with the issuing institution.",
                body_style))
            story.append(Spacer(1, 4))
            story.append(Paragraph(
                "For verification assistance, contact: verification@diplomax.cm",
                ParagraphStyle("Contact", fontName="Helvetica", fontSize=9,
                    textColor=GRAY_RGB, alignment=TA_CENTER)))

        # ── Footer ─────────────────────────────────────────────────────────────
        story.append(Spacer(1, 10))
        story.append(HRFlowable(width="100%", thickness=0.5, color=GRAY_RGB))
        story.append(Paragraph(
            f"Generated by Diplomax CM v2.0 · {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')} · "
            "Confidential — for authorised use only",
            ParagraphStyle("Footer", fontName="Helvetica", fontSize=7.5,
                textColor=GRAY_RGB, alignment=TA_CENTER)))

        doc.build(story)
        return buffer.getvalue()

    # ── International share package ───────────────────────────────────────────

    def generate_intl_package_pdf(
        self,
        *,
        student_name: str,
        matricule: str,
        institution_name: str,
        institution_country: str,
        purpose: str,
        package_token: str,
        access_url: str,
        expires_at: str,
        documents: list[dict],
    ) -> bytes:
        """
        Generates a cover letter + document list for an international share package.
        """
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4,
            rightMargin=2.5*cm, leftMargin=2.5*cm,
            topMargin=2.5*cm, bottomMargin=2.5*cm)
        styles = getSampleStyleSheet()

        story = []
        today = datetime.utcnow().strftime("%B %d, %Y")

        story.append(Paragraph("DIPLOMAX CM", ParagraphStyle(
            "H", fontName="Helvetica-Bold", fontSize=24,
            textColor=GREEN_RGB, alignment=TA_CENTER, spaceAfter=4)))
        story.append(Paragraph("International Academic Document Package",
            ParagraphStyle("S", fontName="Helvetica", fontSize=13,
            textColor=GRAY_RGB, alignment=TA_CENTER, spaceAfter=12)))
        story.append(HRFlowable(width="100%", thickness=2, color=GREEN_RGB))
        story.append(Spacer(1, 16))

        story.append(Paragraph(f"Date: {today}", styles["Normal"]))
        story.append(Spacer(1, 6))
        story.append(Paragraph(f"To: <b>{institution_name}</b>, {institution_country}",
            styles["Normal"]))
        story.append(Spacer(1, 16))

        story.append(Paragraph(
            f"Dear Admissions Office,<br/><br/>"
            f"Please find enclosed the certified academic documentation for "
            f"<b>{student_name}</b> (Matricule: {matricule}), "
            f"submitted for the purpose of: <b>{purpose}</b>.<br/><br/>"
            f"Each document in this package has been cryptographically signed by "
            f"the issuing Cameroonian university and anchored on a Hyperledger Fabric "
            f"blockchain. You may independently verify any document at any time by "
            f"visiting the secure access URL below.",
            ParagraphStyle("Body", fontName="Helvetica", fontSize=11,
                textColor=colors.black, spaceAfter=16, leading=16)))

        story.append(Paragraph("Included Documents", ParagraphStyle(
            "Sec", fontName="Helvetica-Bold", fontSize=12,
            textColor=GREEN_RGB, spaceAfter=8)))

        for i, d in enumerate(documents, 1):
            story.append(Paragraph(
                f"{i}. <b>{d['title']}</b> — {d['doc_type'].title()} "
                f"({d['university']}, {d['issue_date']}). "
                f"Mention: {d.get('mention','—')}.",
                ParagraphStyle("DocItem", fontName="Helvetica", fontSize=10,
                    spaceAfter=4, leftIndent=12)))

        story.append(Spacer(1, 16))
        story.append(Paragraph("Secure Access", ParagraphStyle(
            "Sec", fontName="Helvetica-Bold", fontSize=12,
            textColor=GREEN_RGB, spaceAfter=8)))

        qr_img = _generate_qr_image(access_url, size=3.5*cm)
        qr_table = Table([[qr_img, Paragraph(
            f"<b>Access URL:</b><br/>{access_url}<br/><br/>"
            f"<b>Package ID:</b><br/>{package_token[:24]}...<br/><br/>"
            f"<b>Valid until:</b> {expires_at}<br/><br/>"
            f"<i>For verification assistance: verification@diplomax.cm</i>",
            ParagraphStyle("QR", fontName="Helvetica", fontSize=9,
                textColor=GRAY_RGB, leading=14))]],
            colWidths=[4*cm, 12*cm])
        qr_table.setStyle(TableStyle([("VALIGN",(0,0),(-1,-1),"TOP"),("LEFTPADDING",(0,0),(-1,-1),4)]))
        story.append(qr_table)

        story.append(Spacer(1, 24))
        story.append(Paragraph(
            "This package was generated by Diplomax CM, the official digital academic "
            "certification platform for Cameroonian universities. "
            "All documents are authentic originals issued by MINESUP-accredited institutions.",
            ParagraphStyle("Disc", fontName="Helvetica-Oblique", fontSize=9,
                textColor=GRAY_RGB, alignment=TA_CENTER)))

        doc.build(story)
        return buffer.getvalue()


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _grade_mention(grade: float) -> str:
    if grade >= 16: return "Très Bien"
    if grade >= 14: return "Bien"
    if grade >= 12: return "Assez Bien"
    if grade >= 10: return "Passable"
    return "Insuffisant"


def _generate_qr_image(url: str, size: float) -> Image:
    """Generates a QR code image for embedding in a PDF."""
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=10,
        border=2,
    )
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    buf.seek(0)
    return Image(ImageReader(buf), width=size, height=size)

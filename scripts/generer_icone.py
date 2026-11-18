#!/usr/bin/env python3
"""Génère l'icône de NOYA SSH Manager (toutes les tailles macOS).

Usage : python3 scripts/generer_icone.py
Dépendance de développement uniquement : Pillow (pip install pillow).
Les PNG produits sont versionnés : ce script n'est utile que pour modifier l'icône.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

RACINE = Path(__file__).resolve().parent.parent
DOSSIER = RACINE / "NoyaSSHManager" / "Ressources" / "Assets.xcassets" / "AppIcon.appiconset"

ECHELLE = 4  # Dessin en 4096 px puis réduction : anti-crénelage de qualité.
TAILLE = 1024 * ECHELLE

TURQUOISE = (60, 207, 192, 255)
VERT = (48, 209, 88, 255)
HAUT = (24, 36, 60)
BAS = (10, 16, 28)


def s(valeur: float) -> int:
    """Convertit une coordonnée de la grille 1024 vers la grille de dessin."""
    return int(round(valeur * ECHELLE))


def squircle(taille: int, rayon: int) -> Image.Image:
    masque = Image.new("L", (taille, taille), 0)
    ImageDraw.Draw(masque).rounded_rectangle((0, 0, taille - 1, taille - 1), radius=rayon, fill=255)
    return masque


def degrade(largeur: int, hauteur: int) -> Image.Image:
    image = Image.new("RGB", (largeur, hauteur))
    trace = ImageDraw.Draw(image)
    for y in range(hauteur):
        t = y / max(1, hauteur - 1)
        couleur = tuple(int(HAUT[i] + (BAS[i] - HAUT[i]) * t) for i in range(3))
        trace.line((0, y, largeur, y), fill=couleur)
    return image


def dessiner() -> Image.Image:
    toile = Image.new("RGBA", (TAILLE, TAILLE), (0, 0, 0, 0))

    # Gabarit macOS : forme de 824 px centrée, marges de 100 px.
    marge, cote, rayon = s(100), s(824), s(185)

    # Ombre portée discrète.
    ombre = Image.new("RGBA", (TAILLE, TAILLE), (0, 0, 0, 0))
    ImageDraw.Draw(ombre).rounded_rectangle(
        (marge, marge + s(12), marge + cote, marge + cote + s(12)), radius=rayon, fill=(0, 0, 0, 110)
    )
    toile.alpha_composite(ombre.filter(ImageFilter.GaussianBlur(s(18))))

    # Fond bleu nuit en dégradé vertical.
    fond = degrade(cote, cote).convert("RGBA")
    fond.putalpha(squircle(cote, rayon))
    toile.alpha_composite(fond, (marge, marge))

    # Les motifs sont dessinés sur un calque transparent puis composés : ImageDraw
    # remplace les pixels au lieu de les mélanger, ce qui percerait le fond.
    calque = Image.new("RGBA", (TAILLE, TAILLE), (0, 0, 0, 0))
    trace = ImageDraw.Draw(calque)

    # Liseré très léger, entièrement à l'intérieur de la forme.
    retrait = s(2)
    trace.rounded_rectangle(
        (marge + retrait, marge + retrait, marge + cote - retrait, marge + cote - retrait),
        radius=rayon - retrait,
        outline=(255, 255, 255, 22),
        width=s(2),
    )

    # Invite de terminal « › _ ».
    epaisseur = s(58)
    chevron = [(s(300), s(268)), (s(430), s(380)), (s(300), s(492))]
    trace.line(chevron, fill=TURQUOISE, width=epaisseur, joint="curve")
    for x, y in (chevron[0], chevron[2]):
        trace.ellipse((x - epaisseur // 2, y - epaisseur // 2, x + epaisseur // 2, y + epaisseur // 2), fill=TURQUOISE)
    trace.rounded_rectangle((s(480), s(452), s(724), s(508)), radius=s(28), fill=TURQUOISE)

    # Deux baies de serveur avec voyants de disponibilité.
    for haut in (s(586), s(706)):
        trace.rounded_rectangle(
            (s(270), haut, s(754), haut + s(88)), radius=s(26), outline=(170, 185, 205, 150), width=s(10)
        )
        trace.rounded_rectangle((s(316), haut + s(36), s(470), haut + s(52)), radius=s(8), fill=(170, 185, 205, 120))
        trace.ellipse((s(680), haut + s(26), s(716), haut + s(62)), fill=VERT)

    toile.alpha_composite(calque)
    return toile


def main() -> None:
    DOSSIER.mkdir(parents=True, exist_ok=True)
    grande = dessiner()
    for ancien in DOSSIER.glob("*.png"):
        ancien.unlink()
    # Emplacements standard d'une icône macOS : 16 à 512 points, en 1x et 2x.
    for points in (16, 32, 128, 256, 512):
        for facteur in (1, 2):
            pixels = points * facteur
            suffixe = "" if facteur == 1 else "@2x"
            nom = f"icon_{points}x{points}{suffixe}.png"
            grande.resize((pixels, pixels), Image.LANCZOS).save(DOSSIER / nom, optimize=True)
    print(f"Icônes générées dans {DOSSIER}")


if __name__ == "__main__":
    main()

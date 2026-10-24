# Oscar's Games — design system

Charte complète et composants maintenus comme Artifact Claude :
https://claude.ai/artifact/SSVz6QwRJGzwsFuX6vaaoA

Ce dossier est une copie de référence pour le dépôt. Les tokens sont déjà
intégrés en CSS dans `app/assets/stylesheets/design_system/` :

- `tokens.css` — variables de couleur, espacement, rayons, thème clair/sombre.
- `components.css` — classes de base (`.ds-btn`, `.ds-card`, styles de texte).

En cas de changement de la charte dans l'Artifact, régénérer ces deux
fichiers à partir de `tokens.json` et `components/bundle.css` plutôt que
les modifier à la main ici.

## Contenu

- Système de conception pour un jeu sérieux : un cadre visuel calme, lisible
  et motivant, pensé pour des apprenants qui doivent se concentrer sur le
  contenu pédagogique, pas sur l'interface.
- Public : formation professionnelle en entreprise (montée en compétence,
  conformité, onboarding). Contexte d'apprentissage par quiz et mises en
  situation, progression par niveaux, utilisation sur ordinateur et
  tablette.

## Fondements de contenu

- **Ton** : professionnel et encourageant, jamais infantilisant. On
  félicite l'effort, pas seulement la réussite.
- **Vocabulaire** : phrases courtes, verbes d'action, pas de jargon
  technique dans l'interface de jeu — le jargon métier reste dans le
  contenu pédagogique, pas dans l'UI.
- **Feedback** : toujours immédiat et explicite — l'apprenant doit
  comprendre en un coup d'œil s'il a réussi, et pourquoi.

## Fondements visuels

### Couleur

Deux thèmes, clair et sombre. `primary` (sarcelle) porte les actions et la
progression ; `accent` (ambre) est réservé aux récompenses et badges, pour
qu'il garde sa valeur de signal. `success` et `danger` sont dédiés au
retour sur les réponses et ne doivent pas servir à autre chose.

Tout texte respecte un contraste d'au moins 4,5:1 sur son fond, dans les
deux thèmes (3:1 à partir de 24px, bordures de contrôle et anneaux de
focus compris).

### Typographie

Une seule famille, `sans` (Figtree, chargée depuis Google Fonts). Les
titres utilisent les graisses 600–700, le texte courant 400.

### Espacement et rayons

Échelle d'espacement en incréments de 4px (`space-2` à `space-24`). Les
rayons distinguent les contrôles (`radius-sm`), les cartes (`radius-md`),
les grands panneaux (`radius-lg`) et les éléments ronds comme les badges
et barres de progression (`radius-pill`).

## Composants

Spécifications détaillées sous `components/` :

- [Bouton](components/Bouton.md) — action principale, secondaire, désactivé.
- [BarreProgression](components/BarreProgression.md) — avancement dans un niveau ou un parcours.
- [Badge](components/Badge.md) — récompense ou jalon débloqué.
- [CarteQuiz](components/CarteQuiz.md) — question à choix multiple avec états de réponse.
- [RetourFeedback](components/RetourFeedback.md) — bandeau de confirmation après une réponse.

Chaque composant documente les tokens qu'il utilise ; ne pas introduire de
couleur ou d'espacement hors de cette liste sans l'ajouter d'abord aux
tokens dans l'Artifact.

## Accessibilité

- Tout élément interactif affiche `focus-ring` au clavier (anneau 2px).
- Les paires qui doivent être distinguées (réussite/échec) se
  distinguent aussi par une icône et un mot, pas seulement par la couleur.
- Taille de cible tactile minimale : 44×44px pour les boutons et cartes de
  quiz, pensé pour un usage tablette.

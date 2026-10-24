# Bouton

Boutons d'action pour le jeu : une action principale par écran, le reste en secondaire.

CSS : `.ds-btn`, `.ds-btn-primary`, `.ds-btn-secondary` (`app/assets/stylesheets/design_system/components.css`).

## Variantes

- **Primaire** (`primary` / `on-primary`) : l'action que l'apprenant doit
  faire pour avancer (« Valider », « Niveau suivant »). Une seule par écran.
- **Secondaire** (bordure `border`, texte `primary`) : actions
  alternatives (« Revoir la leçon », « Passer »).
- **Désactivé** : opacité réduite, `cursor: not-allowed`, jamais la seule
  action visible à l'écran.

## Règles

- Hauteur minimale 44px (cible tactile tablette).
- Le focus clavier affiche toujours `focus-ring`.
- Le texte du bouton est un verbe d'action, jamais « OK » ou « Cliquez ici ».

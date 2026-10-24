# BarreProgression

Barre horizontale montrant l'avancement dans un niveau ou un parcours complet.

## Règles

- Toujours accompagnée d'un texte (« 3 / 5 questions » ou « 60 % »), jamais
  la couleur seule pour indiquer l'avancement.
- Remplissage en `primary`, piste en `surface-300`, coins en `radius-pill`.
- `role="progressbar"` avec `aria-valuenow`/`aria-valuemin`/`aria-valuemax`
  dans l'implémentation finale.

# CarteQuiz

Question à choix multiple, le cœur de l'interaction pédagogique.

## États des options

- **Au repos** : fond `surface-200`, bordure `border`.
- **Survol/focus** : fond `surface-300`, anneau `focus-ring` au clavier.
- **Sélectionnée, avant validation** : bordure `primary`, fond `surface-300`.
- **Correcte (après validation)** : bordure et icône `success`.
- **Incorrecte (après validation)** : bordure et icône `danger`, affichée
  uniquement sur l'option choisie, jamais sur toutes les options fausses.

## Règles

- Une seule question par carte ; options en colonne, jamais en grille
  dense, pour rester lisible sur tablette.
- Cible tactile de chaque option : 44px de hauteur minimum.
- L'état correct/incorrect se lit à l'icône et au texte, pas seulement à
  la couleur de la bordure.

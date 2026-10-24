# Creator is a flag on Participant, not a column on Game

`Game` has no `creator_id` column. Instead, `Participant` carries a `creator` boolean, and the Creator is the Participant row with that flag set to true. Creating a Game inserts both the `Game` row and its Creator's `Participant` row in the same operation, with no JoinRequest involved.

This follows GLOSSARY.md directly: Creator is defined as "the Participant who created a Game — a distinguishing role among Participants, not a separate entity." A `creator_id` on `Game` would make Creator a relation to a `User`, independent of Participant — contradicting that definition, and letting a Game exist with a Creator who isn't a Participant, or a Creator who left but is still referenced.

The alternative (`Game belongs_to :creator, class_name: "User"`) is the more obvious Rails shape and reads easier in simple queries ("who created this Game?"), but was rejected because it duplicates state that `Participant` must already track, and the two could drift (e.g. the Creator leaving without the column being cleared).

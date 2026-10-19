# Game Platform

A platform that hosts multiple types of games. Users register on the platform, then create, join, or leave Games of a given GameType.

## Language

**Platform**:
The product as a whole. Hosts multiple GameTypes that Users can play.

**GameType**:
A generic kind of game offered by the Platform (e.g. Planning Poker). Defines the rules; distinct from any specific instance being played.
_Avoid_: Game (when meaning the type rather than an instance)

**Game**:
A specific instance of a GameType being played by a group of Participants. Identified by a name, unique across the whole Platform, chosen by its Creator at creation time. Locatable by its name, by its URL, or via the public listing — but none of these grant entry directly; becoming a Participant always requires a JoinRequest.
_Avoid_: Partie, Session, Room

**User**:
An account registered on the Platform.
_Avoid_: Player, Account

**Participant**:
A User taking part in a specific Game.
_Avoid_: Player (reserved for a future GameType-specific role, e.g. Player vs Spectator in Planning Poker)

**Creator**:
The Participant who created a Game. A distinguishing role among Participants, not a separate entity.

**JoinRequest**:
A request submitted by a User to ask to become a Participant in a Game.
_Avoid_: Candidature, Demande

**Lobby**:
The state of a Game before it has started. Participants can join and leave freely.

**InProgress**:
The state of a Game once it has started.

## Rules

- Joining a Game requires being a registered User; anonymous access is not yet decided.
- All Games are listed publicly; there is no private/unlisted Game.
- Becoming a Participant always requires a JoinRequest, even when the Game was located by a known name or URL — there is no direct-join path.
- A User may submit at most 2 JoinRequests per Game (1 initial attempt + 1 retry after a rejection). The initial attempt may be accepted or rejected by the Creator or any current Participant; the retry may only be accepted or rejected by the Creator. After the retry is rejected, the User is permanently barred from that Game.
- If two decisions are recorded on the same JoinRequest near-simultaneously, the first one recorded is final; any later decision on that same request has no effect.
- A User can be a Participant in at most one Game at a time. Attempting to join another Game while already a Participant is rejected; the User must leave their current Game first.
- A Game's name must be unique across the whole Platform (not just within a GameType).
- A Game is deleted when its last Participant leaves.
- If the Creator leaves a Game that is still in the Lobby state, the Game is deleted immediately, even if other Participants remain (they are removed from the Game too).
- If the Creator leaves a Game that is InProgress, they must delegate the Creator role to another Participant. If delegated explicitly as part of leaving, that Participant becomes Creator immediately; otherwise, after a timeout, the Creator role is assigned at random among the remaining Participants.

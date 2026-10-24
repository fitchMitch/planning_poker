# Game Listing, JoinRequest, and Leaving a Game Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a signed-in Member see and join existing Planning Poker Games (via a JoinRequest that the Creator or any current Participant can accept/reject, per ADR 0001), see a minimal Game page once admitted, leave a Game explicitly or automatically after 30 minutes of inactivity, and see a preview of recent Games on the GameType dashboard.

**Architecture:** `Participant` gains a nullable `left_at` column so leaving never deletes history. A new `JoinRequest` model tracks the request lifecycle (pending/accepted/rejected) and enforces the 2-attempt limit. Leaving (explicit button or automatic timeout) runs through one shared `Participant#leave!` method so both triggers produce identical Ended/Creator-delegation consequences. A Stimulus controller pings a small endpoint every 5 minutes while a Participant is on their Game's page; a Solid Queue recurring job sweeps stale Participants every 5 minutes and calls the same `leave!` method.

**Tech Stack:** Rails 8.1, SQLite, Devise, Slim views, Stimulus (`stimulus-rails`, already installed), Solid Queue (already installed, `config/recurring.yml` already has one entry), RSpec + FactoryBot, Cucumber + Capybara.

**Spec:** GitHub issue #6 (`gh issue view 6`) — see also `GLOSSARY.md` (updated alongside that spec: `Participant`'s history note, and the inactivity-leave-equivalence rule) and `docs/adr/0001-join-requires-approval.md` for the JoinRequest authorization rules this plan implements.

## Global Constraints

- `Participant` rows are never deleted. Leaving sets `left_at: Time.current`; "active" means `left_at: nil`.
- `User#current_game` and the "one active Game per User" validation on `Participant` scope on `left_at: nil`, not on row existence.
- A JoinRequest's first attempt may be accepted or rejected by the Creator or any current (active) Participant of that Game. A retry may only be accepted or rejected by the Creator. A User gets at most 2 JoinRequests per Game (1 initial + 1 retry); a second rejection permanently bars that User from that Game.
- If two decisions land on the same JoinRequest near-simultaneously, the first one recorded wins; a later decision on an already-decided request has no effect.
- Leaving — whether via the explicit button or the automatic inactivity timeout — runs through the same code path and produces identical consequences: last active Participant leaving moves the Game to `Ended`; Creator leaving a `lobby` Game moves it to `Ended` immediately (remaining Participants are also set to left); Creator leaving an `in_progress` Game requires delegation (explicit choice at leave time, or random assignment among remaining active Participants if no explicit choice was made).
- The inactivity timeout is fixed at 30 minutes, checked by a Solid Queue recurring job running every 5 minutes. No per-GameType or admin-configurable threshold.
- The Games-listing page's "Toutes les parties" column shows only Games with `state` in `["lobby", "in_progress"]`. The dashboard's 5-most-recent preview has no state filter (Ended Games are included, a deliberate simplification per the spec).
- No Game-detail visibility for non-Participants: the minimal Game page (`GamesController#show`) is only reachable by that Game's current active Participants.
- Per CLAUDE.md: every task below that changes externally-observable behavior ships with passing Cucumber coverage, not just RSpec.

## Review Focus

- Accepting a JoinRequest while the requesting User has, in the meantime, joined a different Game (race between two JoinRequests being accepted for the same User) must be rejected by the existing "one active Game per User" validation — the acceptance path must not bypass that check just because it's not going through `GamesController#create`.
- A User whose retry JoinRequest is rejected must be unable to submit a third request for that Game — this is a permanent bar, not reset by the passage of time or Game state changes.
- The heartbeat endpoint must only extend the calling User's own `Participant#updated_at`, scoped to a Game they are an active Participant of — a Participant cannot ping on behalf of, or extend, someone else's row.
- A Creator leaving (explicitly or via timeout) an `in_progress` Game with multiple other active Participants and no explicit delegation choice must still end up with exactly one Creator afterward (the random-assignment fallback must actually run, not leave the Game Creator-less).
- The Games-listing page's two columns must each independently handle the "no Games to show" case (a GameType with no open Games yet, or a Member with no participation history) without erroring or rendering a broken list.

---

## Task 1: `Participant#left_at`, scoped `current_game`, and `leave!`

**Files:**
- Create: `db/migrate/20261025000001_add_left_at_to_participants.rb`
- Modify: `app/models/participant.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/game.rb`
- Test: `spec/models/participant_spec.rb` (extend existing file)
- Test: `spec/models/user_spec.rb` (extend existing file)

**Interfaces:**
- Consumes: existing `Game`, `User`, `Participant` (name, slug, description, state="lobby" default; `Game` has no other state values defined yet).
- Produces: `Participant#left_at` (nullable datetime); `Participant.active` scope (`where(left_at: nil)`); `Participant#leave!` — sets `left_at`, and if this Participant was the last active one for their Game, sets `Game#state = "ended"`; if they were the Creator of a Game still in `"lobby"`, sets `Game#state = "ended"` and calls `leave!` on all other active Participants of that Game too (recursively safe — those calls find no further active Participants needing cascading, since this one call already covers them); if they were the Creator of a Game `"in_progress"` with other active Participants remaining and no explicit successor given, promotes one random remaining active Participant to `creator: true`. `Participant#leave!` accepts an optional `successor:` keyword (a `Participant`) for the explicit-delegation case — Task 5 wires this from the controller. `User#current_game` now returns `participants.active.first&.game`. `Game.has_many :participants` unchanged; this task adds no new `Game` scopes (Task 6 adds those).

- [ ] **Step 1: Write the migration**

```ruby
class AddLeftAtToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :left_at, :datetime
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `participants.left_at` column added, `db/schema.rb` updated.

- [ ] **Step 3: Write the failing tests for `left_at` scoping**

Add to `spec/models/participant_spec.rb`:

```ruby
RSpec.describe Participant, type: :model do
  # ... existing examples stay ...

  describe ".active" do
    it "excludes participants who have left" do
      left_participant = create(:participant, left_at: Time.current)
      active_participant = create(:participant)
      expect(Participant.active).to contain_exactly(active_participant)
    end
  end

  it "allows a user to join a new game once they've left their previous one" do
    user = create(:user)
    old_game = create(:game)
    create(:participant, game: old_game, user: user, left_at: 1.hour.ago)
    new_participant = build(:participant, user: user)
    expect(new_participant).to be_valid
  end
end
```

Add to `spec/models/user_spec.rb`:

```ruby
describe "#current_game" do
  # ... existing examples stay ...

  it "ignores a game the user has left" do
    participant = create(:participant, left_at: Time.current)
    expect(participant.user.current_game).to be_nil
  end
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/participant_spec.rb spec/models/user_spec.rb`
Expected: FAIL — the "allows a user to join" test fails because the current validation checks row existence, not `left_at`; `.active` is undefined.

- [ ] **Step 5: Update `Participant`'s validation and add the `active` scope in `app/models/participant.rb`**

```ruby
class Participant < ApplicationRecord
  belongs_to :game
  belongs_to :user

  scope :active, -> { where(left_at: nil) }

  validate :user_has_no_other_active_game, on: :create

  private

  def user_has_no_other_active_game
    return if user.nil?
    return unless user.participants.active.where.not(game_id: game_id).exists?

    errors.add(:user, "is already participating in another game")
  end
end
```

- [ ] **Step 6: Update `User#current_game` in `app/models/user.rb`**

```ruby
def current_game
  participants.active.first&.game
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/participant_spec.rb spec/models/user_spec.rb`
Expected: PASS.

- [ ] **Step 8: Write the failing tests for `Participant#leave!`**

Add to `spec/models/participant_spec.rb`:

```ruby
describe "#leave!" do
  it "sets left_at" do
    participant = create(:participant)
    participant.leave!
    expect(participant.reload.left_at).not_to be_nil
  end

  it "ends the game when the last active participant leaves" do
    participant = create(:participant)
    participant.leave!
    expect(participant.game.reload.state).to eq("ended")
  end

  it "ends a lobby game immediately when its creator leaves, taking remaining participants with it" do
    game = create(:game, state: "lobby")
    creator = create(:participant, game: game, creator: true)
    other = create(:participant, game: game)

    creator.leave!

    expect(game.reload.state).to eq("ended")
    expect(other.reload.left_at).not_to be_nil
  end

  it "promotes a random remaining active participant to creator when the creator leaves an in_progress game with no successor given" do
    game = create(:game, state: "in_progress")
    creator = create(:participant, game: game, creator: true)
    other = create(:participant, game: game)

    creator.leave!

    expect(other.reload.creator).to eq(true)
    expect(game.reload.state).to eq("in_progress")
  end

  it "promotes an explicitly given successor when the creator leaves an in_progress game" do
    game = create(:game, state: "in_progress")
    creator = create(:participant, game: game, creator: true)
    chosen_successor = create(:participant, game: game)
    create(:participant, game: game) # a third participant, not chosen

    creator.leave!(successor: chosen_successor)

    expect(chosen_successor.reload.creator).to eq(true)
  end
end
```

- [ ] **Step 9: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/participant_spec.rb`
Expected: FAIL — `NoMethodError: leave!`.

- [ ] **Step 10: Implement `Participant#leave!(successor: nil)` in `app/models/participant.rb`**

Add below the `active` scope, above `private`:

```ruby
def leave!(successor: nil)
  transaction do
    update!(left_at: Time.current)
    remaining = game.participants.active.where.not(id: id)

    if remaining.none?
      game.update!(state: "ended")
    elsif creator? && game.state == "lobby"
      game.update!(state: "ended")
      remaining.each(&:leave!)
    elsif creator? && game.state == "in_progress"
      next_creator = successor || remaining.sample
      next_creator.update!(creator: true)
    end
  end
end
```

One line on the approach: `remaining.sample` gives the "random assignment" the spec calls for; `remaining.each(&:leave!)` is safe from infinite recursion because each of those calls finds `remaining.none?` true for itself once enough prior iterations have already set their own `left_at` (ActiveRecord re-queries `game.participants.active` fresh each call, so it reflects completed updates from earlier iterations in the same `each`).

- [ ] **Step 11: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/participant_spec.rb spec/models/user_spec.rb`
Expected: PASS.

- [ ] **Step 12: Run the full RSpec suite to confirm no regressions**

Run: `bundle exec rspec`
Expected: all green (existing Game/GameType/Participant/User/request specs unaffected).

- [ ] **Step 13: Commit**

```bash
git add db/migrate/20261025000001_add_left_at_to_participants.rb db/schema.rb app/models/participant.rb app/models/user.rb spec/models/participant_spec.rb spec/models/user_spec.rb
git commit -m "feat: add Participant#left_at and #leave! with Ended/delegation rules"
```

---

## Task 2: `JoinRequest` model

**Files:**
- Create: `db/migrate/20261025000002_create_join_requests.rb`
- Create: `app/models/join_request.rb`
- Create: `spec/factories/join_requests.rb`
- Test: `spec/models/join_request_spec.rb`

**Interfaces:**
- Consumes: `Game` (Task's existing model), `User` (existing), `Participant` including left-but-not-active rows (Task 1 — `left_at` is what scopes the reset below).
- Produces: `JoinRequest` with `game_id`, `user_id`, `status:string` (`"pending"`/`"accepted"`/`"rejected"`, default `"pending"`). The 2-attempt count resets every time the User leaves that Game and comes back — it is not a lifetime count. `JoinRequest.current_cycle_for(game:, user:)` class method — returns the `JoinRequest` relation scoped to attempts made after that User's most recent `Participant#left_at` for this `game` (or all of them, if the User has never had a `Participant` row for this `game` at all — i.e. this is their very first cycle). `JoinRequest.barred?(game:, user:)` — `true` if `current_cycle_for(...)` already has a `"rejected"` request that was itself a retry within that same cycle (2nd rejection since the last return). `JoinRequest#retry?` — `true` if this is the User's 2nd `JoinRequest` within its own cycle (scoped the same way). Task 3 calls `JoinRequest.barred?` before allowing a new request; Task 4 calls `#retry?` to decide who may act on it.

- [ ] **Step 1: Write the migration**

```ruby
class CreateJoinRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :join_requests do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `join_requests` table created, FKs to `games`/`users`.

- [ ] **Step 3: Write the factory**

```ruby
FactoryBot.define do
  factory :join_request do
    game
    user
  end
end
```

- [ ] **Step 4: Write the failing tests**

```ruby
require "rails_helper"

RSpec.describe JoinRequest, type: :model do
  it "requires a game" do
    expect(build(:join_request, game: nil)).not_to be_valid
  end

  it "requires a user" do
    expect(build(:join_request, user: nil)).not_to be_valid
  end

  it "defaults to pending" do
    expect(create(:join_request).status).to eq("pending")
  end

  describe ".barred?" do
    it "is false with no prior join requests" do
      game = create(:game)
      user = create(:user)
      expect(JoinRequest.barred?(game: game, user: user)).to eq(false)
    end

    it "is false after a single rejected attempt (the user may retry)" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      expect(JoinRequest.barred?(game: game, user: user)).to eq(false)
    end

    it "is true after a second rejected attempt" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      create(:join_request, game: game, user: user, status: "rejected")
      expect(JoinRequest.barred?(game: game, user: user)).to eq(true)
    end

    it "resets once the user has left and returned — a prior cycle's 2 rejections don't carry over" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      create(:join_request, game: game, user: user, status: "rejected")
      # the user was eventually accepted (in reality, after a 3rd request this
      # spec doesn't model directly) and then left:
      create(:participant, game: game, user: user, left_at: 1.hour.ago)

      expect(JoinRequest.barred?(game: game, user: user)).to eq(false)
    end
  end

  describe "#retry?" do
    it "is false for a user's first request on a game" do
      join_request = create(:join_request)
      expect(join_request.retry?).to eq(false)
    end

    it "is true for a user's second request on the same game" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      second = create(:join_request, game: game, user: user)
      expect(second.retry?).to eq(true)
    end

    it "is false for a request made in a new cycle after the user left and returned" do
      game = create(:game)
      user = create(:user)
      create(:join_request, game: game, user: user, status: "rejected")
      create(:participant, game: game, user: user, left_at: 1.hour.ago)
      new_cycle_request = create(:join_request, game: game, user: user)

      expect(new_cycle_request.retry?).to eq(false)
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/join_request_spec.rb`
Expected: FAIL — `uninitialized constant JoinRequest`.

- [ ] **Step 6: Implement `JoinRequest` in `app/models/join_request.rb`**

```ruby
class JoinRequest < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validates :status, inclusion: { in: %w[pending accepted rejected] }

  def self.current_cycle_for(game:, user:)
    last_left_at = Participant.where(game: game, user: user).maximum(:left_at)
    scope = where(game: game, user: user)
    last_left_at ? scope.where("created_at > ?", last_left_at) : scope
  end

  def self.barred?(game:, user:)
    current_cycle_for(game: game, user: user).where(status: "rejected").count >= 2
  end

  def retry?
    self.class.current_cycle_for(game: game, user: user).where("id < ?", id).exists?
  end
end
```

One line on the approach: `Participant.where(...).maximum(:left_at)` finds the User's most recent departure from this `game` (`nil` if they've never had a `Participant` row there at all, meaning this is their first cycle and nothing resets); `current_cycle_for` then filters `JoinRequest`s to those created after that point.

Add the inverse association `has_many :join_requests` to `app/models/game.rb` (append after `has_many :participants`):

```ruby
has_many :join_requests
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/join_request_spec.rb`
Expected: PASS (12 examples).

- [ ] **Step 8: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 9: Commit**

```bash
git add db/migrate/20261025000002_create_join_requests.rb db/schema.rb app/models/join_request.rb app/models/game.rb spec/factories/join_requests.rb spec/models/join_request_spec.rb
git commit -m "feat: add JoinRequest model with 2-attempt bar rule"
```

---

## Task 3: Submitting a JoinRequest

**Files:**
- Create: `app/controllers/join_requests_controller.rb`
- Modify: `config/routes.rb`
- Test: `spec/requests/join_requests_spec.rb`

**Interfaces:**
- Consumes: `JoinRequest` (Task 2), `Game` (existing), `Participant.active`/`user_has_no_other_active_game` (Task 1).
- Produces: `POST /games/:game_id/join_requests` → creates a `pending` `JoinRequest` for `current_user`. Task 7 (Game-listing page) links to this. Route name: `game_join_requests_path(game_id)`.

- [ ] **Step 1: Add the route in `config/routes.rb`**

Add a top-level `resources :games` block (separate from the nested one under `game_types`, since `JoinRequest`/`show`/`leave` act on a `Game` directly by id, not scoped to a GameType slug):

```ruby
resources :games, only: [ :index, :show ] do
  resources :join_requests, only: [ :create ]
  post "leave", on: :member
end
```

(Task 6 and 7 add the `:index`/`:show` actions this route block also declares; this task only implements `join_requests`.)

- [ ] **Step 2: Write the failing request specs**

```ruby
require "rails_helper"

RSpec.describe "JoinRequests", type: :request do
  let(:game) { create(:game) }
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates a pending join request" do
    post game_join_requests_path(game)
    expect(JoinRequest.last).to have_attributes(game: game, user: user, status: "pending")
  end

  it "rejects a user barred by two prior rejections" do
    create(:join_request, game: game, user: user, status: "rejected")
    create(:join_request, game: game, user: user, status: "rejected")

    expect {
      post game_join_requests_path(game)
    }.not_to change(JoinRequest, :count)
    expect(response).to have_http_status(:forbidden)
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/join_requests_spec.rb`
Expected: FAIL — `uninitialized constant JoinRequestsController`.

- [ ] **Step 4: Implement `app/controllers/join_requests_controller.rb`**

```ruby
class JoinRequestsController < ApplicationController
  before_action :authenticate_user!

  def create
    game = Game.find(params[:game_id])
    if JoinRequest.barred?(game: game, user: current_user)
      return head :forbidden
    end

    JoinRequest.create!(game: game, user: current_user)
    redirect_to games_path
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/join_requests_spec.rb`
Expected: PASS (2 examples).

- [ ] **Step 6: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/join_requests_controller.rb spec/requests/join_requests_spec.rb
git commit -m "feat: add JoinRequest submission endpoint"
```

---

## Task 4: Accepting and rejecting a JoinRequest

**Files:**
- Modify: `app/controllers/join_requests_controller.rb`
- Modify: `config/routes.rb`
- Test: `spec/requests/join_requests_spec.rb` (extend)

**Interfaces:**
- Consumes: `JoinRequest#retry?` (Task 2), `Participant.active` (Task 1), `Participant` creation pattern from `GamesController#create` (existing: `Participant.create!(game:, user:, creator: false)`).
- Produces: `PATCH /join_requests/:id/accept`, `PATCH /join_requests/:id/reject`. Both are idempotent against a already-decided request (second call has no effect, per the "first decision wins" global constraint).

- [ ] **Step 1: Add routes in `config/routes.rb`**

Replace the `resources :join_requests, only: [ :create ]` nested block with a top-level member-action set (accept/reject act on a `JoinRequest` by its own id, not nested under `games`):

```ruby
resources :join_requests, only: [] do
  patch "accept", on: :member
  patch "reject", on: :member
end
```

Keep the nested `resources :join_requests, only: [ :create ]` under `games` from Task 3 — both blocks coexist (`create` is nested under its `Game`, `accept`/`reject` act directly on the `JoinRequest`'s own id).

- [ ] **Step 2: Write the failing request specs**

Add to `spec/requests/join_requests_spec.rb`:

```ruby
describe "PATCH /join_requests/:id/accept" do
  it "lets any current active participant accept a first attempt" do
    game = create(:game)
    deciding_participant = create(:participant, game: game)
    join_request = create(:join_request, game: game)
    sign_in deciding_participant.user

    patch accept_join_request_path(join_request)

    expect(join_request.reload.status).to eq("accepted")
    expect(Participant.active.exists?(game: game, user: join_request.user)).to eq(true)
  end

  it "rejects acceptance from a non-participant" do
    join_request = create(:join_request)
    sign_in create(:user)

    patch accept_join_request_path(join_request)

    expect(join_request.reload.status).to eq("pending")
    expect(response).to have_http_status(:forbidden)
  end

  it "only lets the creator accept a retry" do
    game = create(:game)
    creator = create(:participant, game: game, creator: true)
    other_participant = create(:participant, game: game)
    user = create(:user)
    create(:join_request, game: game, user: user, status: "rejected")
    retry_request = create(:join_request, game: game, user: user)
    sign_in other_participant.user

    patch accept_join_request_path(retry_request)

    expect(retry_request.reload.status).to eq("pending")
    expect(response).to have_http_status(:forbidden)
  end

  it "does not change an already-decided request" do
    join_request = create(:join_request, status: "accepted")
    deciding_participant = create(:participant, game: join_request.game)
    sign_in deciding_participant.user

    patch reject_join_request_path(join_request)

    expect(join_request.reload.status).to eq("accepted")
  end

  it "rejects the request instead of accepting it when the user has since joined another game" do
    game = create(:game)
    deciding_participant = create(:participant, game: game)
    join_request = create(:join_request, game: game)
    create(:participant, user: join_request.user) # joined a different game meanwhile
    sign_in deciding_participant.user

    patch accept_join_request_path(join_request)

    expect(join_request.reload.status).to eq("rejected")
    expect(Participant.active.exists?(game: game, user: join_request.user)).to eq(false)
  end
end

describe "PATCH /join_requests/:id/reject" do
  it "lets any current active participant reject a first attempt" do
    game = create(:game)
    deciding_participant = create(:participant, game: game)
    join_request = create(:join_request, game: game)
    sign_in deciding_participant.user

    patch reject_join_request_path(join_request)

    expect(join_request.reload.status).to eq("rejected")
  end

  it "permanently bars the user after a second rejection" do
    game = create(:game)
    creator = create(:participant, game: game, creator: true)
    user = create(:user)
    create(:join_request, game: game, user: user, status: "rejected")
    retry_request = create(:join_request, game: game, user: user)
    sign_in creator.user

    patch reject_join_request_path(retry_request)

    expect(JoinRequest.barred?(game: game, user: user)).to eq(true)
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/join_requests_spec.rb`
Expected: FAIL — `accept`/`reject` actions undefined.

- [ ] **Step 4: Implement `accept`/`reject` in `app/controllers/join_requests_controller.rb`**

```ruby
class JoinRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_join_request, only: [ :accept, :reject ]

  def create
    game = Game.find(params[:game_id])
    return head :forbidden if JoinRequest.barred?(game: game, user: current_user)

    JoinRequest.create!(game: game, user: current_user)
    redirect_to games_path
  end

  def accept
    return head :forbidden unless authorized_to_decide?
    return if @join_request.status != "pending"

    Participant.create!(game: @join_request.game, user: @join_request.user, creator: false)
    @join_request.update!(status: "accepted")
    redirect_to game_path(@join_request.game)
  rescue ActiveRecord::RecordInvalid
    @join_request.update!(status: "rejected")
    redirect_to game_path(@join_request.game)
  end

  def reject
    return head :forbidden unless authorized_to_decide?
    return if @join_request.status != "pending"

    @join_request.update!(status: "rejected")
    redirect_to game_path(@join_request.game)
  end

  private

  def set_join_request
    @join_request = JoinRequest.find(params[:id])
  end

  def authorized_to_decide?
    game = @join_request.game
    is_participant = Participant.active.exists?(game: game, user: current_user)
    return false unless is_participant

    return true unless @join_request.retry?

    Participant.active.exists?(game: game, user: current_user, creator: true)
  end
end
```

One line on the approach: `authorized_to_decide?` implements the rule directly — any active Participant may decide a first attempt, only the active Creator may decide a retry; `return if @join_request.status != "pending"` makes both actions a no-op against an already-decided request (first-decision-wins).

- [ ] **Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/join_requests_spec.rb`
Expected: PASS.

- [ ] **Step 6: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/join_requests_controller.rb spec/requests/join_requests_spec.rb
git commit -m "feat: add JoinRequest accept/reject with ADR 0001 authorization"
```

---

## Task 5: Explicit leave action

**Files:**
- Create: `app/controllers/games_controller.rb` additions (modify existing file)
- Test: `spec/requests/games_spec.rb` (extend existing file)

**Interfaces:**
- Consumes: `Participant#leave!` (Task 1).
- Produces: `POST /games/:id/leave` → calls `leave!` on `current_user`'s active `Participant` row for that `Game`. Route already declared in Task 3 (`post "leave", on: :member`).

- [ ] **Step 1: Write the failing request specs**

Add to `spec/requests/games_spec.rb`:

```ruby
describe "POST /games/:id/leave" do
  it "lets a participant leave their game" do
    participant = create(:participant)
    sign_in participant.user

    post leave_game_path(participant.game)

    expect(participant.reload.left_at).not_to be_nil
  end

  it "does nothing if the user is not a participant of that game" do
    game = create(:game)
    sign_in create(:user)

    expect { post leave_game_path(game) }.not_to raise_error
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: FAIL — route or action missing (depending on whether Task 3's route addition already landed; if the route exists but the action doesn't, you'll see a routing error naming the missing controller action).

- [ ] **Step 3: Implement `leave` in `app/controllers/games_controller.rb`**

Add `before_action :authenticate_user!` is already present; add the action:

```ruby
def leave
  game = Game.find(params[:id])
  participant = game.participants.active.find_by(user: current_user)
  participant&.leave!
  redirect_to games_path
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: PASS.

- [ ] **Step 5: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/games_controller.rb spec/requests/games_spec.rb
git commit -m "feat: add explicit leave-a-game action"
```

---

## Task 6: Games-listing page

**Files:**
- Modify: `app/controllers/games_controller.rb`
- Modify: `app/models/game.rb`
- Create: `app/views/games/index.html.slim`
- Modify: `app/views/game_types/show.html.slim` (point "Toutes les parties"/"Parcourir les parties" at the new page)
- Test: `spec/requests/games_spec.rb` (extend)

**Interfaces:**
- Consumes: `Game` (existing), `Participant.active` (Task 1), `current_user.participants` (existing `has_many`).
- Produces: `GET /games` → `@open_games` (all Games with `state` in `["lobby", "in_progress"]`) and `@my_games` (every Game where `current_user` has ever had a `Participant` row, active or not). `Game.open` scope (`where(state: %w[lobby in_progress])`) usable by Task 8 too.

- [ ] **Step 1: Add the `Game.open` scope in `app/models/game.rb`**

```ruby
scope :open, -> { where(state: %w[lobby in_progress]) }
```

- [ ] **Step 2: Write the failing request specs**

Add to `spec/requests/games_spec.rb`:

```ruby
describe "GET /games" do
  it "lists open games" do
    open_game = create(:game, state: "lobby")
    create(:game, state: "ended")
    sign_in create(:user)

    get games_path

    expect(response.body).to include(open_game.name)
  end

  it "lists the signed-in user's participation history, including left and ended games" do
    user = create(:user)
    past_participant = create(:participant, user: user, left_at: 1.day.ago)
    sign_in user

    get games_path

    expect(response.body).to include(past_participant.game.name)
  end

  it "renders without error when there are no games at all" do
    sign_in create(:user)
    get games_path
    expect(response).to have_http_status(:success)
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: FAIL — `index` action/view missing.

- [ ] **Step 4: Implement `index` in `app/controllers/games_controller.rb`**

```ruby
def index
  @open_games = Game.open
  @my_games = Game.joins(:participants).where(participants: { user: current_user }).distinct
end
```

- [ ] **Step 5: Create `app/views/games/index.html.slim`**

Two columns side by side, no tabs. For "Mes parties", a Game is rejoinable if `game.state != "ended"` and the current user's `Participant` row for it has `left_at: nil`; otherwise it's shown as dead (no join/rejoin action, just a label). Use existing `ds-card`/`ds-btn` classes:

```slim
.ds-root
  h1.ds-heading-xl Les parties

  .games-columns
    section
      h2.ds-heading-lg Toutes les parties
      - if @open_games.none?
        p.ds-body-sm Aucune partie ouverte pour le moment.
      - else
        - @open_games.each do |game|
          .ds-card
            h3.ds-heading-md = game.name
            p.ds-body-sm = game.description
            - pending = JoinRequest.exists?(game: game, user: current_user, status: "pending")
            - if pending
              button.ds-btn.ds-btn-secondary type="button" disabled=true En attente
            - else
              = button_to "Demander à rejoindre", game_join_requests_path(game), class: "ds-btn ds-btn-primary"

    section
      h2.ds-heading-lg Mes parties
      - if @my_games.none?
        p.ds-body-sm Vous n'avez participé à aucune partie.
      - else
        - @my_games.each do |game|
          - participant = game.participants.find_by(user: current_user)
          - rejoinable = game.state != "ended" && participant.left_at.nil?
          .ds-card
            h3.ds-heading-md = game.name
            - if rejoinable
              = link_to "Retourner à la partie", game_path(game), class: "ds-btn ds-btn-primary"
            - else
              span.ds-hint Terminée
```

- [ ] **Step 6: Update `app/views/game_types/show.html.slim`'s dead links**

Replace both `li: a href="#" Toutes les parties` and `a.ds-btn.ds-btn-secondary href="#" Parcourir les parties` with `= link_to "Toutes les parties", games_path, class: "..."` / `= link_to "Parcourir les parties", games_path, class: "ds-btn ds-btn-secondary"`, keeping each element's existing classes unchanged (only the `href="#"` becomes a real link).

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: PASS.

- [ ] **Step 8: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 9: Commit**

```bash
git add app/controllers/games_controller.rb app/models/game.rb app/views/games/index.html.slim app/views/game_types/show.html.slim spec/requests/games_spec.rb
git commit -m "feat: add Games-listing page with open-games and my-games columns"
```

---

## Task 7: Minimal Game page

**Files:**
- Modify: `app/controllers/games_controller.rb`
- Create: `app/views/games/show.html.slim`
- Test: `spec/requests/games_spec.rb` (extend)

**Interfaces:**
- Consumes: `Participant.active` (Task 1), `JoinRequest` (Task 2), `accept_join_request_path`/`reject_join_request_path` (Task 4), `leave_game_path` (Task 5, route already declared).
- Produces: `GET /games/:id` → `@game`, `@participants` (active ones), `@pending_join_requests` (visible only if `current_user` is an active Participant). Non-Participants get redirected, not a rendered page.

- [ ] **Step 1: Write the failing request specs**

Add to `spec/requests/games_spec.rb`:

```ruby
describe "GET /games/:id" do
  it "shows the game to one of its active participants" do
    participant = create(:participant)
    sign_in participant.user

    get game_path(participant.game)

    expect(response).to have_http_status(:success)
    expect(response.body).to include(participant.game.name)
  end

  it "redirects a non-participant away" do
    game = create(:game)
    sign_in create(:user)

    get game_path(game)

    expect(response).to redirect_to(games_path)
  end

  it "shows pending join requests to an active participant" do
    participant = create(:participant)
    join_request = create(:join_request, game: participant.game)
    sign_in participant.user

    get game_path(participant.game)

    expect(response.body).to include(join_request.user.email)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: FAIL — `show` action/view missing.

- [ ] **Step 3: Implement `show` in `app/controllers/games_controller.rb`**

```ruby
def show
  @game = Game.find(params[:id])
  @current_participant = @game.participants.active.find_by(user: current_user)
  return redirect_to(games_path) unless @current_participant

  @participants = @game.participants.active
  @pending_join_requests = @game.join_requests.where(status: "pending")
end
```

- [ ] **Step 4: Create `app/views/games/show.html.slim`**

```slim
.ds-root
  h1.ds-heading-xl = @game.name
  p.ds-body = @game.description

  section
    h2.ds-heading-lg Participants
    ul
      - @participants.each do |participant|
        li = participant.user.email + (participant.creator? ? " (créateur)" : "")

  - if @pending_join_requests.any?
    section
      h2.ds-heading-lg Demandes en attente
      - @pending_join_requests.each do |join_request|
        .ds-card
          span = join_request.user.email
          = button_to "Accepter", accept_join_request_path(join_request), method: :patch, class: "ds-btn ds-btn-primary"
          = button_to "Refuser", reject_join_request_path(join_request), method: :patch, class: "ds-btn ds-btn-secondary"

  = button_to "Quitter la partie", leave_game_path(@game), method: :post, class: "ds-btn ds-btn-secondary"
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: PASS.

- [ ] **Step 6: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/games_controller.rb app/views/games/show.html.slim spec/requests/games_spec.rb
git commit -m "feat: add minimal Game page with participants and pending join requests"
```

---

## Task 8: Dashboard recent-Games preview

**Files:**
- Modify: `app/controllers/game_types_controller.rb`
- Modify: `app/views/game_types/show.html.slim`
- Test: `spec/requests/game_types_spec.rb` (extend)

**Interfaces:**
- Consumes: `Game` (existing, scoped by `game_type`), no state filter (Ended Games included, per Global Constraints).
- Produces: `@recent_games` (5 most recent Games of `@game_type`, ordered by `created_at` descending) available in `game_types#show`.

- [ ] **Step 1: Write the failing request spec**

Add to `spec/requests/game_types_spec.rb`:

```ruby
describe "GET /game_types/:slug recent games preview" do
  it "shows up to 5 of the game type's most recently created games" do
    game_type = create(:game_type)
    6.times { |n| create(:game, game_type: game_type, name: "Game #{n}") }
    sign_in create(:user)

    get game_type_path(game_type.slug)

    expect(response.body).to include("Game 5") # most recent
    expect(response.body).not_to include("Game 0") # 6th-oldest, excluded
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/game_types_spec.rb`
Expected: FAIL — preview not present in the response body.

- [ ] **Step 3: Add `@recent_games` to `show` in `app/controllers/game_types_controller.rb`**

```ruby
def show
  @game_type = GameType.find_by!(slug: params[:slug])
  @recent_games = @game_type.games.order(created_at: :desc).limit(5)
end
```

(Requires `GameType has_many :games` — add this association to `app/models/game_type.rb` if not already present; check the file first, since `Game belongs_to :game_type` already exists but the inverse `has_many` may not.)

- [ ] **Step 4: Add the preview section to `app/views/game_types/show.html.slim`**

Insert after the `main.hero` block, inside the `user_signed_in?` branch only (signed-out visitors don't see this):

```slim
section
  h2.ds-heading-lg Parties récentes
  - @recent_games.each do |game|
    .ds-card
      span.ds-body-sm = game.name
  = link_to "Voir toutes les parties", games_path, class: "ds-btn ds-btn-secondary"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/game_types_spec.rb`
Expected: PASS.

- [ ] **Step 6: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/game_types_controller.rb app/models/game_type.rb app/views/game_types/show.html.slim spec/requests/game_types_spec.rb
git commit -m "feat: add recent-games preview to the GameType dashboard"
```

---

## Task 9: Inactivity timeout (heartbeat + recurring job)

**Files:**
- Create: `app/controllers/heartbeats_controller.rb`
- Create: `app/javascript/controllers/heartbeat_controller.js`
- Modify: `app/views/games/show.html.slim`
- Create: `app/jobs/expire_inactive_participants_job.rb`
- Modify: `config/routes.rb`
- Modify: `config/recurring.yml`
- Test: `spec/requests/heartbeats_spec.rb`
- Test: `spec/jobs/expire_inactive_participants_job_spec.rb`

**Interfaces:**
- Consumes: `Participant.active`, `Participant#leave!` (Task 1).
- Produces: `POST /games/:id/heartbeat` → touches `current_user`'s active `Participant#updated_at` for that Game. `ExpireInactiveParticipantsJob.perform_now` — finds `Participant.active.where("updated_at < ?", 30.minutes.ago)` and calls `leave!` on each.

- [ ] **Step 1: Add the route in `config/routes.rb`**

Inside the existing `resources :games` block, alongside `leave`:

```ruby
post "heartbeat", on: :member
```

- [ ] **Step 2: Write the failing request spec**

```ruby
# spec/requests/heartbeats_spec.rb
require "rails_helper"

RSpec.describe "Heartbeats", type: :request do
  it "touches the current user's participant row for that game" do
    participant = create(:participant, updated_at: 1.hour.ago)
    sign_in participant.user

    post heartbeat_game_path(participant.game)

    expect(participant.reload.updated_at).to be_within(5.seconds).of(Time.current)
  end

  it "does not touch another user's participant row" do
    other_participant = create(:participant, updated_at: 1.hour.ago)
    sign_in create(:user)

    post heartbeat_game_path(other_participant.game)

    expect(other_participant.reload.updated_at).to be_within(1.second).of(1.hour.ago)
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec rspec spec/requests/heartbeats_spec.rb`
Expected: FAIL — `uninitialized constant HeartbeatsController`.

- [ ] **Step 4: Implement `app/controllers/heartbeats_controller.rb`**

```ruby
class HeartbeatsController < ApplicationController
  before_action :authenticate_user!

  def create
    game = Game.find(params[:game_id])
    participant = game.participants.active.find_by(user: current_user)
    participant&.touch
    head :no_content
  end
end
```

Route this controller's action from the `post "heartbeat", on: :member` line added in Step 1 — since that's declared under `resources :games`, point it at `heartbeats#create` explicitly:

```ruby
resources :games, only: [ :index, :show ] do
  resources :join_requests, only: [ :create ]
  post "leave", on: :member
  post "heartbeat", on: :member, to: "heartbeats#create"
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec rspec spec/requests/heartbeats_spec.rb`
Expected: PASS.

- [ ] **Step 6: Write the failing job test**

```ruby
# spec/jobs/expire_inactive_participants_job_spec.rb
require "rails_helper"

RSpec.describe ExpireInactiveParticipantsJob, type: :job do
  it "leaves participants inactive for more than 30 minutes" do
    stale_participant = create(:participant)
    stale_participant.update_column(:updated_at, 31.minutes.ago)
    fresh_participant = create(:participant)

    described_class.perform_now

    expect(stale_participant.reload.left_at).not_to be_nil
    expect(fresh_participant.reload.left_at).to be_nil
  end
end
```

- [ ] **Step 7: Run test to verify it fails**

Run: `bundle exec rspec spec/jobs/expire_inactive_participants_job_spec.rb`
Expected: FAIL — `uninitialized constant ExpireInactiveParticipantsJob`.

- [ ] **Step 8: Implement `app/jobs/expire_inactive_participants_job.rb`**

```ruby
class ExpireInactiveParticipantsJob < ApplicationJob
  def perform
    Participant.active.where(updated_at: ...30.minutes.ago).find_each(&:leave!)
  end
end
```

- [ ] **Step 9: Run test to verify it passes**

Run: `bundle exec rspec spec/jobs/expire_inactive_participants_job_spec.rb`
Expected: PASS.

- [ ] **Step 10: Register the recurring schedule in `config/recurring.yml`**

Add alongside the existing `production:` block a `development:`/shared entry, or (simpler, matching the existing file's only block) extend `production:` — check the file's current content first; this plan assumes only a `production:` key exists today. Add under it:

```yaml
production:
  clear_solid_queue_finished_jobs:
    command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
    schedule: every hour at minute 12
  expire_inactive_participants:
    class: ExpireInactiveParticipantsJob
    schedule: every 5 minutes
```

- [ ] **Step 11: Create the Stimulus controller `app/javascript/controllers/heartbeat_controller.js`**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.ping()
    this.interval = setInterval(() => this.ping(), 5 * 60 * 1000)
  }

  disconnect() {
    clearInterval(this.interval)
  }

  ping() {
    fetch(this.urlValue, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
    })
  }
}
```

- [ ] **Step 12: Wire the controller onto `app/views/games/show.html.slim`**

Add `data-controller="heartbeat" data-heartbeat-url-value="#{heartbeat_game_path(@game)}"` to the root `.ds-root` element at the top of the file.

- [ ] **Step 13: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 14: Commit**

```bash
git add config/routes.rb config/recurring.yml app/controllers/heartbeats_controller.rb app/javascript/controllers/heartbeat_controller.js app/jobs/expire_inactive_participants_job.rb app/views/games/show.html.slim spec/requests/heartbeats_spec.rb spec/jobs/expire_inactive_participants_job_spec.rb
git commit -m "feat: add heartbeat-based inactivity timeout"
```

---

## Task 10: Cucumber acceptance coverage

**Files:**
- Create: `features/game_listing.feature`
- Create: `features/join_request.feature`
- Create: `features/leaving_a_game.feature`
- Create/modify: `features/step_definitions/join_request_steps.rb`

**Interfaces:**
- Consumes: everything from Tasks 1–9.
- Produces: no new interfaces; acceptance coverage per CLAUDE.md's standing instruction.

- [ ] **Step 1: Write `features/game_listing.feature`**

```gherkin
Feature: Game listing

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And I am logged in as "alice@example.com"

  Scenario: A member sees an open game in "Toutes les parties"
    Given a game named "Sprint 50" exists for the Planning Poker game type
    When I visit the games list
    Then I should see "Sprint 50"

  Scenario: A member sees their own past participation in "Mes parties"
    Given I am already participating in a game named "Sprint 51"
    When I visit the games list
    Then I should see "Sprint 51"
```

- [ ] **Step 2: Write `features/join_request.feature`**

```gherkin
Feature: Requesting to join a game

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And a user exists with email "bob@example.com"
    And "alice@example.com" created a game named "Sprint 60"

  Scenario: A member requests to join an open game
    Given I am logged in as "bob@example.com"
    When I visit the games list
    And I request to join "Sprint 60"
    Then I should see "En attente"

  Scenario: The creator accepts a join request
    Given "bob@example.com" has requested to join "Sprint 60"
    And I am logged in as "alice@example.com"
    When I visit the game page for "Sprint 60"
    And I accept the join request from "bob@example.com"
    Then "bob@example.com" becomes a participant of "Sprint 60"
```

- [ ] **Step 3: Write `features/leaving_a_game.feature`**

```gherkin
Feature: Leaving a game

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And I am logged in as "alice@example.com"
    And I am already participating in a game named "Sprint 70"

  Scenario: A participant leaves their game
    When I visit the game page for "Sprint 70"
    And I click "Quitter la partie"
    Then I should see "Sprint 70" marked as ended in "Mes parties"
```

- [ ] **Step 4: Write `features/step_definitions/join_request_steps.rb`**

Check `features/step_definitions/game_steps.rb` first for any step text this file would duplicate (e.g. "the Planning Poker game type exists", "a user exists with email", "I am logged in as", "I am already participating in a game named") — reuse those, write only the new ones:

```ruby
When("I visit the games list") do
  visit games_path
end

Given("{string} created a game named {string}") do |email, name|
  user = User.find_by!(email: email)
  game_type = GameType.find_by!(slug: "planning-poker")
  game = Game.create!(game_type: game_type, name: name)
  Participant.create!(game: game, user: user, creator: true)
end

When("I request to join {string}") do |name|
  game = Game.find_by!(name: name)
  within(".ds-card", text: name) { click_button "Demander à rejoindre" }
end

Given("{string} has requested to join {string}") do |email, name|
  user = User.find_by!(email: email)
  game = Game.find_by!(name: name)
  JoinRequest.create!(game: game, user: user)
end

When("I visit the game page for {string}") do |name|
  game = Game.find_by!(name: name)
  visit game_path(game)
end

When("I accept the join request from {string}") do |email|
  within(".ds-card", text: email) { click_button "Accepter" }
end

Then("{string} becomes a participant of {string}") do |email, name|
  user = User.find_by!(email: email)
  game = Game.find_by!(name: name)
  assert Participant.active.exists?(game: game, user: user)
end

When("I click {string}") do |label|
  click_button label
end

Then("I should see {string} marked as ended in \"Mes parties\"") do |name|
  visit games_path
  within("section", text: "Mes parties") do
    assert page.has_text?(name)
    assert page.has_text?("Terminée")
  end
end
```

- [ ] **Step 5: Run the new scenarios**

Run: `bundle exec cucumber features/game_listing.feature features/join_request.feature features/leaving_a_game.feature`
Expected: all scenarios pass. If any step text doesn't match the real rendered page (e.g. exact label wording), fix the step definition or feature wording to match the real app — do not change already-reviewed app code to fit a wrong assumption in the feature file.

- [ ] **Step 6: Run the entire Cucumber and RSpec suites**

Run: `bundle exec cucumber && bundle exec rspec`
Expected: all green — no regressions in any pre-existing `.feature` file or RSpec example.

- [ ] **Step 7: Commit**

```bash
git add features/game_listing.feature features/join_request.feature features/leaving_a_game.feature features/step_definitions/join_request_steps.rb
git commit -m "test: add Cucumber coverage for listing, join requests, and leaving"
```

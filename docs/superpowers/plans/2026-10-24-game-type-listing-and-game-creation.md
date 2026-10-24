# GameType Listing and Game Creation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single fixed Planning-Poker home page with a GameType listing at `/`, move the existing Planning Poker landing/dashboard content behind a GameType `show` page, and let a signed-in Member create a Game (name + optional description) that makes them its Creator and first Participant.

**Architecture:** Three new ActiveRecord models (`GameType`, `Game`, `Participant`) back a new `GameTypesController` (`index`/`show`, replacing `HomeController`) and a new `GamesController` (`new`/`create`). `GameType#show` renders the current `home#index` view content unchanged, scoped to Planning Poker. Game creation is a single form; on submit, the Game and the Creator's Participant row are written together, guarded by an application-level "one active Game per User" validation.

**Tech Stack:** Rails 8.1, SQLite, Devise, Slim views, RSpec (`spec/`) with FactoryBot, Cucumber + Capybara (`features/`), existing `ds-*` design-system CSS classes (no new CSS needed).

**Spec:** GitHub issue #4 (`gh issue view 4`) — see also `GLOSSARY.md` and `docs/adr/0002-creator-is-a-participant-flag.md` for the domain decisions this plan implements.

## Global Constraints

- `Game#name` is unique across the whole `games` table (Platform-wide, not per-GameType), and forever — a Game is never deleted (GLOSSARY.md's `Ended` state), so its name is never released for reuse — DB unique index + model validation.
- `GameType#name` and `GameType#slug` are each unique — DB unique index + model validation.
- `Game#description` is optional; a blank or whitespace-only value is normalized to `nil` before save.
- No `Game#creator_id` column: the Creator is the `Participant` row with `creator: true` (ADR 0002).
- The "one active Game per User" rule is an application-level validation on `Participant`, not a DB unique index on `participants.user_id` (so a future "leave a Game" feature doesn't need a migration to add history).
- Creating a Game never goes through JoinRequest — the Creator's `Participant` row is inserted directly, in the same action as the Game creation.
- `HomeController` and `app/views/home/` are deleted outright once their content is moved — no compatibility redirect.
- Routing: `root` → `game_types#index`; a GameType's page is `/game_types/:slug` → `game_types#show`.
- Unit and controller/request-level tests use RSpec (`spec/`) with FactoryBot factories, per the project's switch away from Minitest. Cucumber (`features/`) stays as-is for acceptance coverage.
- No code in this plan ever deletes a `Game` row (it never implements the leave/Ended transition) — so nothing here contradicts the permanent-uniqueness rule above; it is enforced purely by never deleting.
- Per CLAUDE.md: every task below that changes externally-observable behavior ships with passing Cucumber coverage, not just RSpec.

## Review Focus

- Submitting the Game creation form with a name that collides with an existing Game (case-sensitive exact match) must show a validation error and must not create a second row — the spec calls this out explicitly as the primary uniqueness risk.
- A signed-in Member who already has an active `Participant` row (from a previously created Game) must see the "Créer une partie" button disabled with the other Game's name shown, and a direct POST to create a second Game must still be rejected server-side (the UI disabling the button is not the enforcement).
- A signed-out visitor hitting `/game_types/:slug` directly (not via the listing) must see the same existing public hero content as before — the route must not require authentication.
- Submitting the Game creation form with only whitespace in the description field must store `nil`, not an empty or whitespace string (silent data-quality drift otherwise).
- A `GameType` with no seeded row (e.g. a fresh test database before seeds run) must not crash `game_types#index` — the listing must handle "seed not yet run" by asserting the seed exists as test setup, not by code defending against an empty list the spec never asked it to handle gracefully.

---

## Task 1: `GameType` model

**Files:**
- Create: `db/migrate/20261024000001_create_game_types.rb`
- Create: `app/models/game_type.rb`
- Create: `spec/factories/game_types.rb`
- Test: `spec/models/game_type_spec.rb`

**Interfaces:**
- Produces: `GameType` with `name:string`, `slug:string`, `description:text`, all required by later tasks for routing (`slug`) and the listing view (`name`, `description`). FactoryBot factory `:game_type` (`name: "Planning Poker"`, `slug: "planning-poker"`, `description: "desc"`), reused by every later spec needing a `GameType`.

- [ ] **Step 1: Write the migration**

```ruby
class CreateGameTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :game_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.timestamps
    end
    add_index :game_types, :name, unique: true
    add_index :game_types, :slug, unique: true
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `game_types` table created, `db/schema.rb` updated with both unique indexes.

- [ ] **Step 3: Write the factory**

```ruby
FactoryBot.define do
  factory :game_type do
    name { "Planning Poker" }
    slug { "planning-poker" }
    description { "Estimez vos tickets en équipe, en temps réel, par un vote collectif à l'aveugle." }
  end
end
```

- [ ] **Step 4: Write the failing tests**

```ruby
require "rails_helper"

RSpec.describe GameType, type: :model do
  it "requires a name" do
    game_type = build(:game_type, name: nil)
    expect(game_type).not_to be_valid
    expect(game_type.errors[:name]).to include("can't be blank")
  end

  it "requires a unique name" do
    create(:game_type)
    dup = build(:game_type, slug: "other")
    expect(dup).not_to be_valid
    expect(dup.errors[:name]).to include("has already been taken")
  end

  it "requires a unique slug" do
    create(:game_type)
    dup = build(:game_type, name: "Other")
    expect(dup).not_to be_valid
    expect(dup.errors[:slug]).to include("has already been taken")
  end
end
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/game_type_spec.rb`
Expected: FAIL — `uninitialized constant GameType`.

- [ ] **Step 6: Implement `GameType` in `app/models/game_type.rb`**

```ruby
class GameType < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true
  validates :description, presence: true
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/game_type_spec.rb`
Expected: PASS (3 examples, 0 failures).

- [ ] **Step 8: Commit**

```bash
git add db/migrate/20261024000001_create_game_types.rb db/schema.rb app/models/game_type.rb spec/factories/game_types.rb spec/models/game_type_spec.rb
git commit -m "feat: add GameType model"
```

---

## Task 2: `Game` model

**Files:**
- Create: `db/migrate/20261024000002_create_games.rb`
- Create: `app/models/game.rb`
- Create: `spec/factories/games.rb`
- Test: `spec/models/game_spec.rb`

**Interfaces:**
- Consumes: `GameType` (Task 1) via `belongs_to :game_type`, factory `:game_type`.
- Produces: `Game` with `name:string`, `description:text` (nullable), `state:string` (default `"lobby"`), `game_type_id`. FactoryBot factory `:game` (`game_type` association, sequence-based unique `name`). Later tasks (3, 5, 6) rely on `Game#description` being normalized to `nil` when blank, and on `state` defaulting to `"lobby"`.

- [ ] **Step 1: Write the migration**

```ruby
class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :game_type, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :state, null: false, default: "lobby"
      t.timestamps
    end
    add_index :games, :name, unique: true
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `games` table created, unique index on `name`, FK to `game_types`.

- [ ] **Step 3: Write the factory**

```ruby
FactoryBot.define do
  factory :game do
    game_type
    sequence(:name) { |n| "Sprint #{n}" }
  end
end
```

- [ ] **Step 4: Write the failing tests**

```ruby
require "rails_helper"

RSpec.describe Game, type: :model do
  it "requires a name" do
    game = build(:game, name: nil)
    expect(game).not_to be_valid
    expect(game.errors[:name]).to include("can't be blank")
  end

  it "requires a unique name across the whole platform" do
    create(:game, name: "Sprint 12")
    dup = build(:game, name: "Sprint 12")
    expect(dup).not_to be_valid
    expect(dup.errors[:name]).to include("has already been taken")
  end

  it "defaults state to lobby" do
    game = create(:game)
    expect(game.state).to eq("lobby")
  end

  it "normalizes a blank description to nil" do
    game = create(:game, description: "   ")
    expect(game.description).to be_nil
  end

  it "keeps a present description" do
    game = create(:game, description: "Weekly estimation")
    expect(game.description).to eq("Weekly estimation")
  end
end
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/game_spec.rb`
Expected: FAIL — `uninitialized constant Game`.

- [ ] **Step 6: Implement `Game` in `app/models/game.rb`**

Use `normalizes :description, with: -> (value) { value.blank? ? nil : value }` (Rails 7.1+ `normalizes` API) for the blank-to-nil rule.

```ruby
class Game < ApplicationRecord
  belongs_to :game_type

  normalizes :description, with: -> (value) { value.blank? ? nil : value }

  validates :name, presence: true, uniqueness: true
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/game_spec.rb`
Expected: PASS (5 examples, 0 failures).

- [ ] **Step 8: Commit**

```bash
git add db/migrate/20261024000002_create_games.rb db/schema.rb app/models/game.rb spec/factories/games.rb spec/models/game_spec.rb
git commit -m "feat: add Game model"
```

---

## Task 3: `Participant` model, one-active-Game rule, and `User#current_game`

**Files:**
- Create: `db/migrate/20261024000003_create_participants.rb`
- Create: `app/models/participant.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/game.rb`
- Create: `spec/factories/participants.rb`
- Create: `spec/factories/users.rb` (if not already present from Task 0 setup — see Step 0)
- Test: `spec/models/participant_spec.rb`
- Test: `spec/models/user_spec.rb`

**Interfaces:**
- Consumes: `Game` (Task 2), `User` (existing), factories `:game`, `:user`.
- Produces: `Participant` with `game_id`, `user_id`, `creator:boolean` (default `false`); `Game#participants` (`has_many`); `User#participants` (`has_many`); `User#current_game` returning the `Game` the user currently participates in, or `nil`. FactoryBot factory `:participant` (`game`, `user` associations). Task 6 (Games controller) calls `Participant.create!(game:, user:, creator: true)` and `user.current_game`.

- [ ] **Step 0: Create the `User` factory if missing**

Check whether `spec/factories/users.rb` already exists (it may not, since no RSpec specs predate this plan). If absent, create it:

```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "Password123" }
    password_confirmation { "Password123" }
  end
end
```

- [ ] **Step 1: Write the migration**

```ruby
class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :creator, null: false, default: false
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `participants` table created, FKs to `games` and `users`.

- [ ] **Step 3: Write the factory**

```ruby
FactoryBot.define do
  factory :participant do
    game
    user
  end
end
```

- [ ] **Step 4: Write the failing tests**

```ruby
# spec/models/participant_spec.rb
require "rails_helper"

RSpec.describe Participant, type: :model do
  it "requires a game" do
    participant = build(:participant, game: nil)
    expect(participant).not_to be_valid
  end

  it "requires a user" do
    participant = build(:participant, user: nil)
    expect(participant).not_to be_valid
  end

  it "rejects a second active participation for the same user" do
    user = create(:user)
    create(:participant, user: user)
    second = build(:participant, user: user)
    expect(second).not_to be_valid
    expect(second.errors[:user]).to include("is already participating in another game")
  end

  it "defaults creator to false" do
    participant = create(:participant)
    expect(participant.creator).to eq(false)
  end
end
```

```ruby
# spec/models/user_spec.rb
require "rails_helper"

RSpec.describe User, type: :model do
  describe "#current_game" do
    it "is nil with no participation" do
      user = create(:user)
      expect(user.current_game).to be_nil
    end

    it "returns the game the user participates in" do
      participant = create(:participant)
      expect(participant.user.current_game).to eq(participant.game)
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `bundle exec rspec spec/models/participant_spec.rb spec/models/user_spec.rb`
Expected: FAIL — `uninitialized constant Participant` / `NoMethodError: current_game`.

- [ ] **Step 6: Implement `Participant` in `app/models/participant.rb`**

```ruby
class Participant < ApplicationRecord
  belongs_to :game
  belongs_to :user

  validate :user_has_no_other_active_game, on: :create

  private

  def user_has_no_other_active_game
    return if user.nil?
    return unless user.participants.where.not(game_id: game_id).exists?

    errors.add(:user, "is already participating in another game")
  end
end
```

- [ ] **Step 7: Add `has_many :participants` and `current_game` to `app/models/user.rb`**

Insert after the `enum :role` line:

```ruby
has_many :participants

def current_game
  participants.first&.game
end
```

- [ ] **Step 8: Add `has_many :participants` to `app/models/game.rb`**

```ruby
has_many :participants
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `bundle exec rspec spec/models/participant_spec.rb spec/models/user_spec.rb`
Expected: PASS (6 examples, 0 failures).

- [ ] **Step 10: Commit**

```bash
git add db/migrate/20261024000003_create_participants.rb db/schema.rb app/models/participant.rb app/models/user.rb app/models/game.rb spec/factories/participants.rb spec/factories/users.rb spec/models/participant_spec.rb spec/models/user_spec.rb
git commit -m "feat: add Participant model and User#current_game"
```

---

## Task 4: Seed Planning Poker `GameType`

**Files:**
- Modify: `db/seeds.rb`

**Interfaces:**
- Consumes: `GameType` (Task 1).
- Produces: a `GameType` row with `slug: "planning-poker"`, consumed by Task 5's route and Task 6/7's controllers/tests as the fixed lookup slug.

- [ ] **Step 1: Add the seed**

```ruby
GameType.find_or_create_by!(slug: "planning-poker") do |game_type|
  game_type.name = "Planning Poker"
  game_type.description = "Estimez vos tickets en équipe, en temps réel, par un vote collectif à l'aveugle."
end
```

- [ ] **Step 2: Run the seed and verify**

Run: `bin/rails db:seed && bin/rails runner 'puts GameType.find_by(slug: "planning-poker").name'`
Expected: prints `Planning Poker`.

- [ ] **Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: seed the Planning Poker GameType"
```

---

## Task 5: Routing — `GameTypesController` replaces `HomeController`

**Files:**
- Create: `app/controllers/game_types_controller.rb`
- Delete: `app/controllers/home_controller.rb`
- Delete: `app/views/home/index.html.slim`
- Move: `app/views/home/index.html.slim` content → `app/views/game_types/show.html.slim` (see Step 3)
- Create: `app/views/game_types/index.html.slim`
- Modify: `config/routes.rb`
- Test: `spec/requests/game_types_spec.rb`

**Interfaces:**
- Consumes: `GameType` (Task 1), seeded row (Task 4), factory `:game_type`.
- Produces: `root_path` → `game_types#index`; `game_type_path(slug)` → `game_types#show`. Task 6 and 7's views link to `game_type_path("planning-poker")` and read `@game_type` in `show`.

- [ ] **Step 1: Update `config/routes.rb`**

Replace `root "home#index"` with:

```ruby
root "game_types#index"
resources :game_types, only: [ :index, :show ], param: :slug
```

- [ ] **Step 2: Create `app/controllers/game_types_controller.rb`**

```ruby
class GameTypesController < ApplicationController
  def index
    @game_types = GameType.all
  end

  def show
    @game_type = GameType.find_by!(slug: params[:slug])
  end
end
```

- [ ] **Step 3: Move the view**

Copy the full current contents of `app/views/home/index.html.slim` verbatim into a new `app/views/game_types/show.html.slim` (no content changes — the spec requires this view to render unchanged). Then delete `app/views/home/index.html.slim` and `app/controllers/home_controller.rb`.

- [ ] **Step 4: Create `app/views/game_types/index.html.slim`**

List `@game_types`, each linking to its `show` page. Use existing `ds-card`/`ds-heading-md`/`ds-body-sm`/`ds-btn` classes, matching the visual language already used in the moved view's step cards:

```slim
.ds-root
  header.nav
    .nav-brand
      .nav-logo PP
      span.ds-heading-md Planning Poker Platform
  main
    h1.ds-heading-xl Choisissez un jeu
    - @game_types.each do |game_type|
      .ds-card
        h2.ds-heading-md = game_type.name
        p.ds-body-sm = game_type.description
        = link_to "Voir", game_type_path(game_type.slug), class: "ds-btn ds-btn-primary"
```

- [ ] **Step 5: Write the failing request spec**

```ruby
require "rails_helper"

RSpec.describe "GameTypes", type: :request do
  let!(:game_type) { create(:game_type) }

  describe "GET /" do
    it "lists game types" do
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Planning Poker")
    end
  end

  describe "GET /game_types/:slug" do
    it "renders the game type's page" do
      get game_type_path(game_type.slug)
      expect(response).to have_http_status(:success)
    end

    it "404s for an unknown slug" do
      get game_type_path("does-not-exist")
      expect(response).to have_http_status(:not_found)
    end
  end
end
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/game_types_spec.rb`
Expected: FAIL — `uninitialized constant GameTypesController` (before Step 2) or routing error.

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/game_types_spec.rb`
Expected: PASS (3 examples, 0 failures).

- [ ] **Step 8: Update the Cucumber step that visits the home page**

In `features/step_definitions/registration_steps.rb`, the step `Given("I am on the home page") { visit root_path }` is unaffected (still `root_path`) — no change needed. Run the full suite to confirm:

Run: `bundle exec cucumber`
Expected: all existing scenarios still pass (they visit `root_path`, sign up/log in from there, which is now the GameType listing — but those scenarios only assert on the signed-up/logged-in email appearing after navigating through `S'inscrire`/`Se connecter`, not on home-page copy, so check output for any failures tied to page content before proceeding).

- [ ] **Step 9: If Step 8 reveals broken scenarios, fix the affected step definitions**

The registration/login flows click `S'inscrire` / `Se connecter` links that live in the nav of the *old* home page, now on the GameType `index` page instead of `show`. Since Task 5's `index.html.slim` (Step 4) does not include those links, add a minimal nav to `index.html.slim` mirroring the signed-out nav from the moved view (same `Se connecter` / `S'inscrire` links), so existing Cucumber scenarios keep passing without rewriting their steps.

- [ ] **Step 10: Run the full RSpec and Cucumber suites**

Run: `bundle exec rspec && bundle exec cucumber`
Expected: all green.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: replace HomeController with GameTypesController"
```

---

## Task 6: Game creation — `GamesController#new`/`#create`, form, and disabled-button UI

**Files:**
- Create: `app/controllers/games_controller.rb`
- Create: `app/views/games/new.html.slim`
- Modify: `app/views/game_types/show.html.slim`
- Modify: `config/routes.rb`
- Test: `spec/requests/games_spec.rb`

**Interfaces:**
- Consumes: `GameType` (Task 1, via `params[:game_type_slug]`), `Game`/`Participant` (Tasks 2–3), `User#current_game` (Task 3), factories `:game_type`, `:game`, `:user`, `:participant`.
- Produces: `POST /game_types/:game_type_slug/games` → creates `Game` + Creator `Participant` in one request; `new_game_type_game_path(slug)` for the form link.

- [ ] **Step 1: Add the nested route in `config/routes.rb`**

```ruby
resources :game_types, only: [ :index, :show ], param: :slug do
  resources :games, only: [ :new, :create ]
end
```

- [ ] **Step 2: Write the failing request specs**

```ruby
require "rails_helper"

RSpec.describe "Games", type: :request do
  let!(:game_type) { create(:game_type) }
  let(:user) { create(:user) }

  before { sign_in user }

  it "creates a game and makes the user its creator participant" do
    post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 1", description: "Weekly" } }

    game = Game.find_by(name: "Sprint 1")
    expect(game).not_to be_nil
    expect(response).to redirect_to(game_type_path(game_type.slug))
    participant = game.participants.find_by(user: user)
    expect(participant.creator).to eq(true)
  end

  it "normalizes a blank description to nil" do
    post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 2", description: "   " } }
    expect(Game.find_by(name: "Sprint 2").description).to be_nil
  end

  it "rejects a duplicate game name" do
    create(:game, game_type: game_type, name: "Sprint 3")
    expect {
      post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 3" } }
    }.not_to change(Game, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "rejects creation when the user already has an active game" do
    existing = create(:game, game_type: game_type)
    create(:participant, game: existing, user: user, creator: true)

    expect {
      post game_type_games_path(game_type.slug), params: { game: { name: "Sprint 5" } }
    }.not_to change(Game, :count)
    expect(response).to have_http_status(:unprocessable_entity)
  end
end
```

Note: requires Devise's request-spec helper. Add `config.include Devise::Test::IntegrationHelpers, type: :request` to `spec/rails_helper.rb`'s `RSpec.configure` block.

- [ ] **Step 3: Run tests to verify they fail**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: FAIL — `uninitialized constant GamesController`.

- [ ] **Step 4: Implement `app/controllers/games_controller.rb`**

```ruby
class GamesController < ApplicationController
  before_action :authenticate_user!

  def new
    @game_type = GameType.find_by!(slug: params[:game_type_slug])
    @game = Game.new
  end

  def create
    @game_type = GameType.find_by!(slug: params[:game_type_slug])
    @game = Game.new(game_params.merge(game_type: @game_type))

    ActiveRecord::Base.transaction do
      @game.save!
      Participant.create!(game: @game, user: current_user, creator: true)
    end
    redirect_to game_type_path(@game_type.slug)
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  private

  def game_params
    params.require(:game).permit(:name, :description)
  end
end
```

- [ ] **Step 5: Create `app/views/games/new.html.slim`**

```slim
.ds-root
  h1.ds-heading-lg Créer une partie

  = form_for @game, url: game_type_games_path(@game_type.slug) do |f|
    .ds-field
      = f.label :name, "Nom de la partie", class: "ds-label"
      = f.text_field :name, class: "ds-input"
    .ds-field
      = f.label :description, "Description (optionnel)", class: "ds-label"
      = f.text_area :description, class: "ds-input"
    .ds-actions
      = f.submit "Créer", class: "ds-btn ds-btn-primary"
```

- [ ] **Step 6: Update `app/views/game_types/show.html.slim`'s "Créer une partie" buttons**

There are two such buttons in the moved view (one in the signed-in dashboard hero, one in the signed-in nav list). Replace both `a.ds-btn.ds-btn-primary href="#" Créer une partie` occurrences with the disabled-aware version:

```slim
- if current_user.current_game
  span.ds-btn.ds-btn-primary disabled="disabled" Créer une partie
  span.ds-hint Vous participez déjà à #{current_user.current_game.name}
- else
  = link_to "Créer une partie", new_game_type_game_path(@game_type.slug), class: "ds-btn ds-btn-primary"
```

(The signed-out branch has no such button targeting Game creation — its "Créer une partie" link leads to sign-up, per the existing view; leave it untouched.)

- [ ] **Step 7: Run tests to verify they pass**

Run: `bundle exec rspec spec/requests/games_spec.rb`
Expected: PASS (4 examples, 0 failures).

- [ ] **Step 8: Run the full RSpec suite**

Run: `bundle exec rspec`
Expected: all green.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add Game creation flow with one-active-game guard"
```

---

## Task 7: Cucumber coverage for GameType listing and Game creation

**Files:**
- Create: `features/game_type_listing.feature`
- Create: `features/game_creation.feature`
- Create: `features/step_definitions/game_steps.rb`

**Interfaces:**
- Consumes: everything from Tasks 1–6.
- Produces: no new interfaces; this task only adds acceptance coverage per CLAUDE.md's standing instruction.

- [ ] **Step 1: Write `features/game_type_listing.feature`**

```gherkin
Feature: GameType listing

  Background:
    Given the Planning Poker game type exists

  Scenario: A visitor sees the list of game types on the home page
    When I visit the home page
    Then I should see "Planning Poker"

  Scenario: A visitor opens the Planning Poker game type
    Given I am on the home page
    When I click on "Planning Poker"
    Then I should see "Estimez vos tickets en équipe"

  Scenario: A signed-in member sees the listing and their dashboard unchanged
    Given a user exists with email "dana@example.com"
    And I am logged in as "dana@example.com"
    When I visit the home page
    Then I should see "Planning Poker"
    When I click on "Planning Poker"
    Then I should see "Bon retour !"
```

- [ ] **Step 2: Write `features/game_creation.feature`**

```gherkin
Feature: Game creation

  Background:
    Given the Planning Poker game type exists
    And a user exists with email "alice@example.com"
    And I am logged in as "alice@example.com"

  Scenario: A member creates a game with a name only
    When I create a game named "Sprint 42"
    Then I should see "Sprint 42"

  Scenario: A member creates a game with a name and a description
    When I create a game named "Sprint 43" with description "Weekly estimation"
    Then I should see "Sprint 43"

  Scenario: A member cannot create a game with a name already taken
    Given a game named "Sprint 44" exists for the Planning Poker game type
    When I create a game named "Sprint 44"
    Then I should see "has already been taken"

  Scenario: A member already in a game cannot create another one
    Given I am already participating in a game named "Sprint 45"
    When I visit the Planning Poker game type page
    Then the "Créer une partie" button should be disabled
    And I should see "Vous participez déjà à Sprint 45"
```

- [ ] **Step 3: Write `features/step_definitions/game_steps.rb`**

```ruby
Given("the Planning Poker game type exists") do
  GameType.find_or_create_by!(slug: "planning-poker") do |gt|
    gt.name = "Planning Poker"
    gt.description = "Estimez vos tickets en équipe, en temps réel, par un vote collectif à l'aveugle."
  end
end

Given("I am logged in as {string}") do |email|
  visit new_user_session_path
  fill_in "user_email", with: email
  fill_in "user_password", with: "Password123"
  click_button "Se connecter"
end

When("I visit the home page") do
  visit root_path
end

When("I click on {string}") do |text|
  click_link text
end

When("I visit the Planning Poker game type page") do
  visit game_type_path("planning-poker")
end

Given("a game named {string} exists for the Planning Poker game type") do |name|
  game_type = GameType.find_by!(slug: "planning-poker")
  Game.create!(game_type: game_type, name: name)
end

Given("I am already participating in a game named {string}") do |name|
  game_type = GameType.find_by!(slug: "planning-poker")
  game = Game.create!(game_type: game_type, name: name)
  user = User.find_by!(email: "alice@example.com")
  Participant.create!(game: game, user: user, creator: true)
end

When("I create a game named {string}") do |name|
  visit new_game_type_game_path("planning-poker")
  fill_in "Nom de la partie", with: name
  click_button "Créer"
end

When("I create a game named {string} with description {string}") do |name, description|
  visit new_game_type_game_path("planning-poker")
  fill_in "Nom de la partie", with: name
  fill_in "Description (optionnel)", with: description
  click_button "Créer"
end

Then("the {string} button should be disabled") do |label|
  assert page.has_css?("span.ds-btn[disabled]", text: label)
end
```

- [ ] **Step 4: Run the new scenarios**

Run: `bundle exec cucumber features/game_type_listing.feature features/game_creation.feature`
Expected: all scenarios pass.

- [ ] **Step 5: Run the entire Cucumber and RSpec suites**

Run: `bundle exec cucumber && bundle exec rspec`
Expected: all green — no regressions in `registration.feature`, `login.feature`, `health_check.feature`.

- [ ] **Step 6: Commit**

```bash
git add features/game_type_listing.feature features/game_creation.feature features/step_definitions/game_steps.rb
git commit -m "test: add Cucumber coverage for GameType listing and Game creation"
```

---

## Task 8: Remove `home` leftovers (cleanup)

**Files:**
- Verify removal: `app/controllers/home_controller.rb`, `app/views/home/`

- [ ] **Step 1: Confirm no remaining references to `HomeController` or `home#index`**

Run: `grep -rn "HomeController\|home#index\|home_path" app config spec features`
Expected: no output (all removed in Task 5).

- [ ] **Step 2: Final full-suite run**

Run: `bundle exec rspec && bundle exec cucumber`
Expected: all green.

- [ ] **Step 3: Commit (only if Step 1 found and removed stray references)**

```bash
git add -A
git commit -m "chore: remove remaining HomeController references"
```

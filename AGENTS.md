# AGENTS.md

## Project Role

You are working on a game design and simulation toolkit for:

1. TCG / CCG card balance.
2. Item and currency price-gradient balancing.
3. AI opponent difficulty tuning for multiplayer digital board games.

The goal is not to build a full commercial game immediately.
The goal is to build a clean, testable, simulation-first prototype that can help designers evaluate balance changes quickly.

Prioritize clarity, reproducibility, and testability over visual polish.

---

## Core Product Goal

Build a modular balance lab with three main systems:

### 1. Card Balance Simulator

A system for defining cards, decks, game rules, bots, and batch simulations.

It should support:

- Data-driven card definitions.
- Deterministic simulations using a seed.
- Legal move generation.
- Simple AI bots.
- Batch self-play.
- Win-rate and matchup reports.
- Per-card impact statistics.

The system should make it easy to answer questions such as:

- Is one archetype too strong?
- Does first player advantage exceed an acceptable threshold?
- Which cards are overperforming?
- Which cards are dead draws?
- Which decks create non-interactive games?
- How does a card change affect the whole metagame?

---

### 2. Item Economy and Price Gradient Tool

A system for calculating and testing item prices, shop prices, upgrade costs, and resource sinks.

It should support:

- Base item value calculation.
- Rarity multipliers.
- Progression-stage multipliers.
- Currency income assumptions.
- Resource faucet and sink modeling.
- Optional dynamic price simulation.
- CSV / JSON export for designer review.

The system should make it easy to answer questions such as:

- Is this item too cheap for its power?
- Does the player earn enough currency to buy meaningful upgrades?
- Are premium / rare / late-game items scaling too aggressively?
- Are there enough currency sinks?
- Is the economy inflated after repeated play?

---

### 3. Board Game / Multiplayer AI Difficulty Tuning

A system for implementing AI opponents with adjustable strength.

It should support:

- Random bot.
- Rule-based heuristic bot.
- Search-based bot.
- Optional MCTS / ISMCTS style bot for hidden-information games.
- Difficulty presets.
- AI evaluation through self-play.
- Elo-like or win-rate based comparison.

The system should make it easy to answer questions such as:

- Is Easy AI weak but still believable?
- Is Hard AI strong without cheating?
- How much does search depth affect win rate?
- Does the AI make human-like mistakes?
- Does the AI use hidden information unfairly?
- Can the AI be used both for player-facing gameplay and balance testing?

---

## Reference Projects To Study

Use these projects as conceptual references. Do not copy their code unless license compatibility is confirmed.

### TCG / CCG Balance and Simulation References

- deckgym-core
- gym-locm
- CodinGame Legends of Code and Magic
- reinforced-greediness
- TheCardGoat / tcg-engines
- RyuuPlay
- Forge
- XMage
- MageZero
- OpenDuelyst
- mtg_deck_simulator
- Niantic metagame-balance

Study them for:

- Card rule engines.
- Data-driven card definitions.
- Large-scale match simulation.
- Matchup matrix generation.
- Bot vs bot evaluation.
- Deck archetype comparison.
- Search + heuristic hybrid AI.
- Reinforcement learning environments.
- Metagame diversity metrics.

---

### Item Economy and Price Gradient References

- GEEvo-game-economies
- bazaarBot
- EconSim
- williammoran/economy
- Dynamic-Economy-For-Games
- Aurelium
- Game Developer economy balancing spreadsheet article
- GitHub game-economy topic projects

Study them for:

- Resource graph modeling.
- Price formulas.
- Production-chain pricing.
- Dynamic market simulation.
- Supply and demand behavior.
- Auction house systems.
- Item price history.
- Spreadsheet-friendly economy design.

---

### Board Game AI / Multiplayer AI References

- boardgame.io
- GAIGResearch TabletopGames / TAG
- Ludii
- Ludii AI Competition
- OpenSpiel
- RLCard
- Hanabi Learning Environment
- GBG
- thomasmarsh/monkey
- brianberns/Hearts

Study them for:

- Turn-based game state modeling.
- Legal action generation.
- Bot interfaces.
- Search algorithms.
- Hidden information handling.
- MCTS / ISMCTS.
- Reinforcement learning environments.
- Multi-agent evaluation.
- AI difficulty tuning.

---

## Design Principles

### Simulation First

Every balance feature should be testable through automated simulation.

Do not rely only on manual playtesting.
Manual playtesting is useful, but it should come after automated sanity checks.

---

### Deterministic Reproducibility

All simulations must support deterministic random seeds.

A failed or suspicious simulation should be reproducible by reusing:

- Rules version.
- Card data version.
- Deck list.
- Bot type.
- Random seed.
- Simulation config.

---

### Data-Driven Design

Cards, items, currencies, shops, and AI difficulty presets should be represented as data whenever reasonable.

Prefer JSON, YAML, TOML, or CSV-compatible structures for designer-facing values.

Avoid hardcoding balance numbers deeply inside logic.

---

### Separation of Concerns

Keep these layers separate:

1. Data definitions.
2. Rules engine.
3. Bot decision logic.
4. Simulation runner.
5. Metrics and reports.
6. CLI / UI.
7. Tests.

Do not mix card rules, bot logic, and report generation in the same file unless the prototype is extremely small.

---

### Minimal First, Extensible Later

Do not attempt to support every possible TCG or board game rule.

Start with a small but complete vertical slice:

- Health.
- Mana / energy.
- Hand.
- Deck.
- Board.
- Attack.
- Spell.
- Draw.
- End turn.
- Win / lose condition.
- Simple bots.
- Batch simulation.
- Report output.

Then extend.

---

## Suggested Repository Structure

Use this structure unless the existing repository already has a better one.

```txt
/game-balance-lab
  /data
    /cards
      starter_cards.json
    /decks
      aggro.json
      control.json
      midrange.json
    /economy
      items.json
      currencies.json
      shops.json
      progression.json
    /ai
      difficulty_presets.json

  /src
    /core
      rng.*
      types.*
      errors.*

    /tcg
      card.*
      deck.*
      game_state.*
      rules.*
      actions.*
      legal_moves.*
      resolver.*
      simulation.*
      metrics.*

    /tcg/bots
      random_bot.*
      heuristic_bot.*
      search_bot.*

    /economy
      item_value.*
      price_formula.*
      resource_graph.*
      income_model.*
      market_simulation.*
      economy_metrics.*

    /board_ai
      game_adapter.*
      bot_interface.*
      difficulty.*
      mcts.*
      ismcts.*
      evaluation.*

    /reports
      matchup_report.*
      card_impact_report.*
      economy_report.*
      ai_difficulty_report.*

    /cli
      simulate_tcg.*
      analyze_economy.*
      evaluate_ai.*

  /tests
    /tcg
    /economy
    /board_ai

  /docs
    balance_methodology.md
    economy_methodology.md
    ai_tuning_methodology.md
```

---

## TCG Balance Model

### Required Card Fields

Each card should support at least:

```ts
type Card = {
  id: string;
  name: string;
  cost: number;
  type: "unit" | "spell" | "equipment" | "resource";
  rarity?: "common" | "rare" | "epic" | "legendary";
  attack?: number;
  health?: number;
  tags?: string[];
  effects?: Effect[];
};
```

Use equivalent types if the project is not TypeScript.

---

### Required Deck Fields

```ts
type DeckList = {
  id: string;
  name: string;
  archetype: "aggro" | "midrange" | "control" | "combo" | "test";
  cards: Array<{
    cardId: string;
    count: number;
  }>;
};
```

---

### Required Game Metrics

The simulator should collect:

```ts
type MatchResult = {
  winner: 0 | 1;
  turns: number;
  seed: number;
  firstPlayer: 0 | 1;
  deckA: string;
  deckB: string;
  botA: string;
  botB: string;
  reason: "health_zero" | "deck_out" | "turn_limit" | "concede" | "error";
};

type CardStats = {
  cardId: string;
  drawnCount: number;
  playedCount: number;
  keptInOpeningHandCount: number;
  winWhenDrawn: number;
  winWhenPlayed: number;
  averageTurnPlayed: number;
  averageValueEstimate?: number;
};
```

---

### Required Balance Reports

Implement reports for:

1. Matchup matrix.
2. First-player advantage.
3. Average game length.
4. Win-rate by archetype.
5. Per-card drawn win rate.
6. Per-card played win rate.
7. Dead-card rate.
8. Overperforming card list.
9. Non-interactive game rate.
10. Turn-limit / stall rate.

---

### TCG Balance Heuristics

Flag potential balance problems when:

- A deck has more than 55 percent win rate across broad matchups.
- A deck has more than 60 percent win rate against most archetypes.
- First player advantage exceeds 53 percent.
- A single card has much higher win-when-drawn than the deck average.
- A single card is played in most winning games but rarely in losing games.
- Games often end before the opponent can meaningfully respond.
- Games often reach turn limit.
- A low-cost card generates too much value compared with its cost.

These thresholds are starting points, not absolute truths.
Make them configurable.

---

## Item Economy and Price Gradient Model

### Required Item Fields

```ts
type Item = {
  id: string;
  name: string;
  category: "weapon" | "armor" | "consumable" | "material" | "card_pack" | "upgrade" | "cosmetic";
  rarity: "common" | "rare" | "epic" | "legendary";
  progressionTier: number;
  baseStats?: Record<string, number>;
  tags?: string[];
  acquisition?: {
    source: "shop" | "drop" | "craft" | "quest" | "event";
    dropRate?: number;
    timeGateHours?: number;
  };
};
```

---

### Suggested Price Formula

Use a transparent formula:

```txt
base_value =
  attack_value
+ defense_value
+ utility_value
+ draw_value
+ control_value
+ durability_value
+ convenience_value

final_price =
  base_value
* rarity_multiplier
* progression_multiplier
* acquisition_difficulty_multiplier
* demand_multiplier
* sink_adjustment
```

All multipliers should be configurable.

---

### Suggested Rarity Multipliers

```json
{
  "common": 1.0,
  "rare": 1.8,
  "epic": 3.5,
  "legendary": 7.0
}
```

These are placeholders.
Expose them in data files.

---

### Suggested Progression Curve

Support multiple curve types:

```txt
linear:
  price = base * tier

quadratic:
  price = base * tier^2

soft_exponential:
  price = base * pow(1.35, tier)

capped_exponential:
  price = min(max_price, base * pow(rate, tier))
```

Use different curves for different item categories.

Recommended defaults:

- Consumables: linear.
- Basic equipment: linear or mild quadratic.
- Upgrades: quadratic.
- Rare build-defining items: soft exponential with cap.
- Cosmetics: independent from power economy.
- Card packs: tied to expected card value and target acquisition speed.

---

### Required Economy Metrics

The economy analyzer should calculate:

```ts
type EconomyMetrics = {
  averageCurrencyIncomePerRun: number;
  averageCurrencyIncomePerHour: number;
  itemAffordabilityInRuns: Record<string, number>;
  itemAffordabilityInHours: Record<string, number>;
  currencySinkTotal: number;
  currencyFaucetTotal: number;
  inflationRiskScore: number;
  progressionBlockers: string[];
};
```

---

### Economy Balance Heuristics

Flag potential economy problems when:

- A required early item takes too many runs to afford.
- A late-game item is cheaper than a mid-game item with similar power.
- A currency has faucets but no meaningful sinks.
- A currency has many sinks but no reliable faucet.
- Consumables are priced so high that players never use them.
- Upgrade costs scale faster than player income.
- Dynamic markets allow obvious arbitrage loops.
- Rare items are priced by rarity only, ignoring actual utility.

---

## Board Game AI Difficulty Model

### Required Bot Interface

All bots should implement the same interface:

```ts
interface Bot {
  id: string;
  name: string;
  chooseAction(state: GameState, legalActions: Action[], context: BotContext): Action;
}
```

Use equivalent structures if the project is not TypeScript.

---

### Required Bot Types

Implement at least:

1. `RandomBot`

   - Chooses random legal action.
   - Used as a baseline.

2. `HeuristicBot`

   - Scores legal actions with a transparent evaluation function.
   - Used for normal player-facing AI.

3. `SearchBot`

   - Searches one or more turns ahead.
   - Uses the same evaluation function.
   - Used for hard AI and balance testing.

4. Optional `MCTSBot`

   - Uses Monte Carlo rollouts.
   - Useful for games with many possible actions.

5. Optional `ISMCTSBot`

   - Uses information-set MCTS.
   - Useful for hidden-information games.

---

### Suggested AI Evaluation Function

For TCG-like games, use weighted features:

```txt
score =
  health_weight * health_difference
+ board_weight * board_power_difference
+ hand_weight * hand_size_difference
+ mana_weight * mana_efficiency
+ tempo_weight * tempo_score
+ lethal_weight * lethal_threat
+ survival_weight * survival_score
+ card_advantage_weight * card_advantage
```

Weights should be configurable by difficulty or AI personality.

---

### Difficulty Presets

Use difficulty presets instead of hardcoding behavior.

```json
{
  "easy": {
    "botType": "heuristic",
    "searchDepth": 0,
    "candidateActionLimit": 3,
    "mistakeRate": 0.25,
    "hiddenInfoAccess": false,
    "evaluationNoise": 0.35
  },
  "normal": {
    "botType": "heuristic",
    "searchDepth": 1,
    "candidateActionLimit": 8,
    "mistakeRate": 0.10,
    "hiddenInfoAccess": false,
    "evaluationNoise": 0.15
  },
  "hard": {
    "botType": "search",
    "searchDepth": 2,
    "candidateActionLimit": 16,
    "mistakeRate": 0.03,
    "hiddenInfoAccess": false,
    "evaluationNoise": 0.05
  },
  "expert": {
    "botType": "search",
    "searchDepth": 3,
    "candidateActionLimit": 32,
    "mistakeRate": 0.0,
    "hiddenInfoAccess": false,
    "evaluationNoise": 0.0
  }
}
```

Important rule:

AI should not cheat by reading hidden player information unless the mode is explicitly a developer-only debug mode.

---

### AI Tuning Principles

Use these knobs to tune AI strength:

1. Search depth.
2. Rollout count.
3. Candidate action limit.
4. Evaluation noise.
5. Mistake rate.
6. Personality weights.
7. Risk tolerance.
8. Information access.
9. Time budget.
10. Memory / opponent modeling.

Do not make weak AI look stupid.
Make weak AI less farsighted, less consistent, or more personality-driven.

---

## Player-Facing AI vs Balance-Testing AI

Separate these two roles:

### PlayerFacingBot

Used in actual gameplay.

It should:

- Feel believable.
- Have personality.
- Make occasional human-like mistakes.
- Avoid obvious cheating.
- Avoid taking too long.
- Prefer fun gameplay over perfect play.

### BalanceBot

Used for automated balance testing.

It should:

- Be stable.
- Be deterministic when seeded.
- Play reasonably strong.
- Avoid personality noise.
- Avoid intentional mistakes.
- Produce reproducible data.
- Be suitable for thousands of simulations.

Do not use the exact same bot configuration for both purposes.

---

## CLI Requirements

Add CLI commands or scripts for:

```bash
# Run TCG simulations
simulate-tcg --deck-a aggro --deck-b control --bot-a heuristic --bot-b heuristic --games 1000 --seed 42

# Generate matchup matrix
simulate-tcg-matrix --decks aggro,control,midrange --games 1000 --seed 42 --output reports/matchups.csv

# Analyze economy
analyze-economy --items data/economy/items.json --progression data/economy/progression.json --output reports/economy.json

# Evaluate AI difficulty
evaluate-ai --game tcg-demo --bots easy,normal,hard,expert --games 1000 --seed 42 --output reports/ai_difficulty.csv
```

Adapt command names to the project language and tooling.

---

## Testing Requirements

Add tests for:

### TCG

- Deck shuffling is deterministic with seed.
- Legal actions are valid.
- Illegal actions are rejected.
- Drawing from deck works.
- Playing a card pays cost.
- Attacks reduce health correctly.
- Game ends when health reaches zero.
- Simulations are reproducible with the same seed.
- Match result schema is stable.

### Economy

- Price formula is deterministic.
- Rarity multiplier is applied.
- Progression multiplier is applied.
- Required items are flagged if unaffordable.
- Currency sink and faucet totals are calculated.
- Exported report format is stable.

### AI

- RandomBot always returns a legal action.
- HeuristicBot always returns a legal action.
- SearchBot always returns a legal action.
- Easy AI is weaker than Hard AI across enough simulations.
- AI does not access hidden information unless debug mode allows it.
- Difficulty presets load correctly.

---

## Reporting Requirements

Reports should be machine-readable first and human-readable second.

Prefer JSON and CSV outputs.

Minimum report files:

```txt
/reports
  matchup_matrix.csv
  card_impact.csv
  first_player_advantage.json
  economy_summary.json
  item_price_table.csv
  ai_difficulty_eval.csv
```

Include enough metadata to reproduce results:

```json
{
  "rulesVersion": "0.1.0",
  "dataVersion": "0.1.0",
  "seed": 42,
  "games": 1000,
  "createdAt": "ISO_TIMESTAMP",
  "botConfigs": {},
  "deckIds": []
}
```

---

## Implementation Style

Prefer small pure functions.

Avoid global mutable state.

Avoid hidden randomness.
Always pass RNG or seed explicitly.

Use clear names:

- `GameState`
- `Action`
- `LegalMoveGenerator`
- `SimulationRunner`
- `MatchupMatrix`
- `CardImpactAnalyzer`
- `EconomyAnalyzer`
- `PriceFormula`
- `BotEvaluator`
- `DifficultyPreset`

Do not create complex abstractions before the basic vertical slice works.

---

## Definition of Done

A task is done only when:

1. The code runs.
2. Tests pass.
3. A sample simulation can be executed.
4. A report file is generated.
5. The output is deterministic when using the same seed.
6. The README or docs explain how to run it.
7. New assumptions are documented.

---

## When Unsure

When uncertain about a design decision:

1. Prefer the simpler implementation.
2. Add a TODO with the tradeoff.
3. Keep the data model extensible.
4. Write a test for the current behavior.
5. Do not silently introduce hidden rules.

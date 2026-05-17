# CRAP Score Baseline

Date: 2026-05-17

## Stack and Tooling

- Language/framework: Ruby on Rails 8.1.3.
- Test runner: Rails Minitest through `bin/rails test`.
- Coverage tooling before this pass: none found.
- CRAP/complexity tooling before this pass: none found.
- Lint/security tools already present: `bin/rubocop`, `bin/brakeman`, `bin/check-no-npm-surface`.
- Added measurement tooling: `tools/crap_score.rb`, using Ruby standard-library `Coverage` plus a conservative local cyclomatic-complexity estimate. No new gem dependency was added.

## Baseline Commands

```sh
PARALLEL_WORKERS=1 bin/rails test
ruby tools/crap_score.rb --markdown tmp/crap_score_baseline.md --json tmp/crap_score_baseline.json --limit 40
bin/rubocop --only Metrics --format simple
```

Rails parallel tests hit the local sandbox DRb socket, so the baseline and final verification used `PARALLEL_WORKERS=1`.

## Original Test Baseline

- `78 runs, 536 assertions, 0 failures, 0 errors, 0 skips`
- RuboCop metrics: `121 files inspected, no offenses detected`

## Original Worst Methods

| CRAP | Complexity | Coverage | Method | File |
| ---: | ---: | ---: | --- | --- |
| 30.0 | 5 | 0.0% | `status_for` | `app/services/purchasing/inventory_recommendation.rb:31` |
| 15.64 | 13 | 75.0% | `refresh_product!` | `app/services/purchasing/product_normalizer.rb:76` |
| 14.08 | 4 | 14.3% | `merge_guide_frequency!` | `app/models/inventory_item.rb:52` |
| 12.19 | 4 | 20.0% | `guide_type_for` | `app/services/purchasing/order_guide_importer.rb:64` |
| 12.0 | 3 | 0.0% | `create_count` | `app/controllers/inventory_controller.rb:33` |
| 12.0 | 3 | 0.0% | `import_current` | `app/controllers/order_guides_controller.rb:12` |
| 12.0 | 3 | 0.0% | `buy_quantity_for` | `app/services/purchasing/inventory_recommendation.rb:25` |
| 12.0 | 3 | 0.0% | `extract` | `app/services/purchasing/order_guide_text_extractor.rb:7` |
| 10.0 | 10 | 100.0% | `chart_insight` | `app/services/purchasing/price_intelligence.rb:179` |
| 8.0 | 8 | 100.0% | `reusable_for_guide_item?` | `app/services/purchasing/order_guide_linking.rb:153` |

## Original Worst Files

| Max CRAP | Avg CRAP | Uncovered methods | File |
| ---: | ---: | ---: | --- |
| 30.0 | 11.5 | 4 | `app/services/purchasing/inventory_recommendation.rb` |
| 15.64 | 4.6 | 0 | `app/services/purchasing/product_normalizer.rb` |
| 14.08 | 3.01 | 0 | `app/models/inventory_item.rb` |
| 12.19 | 3.18 | 0 | `app/services/purchasing/order_guide_importer.rb` |
| 12.0 | 12.0 | 1 | `app/services/purchasing/order_guide_text_extractor.rb` |
| 12.0 | 7.0 | 2 | `app/controllers/order_guides_controller.rb` |
| 12.0 | 3.67 | 6 | `app/controllers/inventory_controller.rb` |

## Suspected Causes

- `InventoryRecommendation` had important stock-status business rules with no direct tests.
- `ProductNormalizer#refresh_product!` mixed identity, category, SKU, package fields, notes, and review-state updates in one method.
- Several small but real edge paths had no coverage: order-guide filename inference, PDF extraction failures, inventory count submission, and private branding fallback.
- The highest fully-covered methods were still carrying avoidable branching in price intelligence and order-guide linking.

## Recommended Order of Attack

1. Add characterization tests for inventory recommendations and product normalization before refactoring.
2. Split `ProductNormalizer#refresh_product!` into named update steps.
3. Cover uncovered guide/import/count/branding/extractor edge paths.
4. Refactor fully-covered high-complexity methods in `PriceIntelligence` and `OrderGuideLinking`.
5. Keep remaining parser/matcher methods under watch; most are covered and domain-specific.

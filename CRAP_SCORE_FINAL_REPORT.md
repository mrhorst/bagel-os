# CRAP Score Final Report

Date: 2026-05-17

## Before and After

| Metric | Before | After |
| --- | ---: | ---: |
| Test runs | 78 | 99 |
| Assertions | 536 | 607 |
| Failures/errors/skips | 0/0/0 | 0/0/0 |
| Highest method CRAP | 30.0 | 7.12 |
| Highest file max CRAP | 30.0 | 7.12 |
| Worst uncovered business path | `InventoryRecommendation#status_for` | covered |

## Final Worst Methods

| CRAP | Complexity | Coverage | Method | File |
| ---: | ---: | ---: | --- | --- |
| 7.12 | 7 | 86.7% | `match` | `app/services/purchasing/product_name_matcher.rb:53` |
| 7.0 | 7 | 100.0% | `reusable_for_guide_item?` | `app/services/purchasing/order_guide_linking.rb:153` |
| 7.0 | 7 | 100.0% | `skip_line?` | `app/services/purchasing/order_guide_text_parser.rb:64` |
| 7.0 | 7 | 100.0% | `standardizable?` | `app/services/purchasing/price_calculator.rb:65` |
| 7.0 | 7 | 100.0% | `window_change` | `app/services/purchasing/price_intelligence.rb:345` |
| 7.0 | 7 | 100.0% | `review_intents` | `app/services/purchasing/receipt_line_normalizer.rb:70` |

## Files Changed

- `tools/crap_score.rb`
- `test/test_helper.rb`
- `app/services/purchasing/product_normalizer.rb`
- `app/services/purchasing/price_intelligence.rb`
- `app/services/purchasing/order_guide_linking.rb`
- `test/services/inventory_recommendation_test.rb`
- `test/services/product_normalizer_test.rb`
- `test/services/order_guide_text_extractor_test.rb`
- `test/services/order_guide_importer_test.rb`
- `test/models/inventory_item_test.rb`
- `test/models/app_branding_test.rb`
- `test/integration/inventory_counts_test.rb`
- `test/integration/order_guides_import_current_test.rb`
- `CRAP_SCORE_BASELINE.md`
- `CRAP_SCORE_IMPROVEMENT_PLAN.md`
- `CRAP_SCORE_FINAL_REPORT.md`

## Tests Added

- Inventory recommendation statuses: not counted, buy now, near reorder, inactive item exclusion.
- Product normalization: family shorthand grouping, fallback SKU/package preservation, possible alias review creation.
- Inventory count submissions: successful manual count and empty submission rejection.
- Order-guide import: daily/weekly filename inference and current import error paths.
- PDF extraction: success, command failure, missing `pdftotext`.
- App branding: valid private override and invalid private config fallback.
- Inventory item guide frequency merge states.

## Refactors

- Split `ProductNormalizer#refresh_product!` into focused helpers for identity, category, SKU, package fields, and notes.
- Split `PriceIntelligence#chart_insight` into presentation-value helper methods.
- Split `PriceIntelligence#filtered_products` into focused filter methods.
- Simplified `OrderGuideLinking#reusable_for_guide_item?` into named boolean decisions.

## Verification

```sh
PARALLEL_WORKERS=1 bin/rails test
# 99 runs, 607 assertions, 0 failures, 0 errors, 0 skips

ruby tools/crap_score.rb --markdown tmp/crap_score_final.md --json tmp/crap_score_final.json --limit 60
# Highest method CRAP: 7.12
```

Additional project checks completed after report creation:

```sh
bin/check-no-npm-surface
# No npm/yarn/pnpm/bun package surface detected.

bin/rubocop
# 129 files inspected, no offenses detected

bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
# 0 errors, 0 security warnings
```

## Remaining High-Risk Areas

- `ProductNameMatcher#match` is still the top method at `7.12`; it is business-specific matching logic and should be refactored only with more characterization cases.
- `ReportsController` and `NormalizationReviewsController` still show uncovered helper/action methods, but their CRAP scores are low. They are good next coverage targets.
- The CRAP tool is repo-local and trend-oriented. If this becomes a CI gate, choose and document a threshold, likely `--max-crap 8` after adding a small fail mode to the script.

## Recommended Next Steps

1. Add a CI step for `ruby tools/crap_score.rb` once the desired threshold behavior is added.
2. Add controller coverage for reports and normalization review actions.
3. Add more matcher characterization examples before splitting `ProductNameMatcher#match`.

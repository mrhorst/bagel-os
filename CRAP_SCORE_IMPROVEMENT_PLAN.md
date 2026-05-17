# CRAP Score Improvement Plan

## Priority

1. `Purchasing::InventoryRecommendation`
   - Add direct tests for uncounted, buy-now, near-reorder, and inactive-item behavior.
   - Expected improvement: remove the original max CRAP `30.0` uncovered business rule.

2. `Purchasing::ProductNormalizer`
   - Add characterization tests for family shorthand grouping, fallback product creation, and possible-alias review creation.
   - Refactor product refresh into smaller methods for canonical name, category, SKU, package fields, and notes.
   - Expected improvement: lower `refresh_product!` from a complex mixed-responsibility method to small named steps.

3. Import and inventory edge paths
   - Cover inventory count creation and empty submissions.
   - Cover order-guide current import empty/error states.
   - Cover order-guide type inference.
   - Cover PDF extraction success/failure/setup errors.
   - Cover private branding config fallback.

4. Fully-covered complexity cleanup
   - Split `PriceIntelligence#chart_insight` into named presentation-value helpers.
   - Simplify `OrderGuideLinking#reusable_for_guide_item?`.
   - Split product filtering in `PriceIntelligence` into focused filter methods.

## Risks

- Product normalization is business-critical because it decides whether supplier receipt lines become shared products or review items. Tests were added before refactoring to preserve behavior.
- Order-guide import tests create temporary files under `data/order_guides/current`; teardown removes the directory.
- The CRAP tool uses a conservative local complexity estimate. It is useful for tracking trends inside this repo, not as a universal replacement for a commercial/static-analysis product.

## Commands

```sh
PARALLEL_WORKERS=1 bin/rails test
ruby tools/crap_score.rb --markdown tmp/crap_score_final.md --json tmp/crap_score_final.json --limit 60
bin/check-no-npm-surface
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

## Expected Improvements

- Highest method CRAP should drop from `30.0` to under `8`.
- Previously uncovered restaurant workflow paths should have meaningful tests.
- Product-normalizer complexity should move from one broad update method into smaller, named methods.
- Remaining high scores should be mostly fully-covered parser/matcher logic instead of untested business paths.

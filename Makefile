.PHONY: deps-stable deps-low cs phpstan tests unit-tests integration-tests inspector-tests coverage ci ci-stable ci-lowest conformance-tests conformance-server conformance-client docs docs-guides docs-api docs-serve

# The documentation toolchain is Python (Zensical, see requirements-docs.txt),
# run through uv so no virtualenv has to be managed by hand:
# https://docs.astral.sh/uv/getting-started/installation/
DOCS_RUN = uv run --no-project --with-requirements requirements-docs.txt --

deps-stable:
	composer update --prefer-stable

deps-low:
	composer update --prefer-lowest

cs:
	vendor/bin/php-cs-fixer fix --diff --verbose

phpstan:
	vendor/bin/phpstan --memory-limit=-1

tests:
	vendor/bin/phpunit

unit-tests:
	vendor/bin/phpunit --testsuite=unit

integration-tests:
	vendor/bin/phpunit --testsuite=integration

inspector-tests:
	vendor/bin/phpunit --testsuite=inspector

conformance-tests: conformance-server conformance-client

conformance-server:
	docker compose -f tests/Conformance/Fixtures/docker-compose.yml up -d
	@echo "Waiting for server to start..."
	@sleep 5
	rm -rf tests/Conformance/results
	cd tests/Conformance && npx @modelcontextprotocol/conformance server --url http://localhost:8000/ --output-dir results || true
	php tests/Conformance/score.php server
	docker compose -f tests/Conformance/Fixtures/docker-compose.yml down

conformance-client:
	rm -rf tests/Conformance/results
	cd tests/Conformance && npx @modelcontextprotocol/conformance client --command "php $(CURDIR)/tests/Conformance/client.php" --suite all --expected-failures conformance-baseline.yml --output-dir results || true
	php tests/Conformance/score.php client

coverage:
	XDEBUG_MODE=coverage vendor/bin/phpunit --testsuite=unit --coverage-html=coverage

ci: ci-stable

ci-stable: deps-stable cs phpstan tests

ci-lowest: deps-low cs phpstan tests

# The published site is the guides (Zensical) with the phpDocumentor API
# reference mounted at /api/. `zensical build` wipes site/, so it runs first.
docs: docs-guides docs-api
	rm -rf site/api
	cp -a .phpdoc/build/api site/api

docs-guides:
	$(DOCS_RUN) zensical build --strict

docs-api:
	vendor/bin/phpdoc --no-interaction
	@grep -q 'No errors have been found' .phpdoc/build/api/reports/errors.html || \
		(echo "Documentation errors found. See .phpdoc/build/api/reports/errors.html" && exit 1)

docs-serve:
	$(DOCS_RUN) zensical serve

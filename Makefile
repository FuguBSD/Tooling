# The Perl sources of this repository: the canonical synced scripts,
# the sync script, and the tests. Perl::Critic and Perl::Tidy select
# files the same way, so lint and tidy cover the same set.
PERLSRC			= find org perl scripts -type f \( -name '*.pm' -o \
			  -name '*.t' -o \
			  -exec sh -c 'head -1 "$$1" | grep -q "^\#!.*perl"' \
			  _ {} \; \) -print

DEPS			= org/sync/scripts/deps
PERLTIDY		= perl -MPerl::Tidy -e 'Perl::Tidy::perltidy()'
PRETTIER		= npx prettier@3.9.6

all: deps-test check

# prettier stays out of check: it runs through npx, and no deps/
# manifest provides node. CI runs it in its own job.
check: lint test tidy spec-check ste-lint

deps:
	$(DEPS) runtime

deps-develop: deps deps-test
	$(DEPS) develop

deps-test: deps
	$(DEPS) test

lint:
	@$(PERLSRC) | xargs perl -MPerl::Critic::Command -e 'Perl::Critic::Command::run()' -- --severity 4 --verbose 8

prettier:
	@$(PRETTIER) --check --no-error-on-unmatched-pattern '**/*.md' '**/*.json' '**/*.yml' || { echo "Run 'make prettier-fix' to fix formatting"; exit 1; }

prettier-fix:
	$(PRETTIER) --write --no-error-on-unmatched-pattern '**/*.md' '**/*.json' '**/*.yml'

# The canonical scripts run in place: sync refuses to run inside
# this repository, so no root copy of the scripts exists.
spec-check:
	@org/sync/scripts/spec-check --root .

ste-lint:
	@org/sync/scripts/ste-lint --root .

test:
	prove -l -v perl/t/*.t

tidy:
	@$(PERLSRC) | while read f; do \
		$(PERLTIDY) -- --standard-output "$$f" | diff -q "$$f" - >/dev/null 2>&1 || echo "$$f"; \
	done | grep . && echo "Run 'make tidy-fix' to fix formatting" && exit 1 || echo "All files formatted correctly"

tidy-fix:
	@$(PERLSRC) | while read f; do \
		$(PERLTIDY) -- -b -bext='/' "$$f"; \
	done

.PHONY: all check deps deps-develop deps-test lint prettier prettier-fix spec-check ste-lint test tidy tidy-fix

# mk/python.mk: canonical copy, owned by FuguBSD/Tooling.
# The python fragment: the setup target, the lockfile gate, and the
# Ruff lint and format pair. The fragment uses the portable make
# subset, so every dispatcher includes it without change.
#
# Every uv run passes --locked: a bare uv run rewrites a stale
# uv.lock, so a read target would write (MK-VERBS-1), and the repair
# would blind the lock-py gate. With --locked a stale lockfile fails
# the target instead. Only setup writes the lockfile.
#
# format-py-fix writes only what format-py reports (MK-VERBS-1). Run
# `uv run --locked ruff check --fix .` by hand for a lint autofix.

UV			?= uv

CHECK_TARGETS		+= lock-py
LINT_TARGETS		+= lint-py
FORMAT_TARGETS		+= format-py
FORMAT_FIX_TARGETS	+= format-py-fix

# Install the development tools into .venv.
setup:
	$(UV) sync

lock-py:
	$(UV) lock --check

lint-py:
	$(UV) run --locked ruff check .

format-py:
	$(UV) run --locked ruff format --check .

format-py-fix:
	$(UV) run --locked ruff format .

.PHONY: setup lock-py lint-py format-py format-py-fix

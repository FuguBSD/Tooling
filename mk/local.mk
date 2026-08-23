# mk/local.mk: the consumer hook of this repository (MK-LOCAL).
# sync never touches this file. The canonical scripts run in place,
# because sync refuses to run inside this repository, so the
# variables point into the canon trees.

SPEC_CHECK	= org/sync/scripts/spec-check --root .
STE_LINT	= org/sync/scripts/ste-lint --root .
DEPS		= org/sync/scripts/deps
PERL_SRC_DIRS	= org perl scripts
TEST_GLOBS	= perl/t/*.t

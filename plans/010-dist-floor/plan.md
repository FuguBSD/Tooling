# 010 — The perl floor of a distribution comes from `.toolingrc`

## Status

Proposed. It can land now, and it depends on no other plan. FuguBench waits on
it: its floor is v5.34, and the dist build of today stamps `5.036` into every
distribution.

Extends: SYNC-IDENTITY. The implementation adds one rule for the `dist.perl`
key, and it lands the rule with the code.

## Purpose

`scripts/dist` writes `MIN_PERL_VERSION => '5.036'` into the generated
`Makefile.PL`, and `perl => '5.036'` into the runtime prerequisites of
`META.json`. Both values sit in the script text. The perl pack rule sheet names
the floor of the repository as the pragma of every file. FuguBench takes v5.34,
so the macOS system perl runs it. A tarball of FuguBench would then refuse the
perl that its own code supports. This plan moves the floor into the identity
file of the consumer, with the value of today as the default.

## Scope

In scope:

- The `dist.perl` key of `.toolingrc`, read by `scripts/dist`.
- The two stamps in the generated files.
- The floor sentence of the perl pack rule sheet `lib/CLAUDE.md`.
- The fixtures and the guards of `perl/t/dist.t`.

Out of scope:

- The pragma of `scripts/dist` itself. The script runs where `make dist` runs:
  on a developer host, or in CI. It does not ship in the tarball, so its pragma
  binds no installing perl.
- The floor of any consumer. Each consumer sets its own key, or keeps the
  default.

## Constraints that shape the design

**Identity lives in `.toolingrc`.** SYNC-IDENTITY-2 and D-02 put every fact of a
consumer there. The floor is such a fact, so the key is `dist.perl`, in the
`dist.` prefix that the script reads already.

**The default is the value of today.** A consumer without the key gets `5.036`,
so the four Perl distributions of the organization change no byte of their
generated files. The floor of a consumer changes in a change of that consumer.

**One shape for the value.** The value takes the form that `MIN_PERL_VERSION`
and the META prerequisites share: `5.034`, `5.036`, or `5.038`. The script must
refuse another shape with a message that names the key, as it refuses an unknown
key. Both readers parse the value through version.pm. A `5.34` means perl 5.340
in both, so no perl satisfies it. A `v5.34` means 5.034 in both, but one shape
keeps the check simple, so the rule refuses it.

**One fact, one place.** The rule sheet of the perl pack tells a writer that the
README names the floor. After this plan `.toolingrc` names the floor when it
holds the key, and the default `5.036` of the script applies otherwise. The rule
sheet sentence points at the key, so a writer reads the floor where the build
reads it.

## The interface contract

`.toolingrc` gains an optional single-value key `dist.perl`, with the default
`5.036`. `scripts/dist` reads it with the other `dist.` keys, and holds it to
the shape `5.0NN`. It stamps the value into `MIN_PERL_VERSION` and into the
`perl` prerequisite of `META.json`.

The header comment of the script lists the key in its table of `dist.` keys.

The rule sheet sentence "The README names that floor" changes. It becomes "The
`dist.perl` key of `.toolingrc` names that floor, and the default is `5.036`".

The new rule reads as follows. A plan names no rule number, because a number
exists after the rule lands.

- The rule of SYNC-IDENTITY: "A Perl consumer can name its perl floor under
  `dist.perl` in `.toolingrc`, in the form `5.0NN`. The dist build must stamp
  that floor into the generated `Makefile.PL` and `META.json`. The default is
  `5.036`."

## Files

| File                      | Change                                            |
| ------------------------- | ------------------------------------------------- |
| `perl/sync/scripts/dist`  | The key, the shape check, the two stamps          |
| `perl/sync/lib/CLAUDE.md` | The floor sentence                                |
| `perl/t/dist.t`           | A fixture with `dist.perl 5.034`, and a bad shape |
| `spec/sync.md`            | One rule in SYNC-IDENTITY                         |
| `spec/STATUS.md`          | The SYNC-IDENTITY note names `dist.t`             |

## Tests

`perl/t/dist.t` builds a fixture distribution from a `.toolingrc` and reads the
staged tree. It gains:

- A fixture with `dist.perl 5.034` stages a `Makefile.PL` with
  `MIN_PERL_VERSION => '5.034'`, and its `META.json` accepts `perl` at `5.034`
  and refuses it at `5.032`.
- The fixture of today, without the key, keeps `5.036` in both files.
- A `.toolingrc` with `dist.perl 5.34` fails the build, and the message names
  `dist.perl`.
- A duplicate `dist.perl` line fails the build, as a duplicate single key does.

## Acceptance

- `make check` passes.
- SYNC-IDENTITY stays `done`, and its note names `dist.t`.
- The change deletes this plan.

## Open questions

None.

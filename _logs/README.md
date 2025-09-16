Ephemeral logs directory

- Purpose: transient outputs (compose config, smoke results, temp diagnostics).
- Retention: purge automatically during cleanup; do not commit.
- Developers: treat contents as disposable; copy anything important elsewhere.


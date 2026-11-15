# Managed-workspace Git cache recovery

The approved source commit is09aeb19; publication mergebf785ec also preserves
remote mainea5369c, including the prior pyro revert and signature review kit.
No force push was used. Local worktree/index were clean after integration.

Disk exhaustion interrupted the first full4 export; that incomplete file was
removed and a complete retry passed exact315+2 animation parity. The evicted
1.7GB promisor pack24411df… contained5535 remote-backed blobs only, no commits
or trees. Local source files/native assets were preserved. Required baseline
and39 symlink blobs were restored from SHA-verified local copies.

The partial clone lacks3856 unchanged historical/current blob cache entries.
Their index hashes were verified equal to the previous committed tree before
using write-tree --missing-ok/commit-tree to publish the validated index.
There were no configured pre-commit hooks. New source/evidence objects are local.
Do not refetch the entire historical asset cache merely to prepare a commit.

41 newly merged reference-only files under gauntlet/refs/ff_review/sig_loops
remain in the committed tree and on GitHub, with skip-worktree set locally.
They were not materialized in this space-limited checkout. This does not remove
them from the release/repository. Retrieve relevant references by exact path
from GitHub when that future task needs them; absence locally is not evidence
that the reference catalogue was deleted. The three merged pyro source files
were retrieved separately and verified against their exact Git blob hashes.

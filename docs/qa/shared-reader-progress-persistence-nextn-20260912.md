# NextN optional shared-reader progress persistence — 2026-09-12

## Outcome

LIMITED accepted on phone 197. The optional full-chrome shared Reader can now restore and write NextN's existing
zero-based NH reading progress when, and only when, the explicit debug sentinel
`readerLabUnit=__nextn_progress_readwrite__` is supplied. Ordinary shared-Lab launches remain read-only. No default
Reader replacement, settings migration, release entry, or production Reader removal is included.

## Implementation contract

- `NextNReaderProgressPersistence` is the host adapter around the existing `HistoryRepository`.
- Thumbnail entry keeps its explicit clicked page and never yields to stored progress.
- Non-numeric work ids and every request without the exact sentinel retain the requested page and perform no write.
- The adapter obtains real loaded gallery metadata before calling `HistoryRepository.saveProgress`.
- Visible-original events still pass through the epoch/seal gate. Closing seals the gate and awaits its durable flush
  before the host removes the Reader overlay.
- Restore completes before `ReaderSurface` receives its first session, so no page-zero flash is published first.

## Source/build checks

- `test_reader_progress_persistence_runtime.mjs`: PASS.
- Progress gate, observed-progress mapper, initial-policy lifecycle, and 1,404 tap-zone cases: PASS.
- `git diff --check`: PASS.
- Signed main HAP: 47,136,100 bytes,
  `ad5173efeb93bec437a62881d0fb39ba6e9902ab25a68e2c490d04c913d10a4b`.
- Signed ohosTest HAP: 43,760,661 bytes,
  `483c7a8b24a0b36396fa6f38a2b805313811e6f95da7e4dc7e2b0f9d8bccf52d`.

## Device 197 acceptance

Target `192.168.50.197:12345`, ALN-AL80, portrait 1260x2720. The checked protocol installed both matching HAPs with
replace-only install, then ran two independent native test invocations separated by
`aa force-stop com.erosteam.nextn`.

1. The device had no pre-existing `reading_history` row for gallery 678049. The test recorded that exact absence,
   seeded durable index 2, and launched the explicit read/write trial.
2. The first actual Reader frame was source index 2 with visible `3 / 14`. The host emitted index 2 and durable RDB
   state was index 2 with `has_read_progress=1`.
3. One LTR page turn produced source index 3 with visible `4 / 14`; the host emitted `[2,3]`, in-memory progress was
   3, and durable RDB state reached 3 before and after Reader close.
4. After force-stop, the second process opened directly on source index 3 with visible `4 / 14`; its only initial
   event was `[3]`.
5. The restore test deleted the temporary row because the exact original state was absence. The independent cleanup
   test then passed with no snapshot left to restore.

Hypium summaries were 1/1 PASS for write, 1/1 PASS for cold restore, and 1/1 PASS for independent cleanup. The final
device state is the launcher in portrait, MUSIC volume 3, screen timeout override 10000 ms, and the lease is released.

Evidence:

- Main protocol metadata:
  `.hermes-artifacts/20260912-shared-progress-persistence-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native-rerun4/run-metadata.json`
- Initial durable restore:
  `.hermes-artifacts/20260912-shared-progress-persistence-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native-rerun4/write-initial.png`
- Durable next page:
  `.hermes-artifacts/20260912-shared-progress-persistence-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native-rerun4/write-next.png`
- Cold-process restore:
  `.hermes-artifacts/20260912-shared-progress-persistence-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/02-native-rerun4/cold-restore.png`
- Cleanup metadata and launcher:
  `.hermes-artifacts/20260912-shared-progress-persistence-197/device197__ALN-AL80/not-applicable/portrait-1260x2720/03-cleanup-rerun4/`

## Rejected intermediate evidence

The protocol validator correctly rejected three earlier attempts. The first used the test module's RDB context, which
is `/entry_test`, rather than the actual Reader host's `/entry` context. After switching to EntryAbility, the next
attempt proved the restore visually but queried the obsolete `rkit-page-position` test id instead of the full-chrome
`rkit-chrome-page` id. Neither failure was counted as product acceptance; each run executed the independent cleanup
before continuing.

## Remaining boundary

This closes NextN's explicit debug-only progress write/restore path, not default replacement. The forced-single
long-strip screenshots are page-identity evidence only and are intentionally not claimed as a readable long-image
layout. Remaining replacement work includes production entry opt-in plumbing, cross-mode progress semantics,
thumbnail-entry precedence on-device, failure/retry persistence, and equivalent host adapters for NextE and Koma.

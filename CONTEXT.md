# Managed machines

This context covers the personal machines, user environment, and hosted services
managed by this repository, including their recovery after data loss.

## Language

**Machine recovery**:
Reinstallation of a machine's configured operating system followed by restoration
of its user files, persistent service state, and required identities.
_Avoid_: Disk-image restore

**Home backup**:
Backup history of the user's home directory on a machine. Service state within
that directory also belongs to the service backup scope.

**Service backup**:
Backup history of the persistent data and identities needed to restore a service,
regardless of where that state lives on the machine.

**Restic restore point**:
The recorded contents of the selected files from one backup run on one machine,
identified by its source machine, time, and backup scope.
_Avoid_: Unqualified "snapshot" when it could mean a Storage Box snapshot

**Complete restore point**:
A restore point whose selected data was captured and stored successfully with
the consistency required for recovery. Partial captures do not establish backup
freshness.

**Shared backup repository**:
The common backup history for `loem` and `note`, preserving each machine's
restore points while sharing storage for identical content.
_Avoid_: Synchronized home directory, mirror

**Backup access identity**:
The dedicated identity shared by enrolled machines to access the backup target,
independent of their user and host login identities.
_Avoid_: User SSH key, host SSH key

**Storage Box snapshot**:
A provider-maintained historical view of the backup target, used to recover
repository data that has been changed or deleted.
_Avoid_: Restic restore point

**AI exchange corpus**:
The full AI request and response exchanges retained for future model fine-tuning.
This is ordinary machine data covered by backup retention, even when its files
are described as logs.
_Avoid_: Diagnostic logs

**Diagnostic logs**:
Operational messages used to investigate application behavior. They are distinct
from the AI exchange corpus and may be disposable under an explicit exclusion.

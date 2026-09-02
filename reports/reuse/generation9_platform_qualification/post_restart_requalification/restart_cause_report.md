# Post-Restart Cause Report

The restart is classified as **A — USER_INITIATED_PLANNED_RESTART**.

The decisive evidence is an explicit User32 event 1074 showing that the Windows Start Menu process initiated a power-off on behalf of the interactive user. It is followed by EventLog 6006, an orderly Kernel-General shutdown record, and a Kernel-Boot record stating that the previous shutdown succeeded. The next boot completed normally.

The localized reason label on event 1074 is `OTHER_UNPLANNED`, but that label does not describe an unclean power loss in this event sequence. There is no event 6008, Kernel-Power 41, BugCheck 1001, new dump, WHEA hardware error, serious Disk/Ntfs/storage error, critical-process failure, or Windows Update restart initiator in the examined window.

The historical system-stability hard stop remains unchanged. It was the correct fail-closed decision based on the evidence available at that time. This report is an append-only successor attestation.

No machine name, user name, private absolute path, raw event-log message, or dump content is included in the committed evidence.

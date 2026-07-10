# Task Card: Host and Device Operation

Marker: TASK_HOST_OPERATIONS_V1_20260710

## Required flow

1. Run tools/chatctx with the exact selected scope.
2. Confirm lane, scope, host, route class and secret class.
3. Gather current state and logs.
4. Stop when host, target path or rollback anchor is missing.
5. Prefer tools/cgflow for guarded artifacts and repo work.
6. Use dispatcher delivery for host artifacts.
7. Run remote verify before execution.
8. Match the final result marker to the active lane and scope.

## Completion

A delivery marker is not a host execution result.
A clipboard marker is not a technical verification result.
Close only with explicit scope, host and operation result markers.

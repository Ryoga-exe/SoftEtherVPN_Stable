## See ARM64 port notes

`See` is not blocked by project-file migration alone. The remaining blocker is architectural:
the driver is implemented as an NDIS 5 protocol driver, and the WDK headers reject that API
surface on ARM64.

### Why the current code does not scale to ARM64

- `src/See/Packet.c`
  - `DriverEntry()` registers `NDIS_PROTOCOL_CHARACTERISTICS`.
  - `ProtocolChar.MajorNdisVersion` is set to `5` under `NDIS50`.
  - `NdisRegisterProtocol()` is used instead of the NDIS 6 protocol registration path.
- `src/See/Openclos.c`
  - Open and close flow depends on `NdisOpenAdapter()` / `NdisCloseAdapter()`.
  - OID bootstrap uses `NdisRequest()`.
- `src/See/Read.c`
  - Receive flow is built around `NDIS_PACKET`, `NdisTransferData()`,
    `NPF_TransferDataComplete()`, and MDL chaining for legacy receive indications.
- `src/See/Write.c`
  - Send flow depends on `NdisAllocatePacket()`, `NdisChainBufferAtFront()`,
    and `NdisSend()`.
- `src/See/Packet.h`
  - Core data structures embed `NDIS_REQUEST`, `NDIS_PACKET`, and legacy packet-pool
    assumptions throughout the open-instance lifetime.

These are not isolated typedef or macro issues. They define the driver's control path,
receive path, send path, and OID plumbing.

### What this means for migration

Adding an ARM64 project configuration without changing the implementation is not enough.
The likely next step is an NDIS 6 port that replaces the NDIS 5 protocol model with an
NDIS 6-compatible design and API set.

That port would at minimum need to revisit:

- driver registration and bind/unbind lifecycle
- packet send/receive path
- OID request path
- any assumptions tied to `NDIS_PACKET` / `NdisTransferData`

### Current repository guidance

- Keep `See` on x64-only WDK 10 migration for now.
- Do not add `Release|ARM64` back to `See.vcxproj` until there is a real NDIS 6 migration
  plan for the driver implementation.

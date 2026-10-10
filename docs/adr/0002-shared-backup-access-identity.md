# Share a dedicated backup access identity

Backup clients will use one dedicated SSH keypair, with its private key managed
through agenix and its public key authorized once on the Storage Box.
This lets future machines join by receiving the same encrypted secret through
the existing host-rekey workflow, without another Storage Box authorization
change or a dependency on a user's SSH key or agent.
The trade-off is fleet-wide rotation when this identity must be replaced,
consistent with the shared repository access boundary in
[ADR-0001](0001-shared-backup-repository.md).

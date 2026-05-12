# Deployment Checklist — GroveBasinFactory

### General rules
- [x] A different deployer EOA shall be used across different chains (to prevent a situation where the same address on different chains has a different name and source code).
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.

### Deployment preparation
- [x] Update your foundry to the latest stable version, and ensure that the updated version is at least one week old (to avoid a not-yet-detected supply chain attack).
- [x] Note down your foundry version used for the deployments by documenting `foundryup` logs:
  ```
  foundryup: use - forge 1.5.1-stable (b0a9dd9ced 2025-12-22T11:41:09.812070000Z)
  foundryup: use - cast 1.5.1-stable (b0a9dd9ced 2025-12-22T11:41:09.812070000Z)
  foundryup: use - anvil 1.5.1-stable (b0a9dd9ced 2025-12-22T11:41:09.812070000Z)
  foundryup: use - chisel 1.5.1-stable (b0a9dd9ced 2025-12-22T11:41:09.812070000Z)
  ```
- [x] Find the latest audits for the contract to be deployed. If there are 2 reports, compare commit hashes between them and inspect the diff. If the diff is safe, note down the latest of the two commit hashes.
  - The commit URL: https://github.com/grove-labs/grove-basin/commit/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d
- [x] Freshly clone the repository with the contract at the commit determined above.
- [x] Init submodules and install npm packages using the appropriate package manager (npm, yarn, pnpm – based on the lockfile type present in the repository).
- [x] Check the deployer address (e.g., using `cast wallet address`) to match the expected value and expected transaction history.
  - Deployer: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817`
- [x] Ensure the deployer has enough gas tokens.
- [x] Document the command planned to be used to perform the deployment. Prefer writing a foundry script for anything that requires more than one transaction.

```bash
forge create src/GroveBasinFactory.sol:GroveBasinFactory \
    --account grove-basin-deployer \
    --rpc-url mainnet \
    --broadcast --verify
```

- [x] Perform a test deployment using a fresh *private* Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.
  - GroveBasinFactory: [Tenderly testnet tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/efd87152-530e-421e-9203-e3d597434433/tx/0x9e23055d462f40c9cdd8cf083f99514f0df89268fb3c0a4a34efb0cecfffc5a8)

### Deployment
- [x] Set production RPC URL (only trusted RPC provider shall be used to avoid poisoning attacks).
  - RPC provider: Alchemy
- [x] Set API key for the verification provider (e.g., Etherscan) compatible with the target chain.
  - Verification provider: Etherscan
- [x] Execute the same command used for testnet deployment, but with `--verify`.
- [x] Inspect the transaction history of the deployer.
- [ ] Perform all relevant checks documented in the technical doc (constructor arguments, optimizations, bytecode verify, ownership transfer).
- [ ] Independently verify the deployment by another member of the team.

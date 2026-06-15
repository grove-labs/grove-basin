# Deployment Checklist — BUIDL USDS/USDC Basin (SetupBUIDLUsdsUsdcBasin)

### General rules
- [x] A different deployer EOA shall be used across different chains (to prevent a situation where the same address on different chains has a different name and source code).
- [x] A deployer EOA shall not be used for other transactions besides the deployments and configuration of contracts.
- [x] Avoid storing a private key in the env files or in the bash history. Prefer using a password-protected keystore or a hardware wallet.

### Deployment preparation
- [x] Update your foundry to the latest stable version, and ensure that the updated version is at least one week old (to avoid a not-yet-detected supply chain attack).
- [x] Note down your foundry version used for the deployments by documenting `foundryup` logs:
  ```
  foundryup: use - forge 1.7.1 (4072e48705 2026-05-08T07:54:31.470926000Z)
  foundryup: use - cast 1.7.1 (4072e48705 2026-05-08T07:54:31.470926000Z)
  foundryup: use - anvil 1.7.1 (4072e48705 2026-05-08T07:54:31.470926000Z)
  foundryup: use - chisel 1.7.1 (4072e48705 2026-05-08T07:54:31.470926000Z)
  ```
- [x] Find the latest audits for the contract to be deployed. If there are 2 reports, compare commit hashes between them and inspect the diff. If the diff is safe, note down the latest of the two commit hashes.
  - The commit URL: https://github.com/grove-labs/grove-basin/commit/9c812fcb32df0475ceaf443e3db39c3302a5e56c
- [x] Freshly clone the repository with the contract at the commit determined above.
- [x] Init submodules and install npm packages using the appropriate package manager (npm, yarn, pnpm – based on the lockfile type present in the repository).
- [x] Check the deployer address (e.g., using `cast wallet address`) to match the expected value and expected transaction history.
  - Deployer: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817`
- [x] Ensure the deployer has enough gas tokens.
- [x] Document the command planned to be used to perform the deployment. Prefer writing a foundry script for anything that requires more than one transaction.

**BUIDL GroveBasin and UsdsUsdcPocket:**
```bash
DEPLOYER=<deployer_address> \
forge script script/SetupBUIDLUsdsUsdcBasin.s.sol:SetupBUIDLUsdsUsdcBasin \
    --rpc-url mainnet \
    --account grove-basin-deployer \
    --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
    --broadcast --slow --verify
```

**BUIDLTokenRedeemer:**
```bash
forge script script/SetupBUIDLUsdsUsdcBasin.s.sol:SetupBUIDLUsdsUsdcBasin \
    --sig "deployRedeemerContractAndGrantRedeemerRole(address)" <TBD: BUIDL GroveBasin address> \
    --rpc-url mainnet \
    --account grove-basin-deployer \
    --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
    --broadcast --slow --verify
```

- [ ] Perform a test deployment using a fresh *private* Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.
  - GroveBasin: TBD
    - Tenderly test tx: TBD
  - UsdsUsdcPocket: TBD
    - Tenderly test tx: TBD
  - BUIDLTokenRedeemer: TBD
    - Tenderly test tx: TBD

### Deployment
- [x] Set production RPC URL (only trusted RPC provider shall be used to avoid poisoning attacks).
  - RPC provider: Alchemy
- [x] Set API key for the verification provider (e.g., Etherscan) compatible with the target chain.
  - Verification provider: Etherscan
- [ ] Execute the same command used for testnet deployment, but with `--slow --verify`.
  - Total gas: TBD
  - Transactions/blocks: TBD
  - GroveBasin: TBD
    - Deploy tx: TBD
  - UsdsUsdcPocket: TBD
    - Deploy tx: TBD
  - BUIDLTokenRedeemer: TBD
    - Deploy tx: TBD
    - `addTokenRedeemer` tx: TBD
    - `grantRole(REDEEMER_ROLE)` tx: TBD
    - Redemption address: `0x8780Dd016171B91E4Df47075dA0a947959C34200`
- [ ] Inspect the transaction history of the deployer.
- [ ] Perform all relevant checks documented in the technical doc (constructor arguments, optimizations, bytecode verify, ownership transfer).
- [ ] Independently verify the deployment by another member of the team.

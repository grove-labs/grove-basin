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
    --sig "deployRedeemerContractAndGrantRedeemerRole(address)" 0xCBa428fB052B365557DAf52b744DFfF20d5FbEdD \
    --rpc-url mainnet \
    --account grove-basin-deployer \
    --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
    --broadcast --slow --verify
```

- [x] Perform a test deployment using a fresh *private* Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.
  - GroveBasin: `0xCBa428fB052B365557DAf52b744DFfF20d5FbEdD`
    - Tenderly test tx: `0x0b7b97dc752b262e17a50e08ea871c8a05eb78cf7b0348943848da405325f87d`
  - UsdsUsdcPocket: `0x39548FeF138370Db06e172eF0739894b2a613DF9`
    - Tenderly test tx: `0xe862d32871d4270ef7eb1a97cd55eef625238485b7db3713c66eff428ef48b50`
  - BUIDLTokenRedeemer: `0x73414528187A4986E2Af5D551fD14871b723E506`
    - Tenderly test tx: `0xd3f022e052f5047f9b149618d1d43c133d5bcdfb5b0824c9938332d59e52984d`

### Deployment
- [x] Set production RPC URL (only trusted RPC provider shall be used to avoid poisoning attacks).
  - RPC provider: Alchemy
- [x] Set API key for the verification provider (e.g., Etherscan) compatible with the target chain.
  - Verification provider: Etherscan
- [x] Execute the same command used for testnet deployment, but with `--slow --verify`.
  - Total gas: 0.015489045431022739 ETH (6768724 gas * avg 2.171567351 gwei)
  - Transactions/blocks: 20 transactions, blocks 25324010-25324038
  - GroveBasin: `0xCBa428fB052B365557DAf52b744DFfF20d5FbEdD`
    - Deploy tx: [0x990afcd9...](https://etherscan.io/tx/0x990afcd93b55b0fe5463bb91d0dc66dcfad685f3c47b393cedfbceae20e82340)
  - UsdsUsdcPocket: `0x39548FeF138370Db06e172eF0739894b2a613DF9`
    - Deploy tx: [0x77f6e80c...](https://etherscan.io/tx/0x77f6e80c7819d585ffb2e1f4bd8172edf19c89b12ca0b3ac0f02ec69f8d6c05f)
  - BUIDLTokenRedeemer: `0x73414528187A4986E2Af5D551fD14871b723E506`
    - Deploy tx: [0x888266d7...](https://etherscan.io/tx/0x888266d7097dbd63221f7087e33dad9abf6b11c31bd8ce5799b5993b12bc5a99)
    - `addTokenRedeemer` tx: [0x4f6f5e73...](https://etherscan.io/tx/0x4f6f5e737ae0fd4c7900a6bce8f7e884f476973bcbfa3b6d86b4c70d841e7b61)
    - `grantRole(REDEEMER_ROLE)` tx: [0x35887af4...](https://etherscan.io/tx/0x35887af49a71944ccb14cdc156bdc92a94d0aa2c3f72b76c987cfc9c8fc3d1a9)
    - Redemption address: `0x8780Dd016171B91E4Df47075dA0a947959C34200`
- [x] Inspect the transaction history of the deployer.
- [x] Perform all relevant checks documented in the technical doc (constructor arguments, optimizations, bytecode verify, ownership transfer).
- [x] Independently verify the deployment by another member of the team.

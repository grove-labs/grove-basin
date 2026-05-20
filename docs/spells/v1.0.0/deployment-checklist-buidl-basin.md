# Deployment Checklist — BUIDL USDS/USDC Basin (SetupBUIDLUsdsUsdcBasin)

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
    --sig "deployRedeemerContractAndGrantRedeemerRole(address)" 0x10b3d3A96646720f8B3a29229cF96d513f3C84F1 \
    --rpc-url mainnet \
    --account grove-basin-deployer \
    --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
    --broadcast --slow --verify
```

- [x] Perform a test deployment using a fresh *private* Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.
  - GroveBasin: `0x10b3d3A96646720f8B3a29229cF96d513f3C84F1`
    - [Tenderly test tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/02d7edf3-c111-495c-88e6-98db7a9a2102/tx/0xa1299d2edf40902735b7f0285f0d41b46c0785a3cb4e0357fe9c6162db1dc937)
  - UsdsUsdcPocket: `0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA`
    - [Tenderly test tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/02d7edf3-c111-495c-88e6-98db7a9a2102/tx/0x70d642074437e2dae7fc8f13fbf6d88d4a808ff3ee7f14f012f2ef9fe65b0332)
  - BUIDLTokenRedeemer: `0x99e5e7c533c7319f855b940561df285be022c82d`
    - [Tenderly test tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/e7893a1c-cc85-45f4-8445-7c0c7f11b7e9/tx/0x393165ada555b68f49dce8e93e43901670a3f21a948d03161933a81a0690b0fd)

### Deployment
- [x] Set production RPC URL (only trusted RPC provider shall be used to avoid poisoning attacks).
  - RPC provider: Alchemy
- [x] Set API key for the verification provider (e.g., Etherscan) compatible with the target chain.
  - Verification provider: Etherscan
- [x] Execute the same command used for testnet deployment, but with `--slow --verify`.
  - Total gas: 6,005,828 (0.000989 ETH at avg 0.188 gwei)
  - 17 transactions, blocks 25081592–25081610
  - GroveBasin: [`0x10b3d3A96646720f8B3a29229cF96d513f3C84F1`](https://etherscan.io/address/0x10b3d3A96646720f8B3a29229cF96d513f3C84F1)
    - Deploy tx: [0x4c394796...](https://etherscan.io/tx/0x4c39479656f2293361acb059d467cffd3b11f1346dfc52e99bd2a161521775e8)
  - UsdsUsdcPocket: [`0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA`](https://etherscan.io/address/0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA)
    - Deploy tx: [0xc6f0e579...](https://etherscan.io/tx/0xc6f0e579c7636321f4b27c4ec2f701e9afd6ce01488c111de66f932c5eaf8b5c)
  - BUIDLTokenRedeemer (old — superseded): [`0x0D46f8A832B76A79AC3B5F29fFfc35ACeebad885`](https://etherscan.io/address/0x0D46f8A832B76A79AC3B5F29fFfc35ACeebad885)
    - Deploy tx: [0x2577828e...](https://etherscan.io/tx/0x2577828e23503fdc87af290e044df43474341bc072f62fde6e983ef08b0729a1)
  - BUIDLTokenRedeemer (current): [`0x99E5E7c533C7319f855B940561Df285bE022c82d`](https://etherscan.io/address/0x99E5E7c533C7319f855B940561Df285bE022c82d)
    - Deploy tx: [0xc6152410...](https://etherscan.io/tx/0xc61524108a1fecf43252b20082c169ce60096b8e4f78c59125a2585d33f6dc49)
    - `addTokenRedeemer` tx: [0xc92b0e53...](https://etherscan.io/tx/0xc92b0e537e826716ec1b2887c661f60ff419d2fbd67f1d15efb092c4ce3e5487)
    - `grantRole(REDEEMER_ROLE)` tx: [0xfaf84da7...](https://etherscan.io/tx/0xfaf84da7a343b4fbd2776b955b4a4252de2e712f05092f45425b249ce7c407b4)
    - Redemption address: `0x8780Dd016171B91E4Df47075dA0a947959C34200`
- [x] Inspect the transaction history of the deployer.
- [x] Perform all relevant checks documented in the technical doc (constructor arguments, optimizations, bytecode verify, ownership transfer).
- [ ] Independently verify the deployment by another member of the team.

# Deployment Checklist — JTRSY USDS/USDC Basin (SetupJTRSYUsdsUsdcBasin)

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

```bash
DEPLOYER=<deployer_address> \
forge script script/SetupJTRSYUsdsUsdcBasin.s.sol:SetupJTRSYUsdsUsdcBasin \
    --rpc-url mainnet \
    --account grove-basin-deployer \
    --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
    --broadcast --slow --verify
```

- [x] Perform a test deployment using a fresh *private* Tenderly testnet. Then, inspect submitted transactions to match the desired outcome.
  - GroveBasin: `0xf08943f817e1F902dEbC884c7B19Ea5764594Ac9` ([Tenderly testnet tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnets/d2d3c761-6480-44ce-b204-2f3cb6a1aa43/instance/fd0208d5-2bb9-4435-b849-a5eb216f2d61/container/359fb691-669d-481d-bc9d-d8de3ab923eb/tx/0x193b4a4d12e68a4a527c3ca7ab0d762e21a4cbb27d3bd98ed65500493ce045d5))
  - UsdsUsdcPocket: `0x2Cd296095788A2741e72056D66B3Ae1fAeE23ea2` ([Tenderly testnet tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnets/d2d3c761-6480-44ce-b204-2f3cb6a1aa43/instance/fd0208d5-2bb9-4435-b849-a5eb216f2d61/container/359fb691-669d-481d-bc9d-d8de3ab923eb/tx/0x7b601f9425dd261b8715a8e2321d6aff1cc01ce046da6a54b28c8a71825981fc))
  - JTRSYTokenRedeemer: `0x7c5Ce1a1D50a6cb3Da97C9e202B3E7CD8e5b5b6c` ([Tenderly testnet tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnets/d2d3c761-6480-44ce-b204-2f3cb6a1aa43/instance/fd0208d5-2bb9-4435-b849-a5eb216f2d61/container/359fb691-669d-481d-bc9d-d8de3ab923eb/tx/0x4efbaf931511339618e669dc4c9dbacb881d6698925715486c2339f08748919d))

### Deployment
- [x] Set production RPC URL (only trusted RPC provider shall be used to avoid poisoning attacks).
  - RPC provider: Alchemy
- [x] Set API key for the verification provider (e.g., Etherscan) compatible with the target chain.
  - Verification provider: Etherscan
- [x] Execute the same command used for testnet deployment, but with `--slow --verify`.
  - GroveBasin: `0xf08943f817e1F902dEbC884c7B19Ea5764594Ac9`
    - Deploy tx: [0x17e4e472...](https://etherscan.io/tx/0x17e4e472d6a5874fd057f7e34c2e3cb8d29fa5544b373ef371e46ff6ce6332da)
  - UsdsUsdcPocket: `0x2Cd296095788A2741e72056D66B3Ae1fAeE23ea2`
    - Deploy tx: [0xa7d03ed1...](https://etherscan.io/tx/0xa7d03ed1f6ec5f718858a1c5c53cbf693604b7050cba4692de150a87b86a42a0)
  - JTRSYTokenRedeemer: `0x7c5Ce1a1D50a6cb3Da97C9e202B3E7CD8e5b5b6c`
    - Deploy tx: [0x17bf9bd8...](https://etherscan.io/tx/0x17bf9bd8e28c8ca2ffeb39baaada6615c75c749a1bfaf2596172df531e6289af)
- [x] Inspect the transaction history of the deployer.
- [x] Perform all relevant checks documented in the technical doc (constructor arguments, optimizations, bytecode verify, ownership transfer).
- [x] Independently verify the deployment by another member of the team.

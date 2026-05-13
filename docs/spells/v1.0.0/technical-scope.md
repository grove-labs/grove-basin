# General Technical Scope Template

## Trusted addresses

| **Contract name** | **Address with URL** | **Source URL** |
|---|---|---|
| USDS | [0xdC035D45d973E3EC169d2276DDab16f1e407384F](https://etherscan.io/address/0xdC035D45d973E3EC169d2276DDab16f1e407384F) | TODO |
| USDC | [0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) | TODO |
| BUIDL | [0x7712c34205737192402172409a8F7ccef8aA2AEc](https://etherscan.io/address/0x7712c34205737192402172409a8F7ccef8aA2AEc) | TODO |
| JTRSY | [0x8c213ee79581Ff4984583C6a801e5263418C4b86](https://etherscan.io/address/0x8c213ee79581Ff4984583C6a801e5263418C4b86) | TODO |
| Centrifuge JTRSY Vault | [0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A](https://etherscan.io/address/0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A) | TODO |
| USDS PSM Wrapper | [0xA188EEC8F81263234dA3622A406892F3D630f98c](https://etherscan.io/address/0xA188EEC8F81263234dA3622A406892F3D630f98c) | TODO |
| ALM Proxy | [0x491EDFB0B8b608044e227225C715981a30F3A44E](https://etherscan.io/address/0x491EDFB0B8b608044e227225C715981a30F3A44E) | TODO |
| ALM Relayer | [0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f](https://etherscan.io/address/0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f) | TODO |
| ALM Freezer | [0xB0113804960345fd0a245788b3423319c86940e5](https://etherscan.io/address/0xB0113804960345fd0a245788b3423319c86940e5) | TODO |
| Grove Proxy | [0x1369f7b2b38c76B6478c0f0E66D94923421891Ba](https://etherscan.io/address/0x1369f7b2b38c76B6478c0f0E66D94923421891Ba) | TODO |

## Pre-deployed contracts

1. **GroveBasinFactory (BUIDL basin)**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a](https://etherscan.io/address/0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a)
    - Deployment transaction trace: [0x6154253c2283e32872ab8c3ead1658eefa2f30b0916236ca5ef649b1bdde1679](https://etherscan.io/tx/0x6154253c2283e32872ab8c3ead1658eefa2f30b0916236ca5ef649b1bdde1679)
    - Code verification
        - Source code URL (at the audited commit hash): [src/GroveBasinFactory.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/GroveBasinFactory.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode 0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a src/GroveBasinFactory.sol:GroveBasinFactory --rpc-url mainnet`
        - Compilation optimizations match optimizer=true, runs=180, source solc 0.8.24.
        - Constructor arguments: None (GroveBasinFactory has no constructor arguments).
    - Additional parameters configured on the contract by a privileged actor: None — factory is stateless.
    - Ownership, roles, privilege callers: None — factory has no access control.
    - Deployment command:
        ```
        forge create src/GroveBasinFactory.sol:GroveBasinFactory --account grove-basin-deployer --rpc-url mainnet --broadcast
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a#code)
    - The deployer no longer has a privileged role: N/A — factory has no roles.

2. **USDS/USDC Fixed Rate Provider (Fixed 1:1)**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x7928A185B8137D1CD2a0996a810A04dB2837419D](https://etherscan.io/address/0x7928A185B8137D1CD2a0996a810A04dB2837419D)
    - Deployment transaction trace: [0xfc222a7bc6442a387de4b1cc9abba93c796783ca8b720ef521e559688e37a271](https://etherscan.io/tx/0xfc222a7bc6442a387de4b1cc9abba93c796783ca8b720ef521e559688e37a271)
    - Code verification
        - Source code URL (at the audited commit hash): [src/rate-providers/FixedRateProvider.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/rate-providers/FixedRateProvider.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode 0x7928A185B8137D1CD2a0996a810A04dB2837419D src/rate-providers/FixedRateProvider.sol:FixedRateProvider --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(uint256)" 1000000000000000000000000000)`
        - Compilation optimizations match optimizer=true, runs=180, source solc 0.8.24.
        - Constructor arguments:
            1. `rate`
                - Argument value: `1000000000000000000000000000` (1e27, i.e. 1:1)
                - Description: Fixed 1:1 rate for USDS/USDC peg
    - Additional parameters configured on the contract by a privileged actor: None — FixedRateProvider is immutable.
    - Ownership, roles, privilege callers: None — no access control.
    - Deployment command:
        ```
        forge script script/DeployFixedRateProvider.s.sol:DeployFixedRateProvider --rpc-url mainnet --account grove-basin-deployer --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x7928A185B8137D1CD2a0996a810A04dB2837419D#code)
    - The deployer no longer has a privileged role: N/A

3. **BUIDL Chronicle Rate Provider**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x69a171853575FFD41574EA80Abfc6337AcbC4d43](https://etherscan.io/address/0x69a171853575FFD41574EA80Abfc6337AcbC4d43)
    - Deployment transaction trace: [0xf92bfcada2976746a9b7fce8bd98636895db6a6046da44bc710abe42c6efd248](https://etherscan.io/tx/0xf92bfcada2976746a9b7fce8bd98636895db6a6046da44bc710abe42c6efd248)
    - Code verification
        - Source code URL (at the audited commit hash): [src/rate-providers/ChronicleRateProvider.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/rate-providers/ChronicleRateProvider.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode 0x69a171853575FFD41574EA80Abfc6337AcbC4d43 src/rate-providers/ChronicleRateProvider.sol:ChronicleRateProvider --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address)" 0x8c68E0CacB61a065b99E2104457aCC829d61cbB0)`
        - Compilation optimizations match optimizer=true, runs=180, source solc 0.8.24.
        - Constructor arguments:
            1. `oracle`
                - Argument value: `0x8c68E0CacB61a065b99E2104457aCC829d61cbB0` (Chronicle BUIDL/USD oracle router)
                - External source: [Chronicle Labs Dashboard](https://chroniclelabs.org/dashboard/proofofasset/blackrock-buidl)
    - Additional parameters configured on the contract by a privileged actor: None — ChronicleRateProvider is immutable.
    - Ownership, roles, privilege callers: None — no access control.
    - Deployment command:
        ```
        forge script script/DeployChronicleRateProvider.s.sol:DeployChronicleRateProvider --rpc-url mainnet --sig "run(address)" 0x8c68E0CacB61a065b99E2104457aCC829d61cbB0 --account grove-basin-deployer --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x69a171853575FFD41574EA80Abfc6337AcbC4d43#code)
    - The deployer no longer has a privileged role: N/A

4. **JTRSY Chronicle Rate Provider**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5](https://etherscan.io/address/0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5)
    - Deployment transaction trace: [0xabaaf7e7f32c02e68029f16cb10cbf6cdc45371220072e4acaaf9bfcf1713a73](https://etherscan.io/tx/0xabaaf7e7f32c02e68029f16cb10cbf6cdc45371220072e4acaaf9bfcf1713a73)
    - Code verification
        - Source code URL (at the audited commit hash): [src/rate-providers/ChronicleRateProvider.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/rate-providers/ChronicleRateProvider.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode 0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5 src/rate-providers/ChronicleRateProvider.sol:ChronicleRateProvider --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address)" 0xE980a33EFA3EDDaa689eCbdCE4B2278D4DB94471)`
        - Compilation optimizations match optimizer=true, runs=180, source solc 0.8.24.
        - Constructor arguments:
            1. `oracle`
                - Argument value: `0xE980a33EFA3EDDaa689eCbdCE4B2278D4DB94471` (Chronicle JTRSY/USD oracle router)
                - External source: [Chronicle Labs Dashboard](https://chroniclelabs.org/dashboard/proofofasset/janus-henderson-anemoy-treasury-fund)
    - Additional parameters configured on the contract by a privileged actor: None — ChronicleRateProvider is immutable.
    - Ownership, roles, privilege callers: None — no access control.
    - Deployment command:
        ```
        forge script script/DeployChronicleRateProvider.s.sol:DeployChronicleRateProvider --rpc-url mainnet --sig "run(address)" 0xE980a33EFA3EDDaa689eCbdCE4B2278D4DB94471 --account grove-basin-deployer --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5#code)
    - The deployer no longer has a privileged role: N/A

5. **JTRSY Admin TimelockController**
    - Chain name: Ethereum Mainnet
    - Contract address: [0xA52dC9876aB4A9DB6dAfbb83410554086054d140](https://etherscan.io/address/0xA52dC9876aB4A9DB6dAfbb83410554086054d140)
    - Deployment transaction trace: [0xec51cda57fcb7698dbc3fb9a7da1bd8eb0fca506332700546a311ffd3b265b9d](https://etherscan.io/tx/0xec51cda57fcb7698dbc3fb9a7da1bd8eb0fca506332700546a311ffd3b265b9d)
    - Library version: [OpenZeppelin Contracts v5.5.0](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/fcbae5394ae8ad52d8e580a3477db99814b9d565)
    - Code verification
        - Source code URL (at the audited commit hash): [OpenZeppelin `TimelockController`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/fcbae5394ae8ad52d8e580a3477db99814b9d565/contracts/governance/TimelockController.sol)
        - External URLs to the audit reports: [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/audits/2025-10-v5.5.pdf)
        - Deployed bytecode verification: `forge verify-bytecode 0xA52dC9876aB4A9DB6dAfbb83410554086054d140 lib/openzeppelin-contracts/contracts/governance/TimelockController.sol:TimelockController --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(uint256,address[],address[],address)" 604800 "[0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c]" "[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]" 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817)`
        - Constructor arguments:
            1. `minDelay`
                - Argument value: `604800` (7 days)
                - External source: Script constant `MIN_DELAY`
            2. `proposers`
                - Argument value: `[0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c]`
                - External source: From private chats with Anemoy
            3. `executors`
                - Argument value: `[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]` (Grove Proxy)
                - External source: grove-address-registry `Ethereum.GROVE_PROXY`
            4. `admin`
                - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
                - External source: Deployer EOA
    - Additional parameters configured on the contract by a privileged actor: `CANCELLER_ROLE` granted to ALM Freezer (`0xB0113804960345fd0a245788b3423319c86940e5`) in the deployment script.
    - Ownership, roles, privilege callers:
        - `PROPOSER_ROLE`: `0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c`
        - `EXECUTOR_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
        - `CANCELLER_ROLE`: `0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c` (proposer, via constructor) + `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer, via script)
        - `DEFAULT_ADMIN_ROLE`: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer — to be revoked as pre-requirement)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 forge script script/DeployTimelockController.s.sol:DeployTimelockController --rpc-url mainnet --sig "run(address)" 0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c --account grove-basin-deployer --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0xA52dC9876aB4A9DB6dAfbb83410554086054d140#code)
    - The deployer no longer has a privileged role: TODO — `DEFAULT_ADMIN_ROLE` must be revoked after Anemoy does a test transaction (see pre-requirements).

6. **BUIDL Admin TimelockController**
    - Chain name: Ethereum Mainnet
    - Contract address: [0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34](https://etherscan.io/address/0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34)
    - Library version: [OpenZeppelin Contracts v5.5.0](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/fcbae5394ae8ad52d8e580a3477db99814b9d565)
    - Deployment transaction trace: [0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8](https://etherscan.io/tx/0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8)
    - Code verification
        - Source code URL (at the audited commit hash): [OpenZeppelin `TimelockController`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/fcbae5394ae8ad52d8e580a3477db99814b9d565/contracts/governance/TimelockController.sol)
        - External URLs to the audit reports: [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/audits/2025-10-v5.5.pdf)
        - Deployed bytecode verification: `forge verify-bytecode 0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34 lib/openzeppelin-contracts/contracts/governance/TimelockController.sol:TimelockController --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(uint256,address[],address[],address)" 604800 "[0x6D99f476E7E9FCcd189fb87023cFa301364Fa817]" "[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]" 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817)`
        - Constructor arguments:
            1. `minDelay`
                - Argument value: `604800` (7 days)
                - External source: Script constant `MIN_DELAY`
            2. `proposers`
                - Argument value: `[0x6D99f476E7E9FCcd189fb87023cFa301364Fa817]` (deployer — temporary, to be replaced with Securitize owner address)
                - External source: Script argument
            3. `executors`
                - Argument value: `[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]` (Grove Proxy)
                - External source: grove-address-registry `Ethereum.GROVE_PROXY`
            4. `admin`
                - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
                - External source: Deployer EOA
    - Additional parameters configured on the contract by a privileged actor: `CANCELLER_ROLE` granted to ALM Freezer (`0xB0113804960345fd0a245788b3423319c86940e5`) in the deployment script.
    - Ownership, roles, privilege callers:
        - `PROPOSER_ROLE`: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer — temporary, to be replaced with Securitize owner address)
        - `EXECUTOR_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
        - `CANCELLER_ROLE`: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (proposer, via constructor) + `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer, via script)
        - `DEFAULT_ADMIN_ROLE`: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer — to be revoked as pre-requirement)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 forge script script/DeployTimelockController.s.sol:DeployTimelockController --rpc-url mainnet --sig "run(address)" 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --account grove-basin-deployer --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34#code)
    - The deployer no longer has a privileged role: TODO — `DEFAULT_ADMIN_ROLE` must be revoked after Securitize provides an owner address and does a test transaction (see pre-requirements).

7. **JTRSY GroveBasin**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363](https://etherscan.io/address/0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363)
    - Deployment transaction trace: [0x7d3a7d8b0e3f06bd945482ee9d10bbd8c8f0dc2524736edc81d3ed99f94f0b82](https://etherscan.io/tx/0x7d3a7d8b0e3f06bd945482ee9d10bbd8c8f0dc2524736edc81d3ed99f94f0b82) (deployed via `GroveBasinFactory.deploy()` at `0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
    - Deployed by a factory:
        - Source code URL (at the audited commit hash): [src/GroveBasin.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/GroveBasin.sol)
        - Contract being called: GroveBasinFactory ([0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a](https://etherscan.io/address/0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a))
        - External docs page with this address: N/A
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Function being called: `deploy(address owner, address liquidityProvider, address swapToken, address collateralToken, address creditToken, address swapTokenRateProvider, address collateralTokenRateProvider, address creditTokenRateProvider)`
        - Function arguments:
            - `owner`
                - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: `DEPLOYER` env var in the deployment script. Can be verified by checking the `msg.sender` of the `GroveBasinFactory.deploy()` call in the [deployment transaction trace](https://etherscan.io/tx/0x7d3a7d8b0e3f06bd945482ee9d10bbd8c8f0dc2524736edc81d3ed99f94f0b82). Grove to confirm.
            - `liquidityProvider`
                - Argument value: `0x491EDFB0B8b608044e227225C715981a30F3A44E` (ALM Proxy)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: grove-address-registry [`Ethereum.ALM_PROXY`](lib/grove-address-registry/src/Ethereum.sol). Can be verified by calling `liquidityProvider()` on the deployed GroveBasin. Grove to confirm.
            - `swapToken`
                - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: grove-address-registry [`Ethereum.USDS`](lib/grove-address-registry/src/Ethereum.sol). Can be verified by calling `swapToken()` on the deployed GroveBasin and cross-referencing with the [USDS token on Etherscan](https://etherscan.io/address/0xdC035D45d973E3EC169d2276DDab16f1e407384F). Grove to confirm.
            - `collateralToken`
                - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: grove-address-registry [`Ethereum.USDC`](lib/grove-address-registry/src/Ethereum.sol). Can be verified by calling `collateralToken()` on the deployed GroveBasin and cross-referencing with the [USDC token on Etherscan](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48). Grove to confirm.
            - `creditToken`
                - Argument value: `0x8c213ee79581Ff4984583C6a801e5263418C4b86` (JTRSY Token)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Script constant `JTRSY_TOKEN`. Can be verified by calling `creditToken()` on the deployed GroveBasin and cross-referencing with the [JTRSY token on Etherscan](https://etherscan.io/address/0x8c213ee79581Ff4984583C6a801e5263418C4b86). Anemoy to confirm this is the correct JTRSY token.
            - `swapTokenRateProvider`
                - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (Fixed 1:1 rate provider for USDS/USDC)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Pre-deployed contract #2 (USDS/USDC Fixed Rate Provider). Can be verified by calling `swapTokenRateProvider()` on the deployed GroveBasin and cross-referencing with [pre-deployed contract #2](https://etherscan.io/address/0x7928A185B8137D1CD2a0996a810A04dB2837419D). Grove to confirm.
            - `collateralTokenRateProvider`
                - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (same fixed 1:1 rate provider — USDS and USDC share the same peg)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Pre-deployed contract #2 (USDS/USDC Fixed Rate Provider). Can be verified by calling `collateralTokenRateProvider()` on the deployed GroveBasin and cross-referencing with [pre-deployed contract #2](https://etherscan.io/address/0x7928A185B8137D1CD2a0996a810A04dB2837419D). Grove to confirm.
            - `creditTokenRateProvider`
                - Argument value: `0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5` (JTRSY ChronicleRateProvider)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Pre-deployed contract #4 (JTRSY Chronicle Rate Provider). Can be verified by calling `creditTokenRateProvider()` on the deployed GroveBasin and cross-referencing with [pre-deployed contract #4](https://etherscan.io/address/0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5). Grove to confirm.
    - Additional parameters configured on the contract by a privileged actor: Pocket set to `0xA15B8C07Fa32A4f8BeA3882600a673dc9CC1D6B9` (UsdsUsdcPocket). Token redeemer `0x212697f0A9Fc218210D98cd1A159dc8D8A87b8A8` (JTRSYTokenRedeemer) registered. Fee bounds set to [0, 500]. Four pause keys enabled (PAUSED_SWAP_SWAP_TO_CREDIT, PAUSED_SWAP_COLLATERAL_TO_CREDIT, PAUSED_DEPOSIT_CREDIT, PAUSED_WITHDRAW_CREDIT). See [SetupJTRSYUsdsUsdcBasin post-deploy configuration](#setupjtrsyusdsusdcbasin-post-deploy-configuration) for full details.
    - Ownership, roles, privilege callers:
        - `OWNER_ROLE` (`DEFAULT_ADMIN_ROLE`): `0xA52dC9876aB4A9DB6dAfbb83410554086054d140` (JTRSY Admin TimelockController)
        - `MANAGER_ADMIN_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy) + `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
        - `MANAGER_ROLE`: `0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f` (ALM Relayer)
        - `PAUSER_ROLE`: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
        - `REDEEMER_ROLE`: `0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a` ()
        - `REDEEMER_CONTRACT_ROLE`: `0x212697f0A9Fc218210D98cd1A159dc8D8A87b8A8` (JTRSYTokenRedeemer)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
        forge script script/SetupJTRSYUsdsUsdcBasin.s.sol:SetupJTRSYUsdsUsdcBasin \
            --rpc-url mainnet \
            --account grove-basin-deployer \
            --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
            --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363#code)
    - The deployer no longer has a privileged role: TODO — deployer to give up `MANAGER_ADMIN_ROLE` after test transaction from Anemoy

8. **JTRSY UsdsUsdcPocket**
    - Chain name: Ethereum Mainnet
    - Contract address: [0xA15B8C07Fa32A4f8BeA3882600a673dc9CC1D6B9](https://etherscan.io/address/0xA15B8C07Fa32A4f8BeA3882600a673dc9CC1D6B9)
    - Deployment transaction trace: [0x64604be1965dda0a8b72745206d43630fc0a7f8e598d40d75d0a183f420def81](https://etherscan.io/tx/0x64604be1965dda0a8b72745206d43630fc0a7f8e598d40d75d0a183f420def81)
    - Code verification
        - Source code URL (at the audited commit hash): [src/pockets/UsdsUsdcPocket.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/pockets/UsdsUsdcPocket.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode 0xA15B8C07Fa32A4f8BeA3882600a673dc9CC1D6B9 src/pockets/UsdsUsdcPocket.sol:UsdsUsdcPocket --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" 0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0xdC035D45d973E3EC169d2276DDab16f1e407384F 0xA188EEC8F81263234dA3622A406892F3D630f98c 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba)`
        - Compilation optimizations match optimizer=true, runs=180, source solc 0.8.24.
        - Constructor arguments:
            1. `basin_`
                - Argument value: `0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363` (JTRSY GroveBasin)
                - External source: Deployed in step 2 of SetupJTRSYUsdsUsdcBasin
            2. `usdc_`
                - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
                - External source: grove-address-registry `Ethereum.USDC`
            3. `usds_`
                - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
                - External source: grove-address-registry `Ethereum.USDS`
            4. `psm_`
                - Argument value: `0xA188EEC8F81263234dA3622A406892F3D630f98c` (USDS PSM Wrapper)
                - External source: Script constant `USDS_PSM_WRAPPER`
            5. `groveProxy_`
                - Argument value: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
                - External source: grove-address-registry `Ethereum.GROVE_PROXY`
    - Additional parameters configured on the contract by a privileged actor: None — UsdsUsdcPocket is immutable. Constructor grants max USDS approval to basin and Grove Proxy.
    - Ownership, roles, privilege callers: None — no access control. Callable by GroveBasin (via `MANAGER_ROLE`), Grove Proxy.
    - Deployment command: Deployed within `SetupJTRSYUsdsUsdcBasin` script (see item 7).
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0xA15B8C07Fa32A4f8BeA3882600a673dc9CC1D6B9#code)
    - The deployer no longer has a privileged role: N/A — no access control.

9. **JTRSY JTRSYTokenRedeemer**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x212697f0A9Fc218210D98cd1A159dc8D8A87b8A8](https://etherscan.io/address/0x212697f0A9Fc218210D98cd1A159dc8D8A87b8A8)
    - Deployment transaction trace: [0x2386be7468d4c752f78d92d6f9435af778e8d1e92d8b93c85e9ed3891a562b82](https://etherscan.io/tx/0x2386be7468d4c752f78d92d6f9435af778e8d1e92d8b93c85e9ed3891a562b82)
    - Code verification
        - Source code URL (at the audited commit hash): [src/redeemers/JTRSYTokenRedeemer.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/redeemers/JTRSYTokenRedeemer.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode 0x212697f0A9Fc218210D98cd1A159dc8D8A87b8A8 src/redeemers/JTRSYTokenRedeemer.sol:JTRSYTokenRedeemer --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address)" 0x8c213ee79581Ff4984583C6a801e5263418C4b86 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A 0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363)`
        - Compilation optimizations match optimizer=true, runs=180, source solc 0.8.24.
        - Constructor arguments:
            1. `creditToken_`
                - Argument value: `0x8c213ee79581Ff4984583C6a801e5263418C4b86` (JTRSY)
                - External source: Script constant `JTRSY_TOKEN`
            2. `vault_`
                - Argument value: `0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A` (Centrifuge JTRSY vault)
                - External source: grove-address-registry `Ethereum.CENTRIFUGE_JTRSY`
            3. `basin_`
                - Argument value: `0x1FA4dB8D545Cbd22b7bbA2084348A2E6ef36E363` (JTRSY GroveBasin)
                - External source: Deployed in step 2 of SetupJTRSYUsdsUsdcBasin
    - Additional parameters configured on the contract by a privileged actor: None — JTRSYTokenRedeemer is immutable. Registered on the basin via `addTokenRedeemer()` which grants `REDEEMER_CONTRACT_ROLE` and calls `setUp()`.
    - Ownership, roles, privilege callers: None — no access control. Callable by the GroveBasin contract (`onlyBasin` modifier) and the basin's manager admin (Grove Proxy `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`).
    - Deployment command: Deployed within `SetupJTRSYUsdsUsdcBasin` script (see item 7).
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x212697f0A9Fc218210D98cd1A159dc8D8A87b8A8#code)
    - The deployer no longer has a privileged role: N/A — no access control.

10. **BUIDL GroveBasin**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x10b3d3A96646720f8B3a29229cF96d513f3C84F1](https://etherscan.io/address/0x10b3d3A96646720f8B3a29229cF96d513f3C84F1)
    - Deployment transaction trace: [0x4c39479656f2293361acb059d467cffd3b11f1346dfc52e99bd2a161521775e8](https://etherscan.io/tx/0x4c39479656f2293361acb059d467cffd3b11f1346dfc52e99bd2a161521775e8) (deployed via `GroveBasinFactory.deploy()` at `0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
    - Deployed by a factory:
        - Source code URL (at the audited commit hash): [src/GroveBasin.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/GroveBasin.sol)
        - Contract being called: GroveBasinFactory ([0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a](https://etherscan.io/address/0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a))
        - External docs page with this address: [Etherscan verified source](https://etherscan.io/address/0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a#code)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Function being called: `deploy(address owner, address liquidityProvider, address swapToken, address collateralToken, address creditToken, address swapTokenRateProvider, address collateralTokenRateProvider, address creditTokenRateProvider)`
        - Function arguments:
            - `owner`
                - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: `DEPLOYER` env var in the deployment script. Can be verified by checking the `msg.sender` of the `GroveBasinFactory.deploy()` call in the [deployment transaction trace](https://etherscan.io/tx/0x4c39479656f2293361acb059d467cffd3b11f1346dfc52e99bd2a161521775e8). Grove to confirm.
            - `liquidityProvider`
                - Argument value: `0x491EDFB0B8b608044e227225C715981a30F3A44E` (ALM Proxy)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: grove-address-registry [`Ethereum.ALM_PROXY`](lib/grove-address-registry/src/Ethereum.sol). Can be verified by calling `liquidityProvider()` on the deployed GroveBasin. Grove to confirm.
            - `swapToken`
                - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: grove-address-registry [`Ethereum.USDS`](lib/grove-address-registry/src/Ethereum.sol). Can be verified by calling `swapToken()` on the deployed GroveBasin and cross-referencing with the [USDS token on Etherscan](https://etherscan.io/address/0xdC035D45d973E3EC169d2276DDab16f1e407384F). Grove to confirm.
            - `collateralToken`
                - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: grove-address-registry [`Ethereum.USDC`](lib/grove-address-registry/src/Ethereum.sol). Can be verified by calling `collateralToken()` on the deployed GroveBasin and cross-referencing with the [USDC token on Etherscan](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48). Grove to confirm.
            - `creditToken`
                - Argument value: `0x7712c34205737192402172409a8F7ccef8aA2AEc` (BUIDL)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Script constant `BUIDL_TOKEN`. Can be verified by calling `creditToken()` on the deployed GroveBasin and cross-referencing with the [BUIDL token on Etherscan](https://etherscan.io/address/0x7712c34205737192402172409a8F7ccef8aA2AEc). Securitize to confirm this is the correct BUIDL token.
            - `swapTokenRateProvider`
                - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (Fixed 1:1 rate provider for USDS/USDC)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Pre-deployed contract #2 (USDS/USDC Fixed Rate Provider). Can be verified by calling `swapTokenRateProvider()` on the deployed GroveBasin and cross-referencing with [pre-deployed contract #2](https://etherscan.io/address/0x7928A185B8137D1CD2a0996a810A04dB2837419D). Grove to confirm.
            - `collateralTokenRateProvider`
                - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (same fixed 1:1 rate provider — USDS and USDC share the same peg)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Same as `swapTokenRateProvider` (pre-deployed contract #2). Can be verified by calling `collateralTokenRateProvider()` on the deployed GroveBasin. Grove to confirm.
            - `creditTokenRateProvider`
                - Argument value: `0x69a171853575FFD41574EA80Abfc6337AcbC4d43` (BUIDL ChronicleRateProvider)
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: Pre-deployed contract #3 (BUIDL Chronicle Rate Provider). Can be verified by calling `creditTokenRateProvider()` on the deployed GroveBasin and cross-referencing with [pre-deployed contract #3](https://etherscan.io/address/0x69a171853575FFD41574EA80Abfc6337AcbC4d43). Grove to confirm.
    - Additional parameters configured on the contract by a privileged actor: Pocket set to `0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA` (UsdsUsdcPocket). Fee bounds set to [0, 500]. Four pause keys enabled (PAUSED_SWAP_SWAP_TO_CREDIT, PAUSED_SWAP_COLLATERAL_TO_CREDIT, PAUSED_DEPOSIT_CREDIT, PAUSED_WITHDRAW_CREDIT). BUIDLTokenRedeemer deployment skipped (BUIDL_REDEMPTION_ADDRESS not set). REDEEMER_ROLE grant skipped (SECURITIZE_REDEEMER_ADDRESS not set). See [SetupBUIDLUsdsUsdcBasin post-deploy configuration](#setupbuidlusdsusdcbasin-post-deploy-configuration) for full details.
    - Ownership, roles, privilege callers:
        - `OWNER_ROLE` (`DEFAULT_ADMIN_ROLE`): `0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34` (BUIDL Admin TimelockController)
        - `MANAGER_ADMIN_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy) + `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
        - `MANAGER_ROLE`: `0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f` (ALM Relayer)
        - `PAUSER_ROLE`: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
        - `REDEEMER_ROLE`: None (pending Securitize redeemer address)
        - `REDEEMER_CONTRACT_ROLE`: None (pending BUIDLTokenRedeemer deployment)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
        forge script script/SetupBUIDLUsdsUsdcBasin.s.sol:SetupBUIDLUsdsUsdcBasin \
            --rpc-url mainnet \
            --account grove-basin-deployer \
            --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
            --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x10b3d3A96646720f8B3a29229cF96d513f3C84F1#code)
    - The deployer no longer has a privileged role: TODO — deployer to give up `MANAGER_ADMIN_ROLE` after redeemer address, redemption vault address, and test admin transaction from Securitize.

11. **BUIDL UsdsUsdcPocket**
    - Chain name: Ethereum Mainnet
    - Contract address: [0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA](https://etherscan.io/address/0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA)
    - Deployment transaction trace: [0xc6f0e579c7636321f4b27c4ec2f701e9afd6ce01488c111de66f932c5eaf8b5c](https://etherscan.io/tx/0xc6f0e579c7636321f4b27c4ec2f701e9afd6ce01488c111de66f932c5eaf8b5c)
    - Code verification
        - Source code URL (at the audited commit hash): [src/pockets/UsdsUsdcPocket.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/pockets/UsdsUsdcPocket.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode 0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA src/pockets/UsdsUsdcPocket.sol:UsdsUsdcPocket --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" 0x10b3d3A96646720f8B3a29229cF96d513f3C84F1 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0xdC035D45d973E3EC169d2276DDab16f1e407384F 0xA188EEC8F81263234dA3622A406892F3D630f98c 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba)`
        - Compilation optimizations match optimizer=true, runs=180, source solc 0.8.24.
        - Constructor arguments:
            1. `basin_`
                - Argument value: `0x10b3d3A96646720f8B3a29229cF96d513f3C84F1` (BUIDL GroveBasin)
                - External source: Pre-deployed contract #10 (BUIDL GroveBasin), deployed in step 2 of SetupBUIDLUsdsUsdcBasin
            2. `usdc_`
                - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
                - External source: grove-address-registry `Ethereum.USDC`
            3. `usds_`
                - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
                - External source: grove-address-registry `Ethereum.USDS`
            4. `psm_`
                - Argument value: `0xA188EEC8F81263234dA3622A406892F3D630f98c` (USDS PSM Wrapper)
                - External source: Script constant `USDS_PSM_WRAPPER`
            5. `groveProxy_`
                - Argument value: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
                - External source: grove-address-registry `Ethereum.GROVE_PROXY`
    - Additional parameters configured on the contract by a privileged actor: None — UsdsUsdcPocket is immutable. Constructor grants max USDS approval to basin and Grove Proxy.
    - Ownership, roles, privilege callers: None — no access control. Callable by GroveBasin (via `MANAGER_ROLE`) and Grove Proxy.
    - Deployment command: Deployed within `SetupBUIDLUsdsUsdcBasin` script (see item 10).
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0x621727A05db6AeB33118b3F9DE3EAf2d8Fc86aDA#code)
    - The deployer no longer has a privileged role: N/A — no access control.

## Pre-configurations

### BUIDL Basin TimelockController

1. **Deploy TimelockController**
    - Transaction trace URL: [0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8](https://etherscan.io/tx/0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8)
    - Contract being deployed: `TimelockController` (OpenZeppelin)
    - Constructor arguments:
        1. `minDelay`
            - Argument value: `604800` (7 days)
            - External source: Script constant `MIN_DELAY`
        2. `proposers`
            - Argument value: `[0x6D99f476E7E9FCcd189fb87023cFa301364Fa817]` (deployer — temporary, to be replaced with Securitize owner address)
            - External source: Script argument
        3. `executors`
            - Argument value: `[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]` (Grove Proxy)
            - External source: grove-address-registry `Ethereum.GROVE_PROXY`
        4. `admin`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

2. **Grant CANCELLER_ROLE to ALM Freezer**
    - Transaction trace URL: [0x211e0cab507ef6affbe69283e0270ffd41e84906fa6a347ac43b5889122d64e3](https://etherscan.io/tx/0x211e0cab507ef6affbe69283e0270ffd41e84906fa6a347ac43b5889122d64e3)
    - Contract being called: TimelockController (newly deployed)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
            - External source: grove-address-registry `Ethereum.ALM_FREEZER`
    - Note: The constructor also grants `CANCELLER_ROLE` to the proposer by default.

3. **Issuer to propose a test transaction (sending 1 wei of ETH)**
    - Transaction trace URL: TODO
    - Contract being called: TimelockController
    - Function being called: `schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)`
    - Function arguments:
        1. `target` - TimelockController address (self)
        2. `value` - `1` (1 wei)
        3. `data` - `0x` (empty calldata)
        4. `predecessor` - `bytes32(0)`
        5. `salt` - `bytes32(0)`
        6. `delay` - `604800` (7 days)
    - Who will perform this action: Issuer (proposer)

4. **Grove to simulate executing the test transaction with Grove Proxy on Tenderly**
    - Transaction trace URL: TODO - Tenderly simulation link
    - Contract being called: TimelockController
    - Function being called: `execute(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt)`
    - Function arguments: Same target/value/data/predecessor/salt as step 3
    - Who will perform this action: Grove (via Grove Proxy `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`)
    - Note: This is a Tenderly simulation only, not an on-chain execution. Verifies the executor role is correctly configured.

5. **Grove to cancel the test transaction with the freezer multisig**
    - Transaction trace URL: TODO
    - Contract being called: TimelockController
    - Function being called: `cancel(bytes32 id)`
    - Function arguments:
        1. `id` - operation hash from the `schedule` call in step 3
    - Who will perform this action: Grove (via ALM Freezer `0xB0113804960345fd0a245788b3423319c86940e5`)
    - Note: Verifies the CANCELLER_ROLE is correctly configured for the freezer multisig.

### JTRSY Basin TimelockController

1. **Deploy TimelockController**
    - Transaction trace URL: [0xec51cda57fcb7698dbc3fb9a7da1bd8eb0fca506332700546a311ffd3b265b9d](https://etherscan.io/tx/0xec51cda57fcb7698dbc3fb9a7da1bd8eb0fca506332700546a311ffd3b265b9d)
    - Contract being deployed: `TimelockController` (OpenZeppelin)
    - Constructor arguments:
        1. `minDelay`
            - Argument value: `604800` (7 days)
            - External source: Script constant `MIN_DELAY`
        2. `proposers`
            - Argument value: `[0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c]`
            - External source: Script argument
        3. `executors`
            - Argument value: `[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]` (Grove Proxy)
            - External source: grove-address-registry `Ethereum.GROVE_PROXY`
        4. `admin`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

2. **Grant CANCELLER_ROLE to ALM Freezer**
    - Transaction trace URL: [0x69e236ea1ad036bea9775e735768f63d311d1ec45ff75933c1fbc0a55d9a472f](https://etherscan.io/tx/0x69e236ea1ad036bea9775e735768f63d311d1ec45ff75933c1fbc0a55d9a472f)
    - Contract being called: TimelockController (newly deployed)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
            - External source: grove-address-registry `Ethereum.ALM_FREEZER`
    - Note: The constructor also grants `CANCELLER_ROLE` to the proposer by default.

3. **Issuer to propose a test transaction (sending 1 wei of ETH)**
    - Transaction trace URL: TODO
    - Contract being called: TimelockController
    - Function being called: `schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)`
    - Function arguments:
        1. `target` - TimelockController address (self)
        2. `value` - `1` (1 wei)
        3. `data` - `0x` (empty calldata)
        4. `predecessor` - `bytes32(0)`
        5. `salt` - `bytes32(0)`
        6. `delay` - `604800` (7 days)
    - Who will perform this action: Issuer (proposer)

4. **Grove to simulate executing the test transaction with Grove Proxy on Tenderly**
    - Transaction trace URL: TODO - Tenderly simulation link
    - Contract being called: TimelockController
    - Function being called: `execute(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt)`
    - Function arguments: Same target/value/data/predecessor/salt as step 3
    - Who will perform this action: Grove (via Grove Proxy `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`)
    - Note: This is a Tenderly simulation only, not an on-chain execution. Verifies the executor role is correctly configured.

5. **Grove to cancel the test transaction with the freezer multisig**
    - Transaction trace URL: TODO
    - Contract being called: TimelockController
    - Function being called: `cancel(bytes32 id)`
    - Function arguments:
        1. `id` - operation hash from the `schedule` call in step 3
    - Who will perform this action: Grove (via ALM Freezer `0xB0113804960345fd0a245788b3423319c86940e5`)
    - Note: Verifies the CANCELLER_ROLE is correctly configured for the freezer multisig.

### SetupBUIDLUsdsUsdcBasin post-deploy configuration

1. **Approve GroveBasinFactory to spend 1 USDS (seed amount)**
    - Transaction trace URL: [0xda07b81643dc8949cdc7b5584807f23a0eb7a2a7378d90313e5d04efcb6b98d3](https://etherscan.io/tx/0xda07b81643dc8949cdc7b5584807f23a0eb7a2a7378d90313e5d04efcb6b98d3)
    - Contract being called: USDS (`0xdC035D45d973E3EC169d2276DDab16f1e407384F`)
    - Function being called: `approve(address spender, uint256 amount)`
    - Function arguments:
        1. `spender`
            - Argument value: `0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a` (GroveBasinFactory)
            - External source: Script constant `GROVE_BASIN_FACTORY`
        2. `amount`
            - Argument value: `1e18` (1 USDS)
            - External source: `10 ** IERC20(USDS).decimals()`

2. **Deploy GroveBasin via GroveBasinFactory**
    - Transaction trace URL: [0x4c39479656f2293361acb059d467cffd3b11f1346dfc52e99bd2a161521775e8](https://etherscan.io/tx/0x4c39479656f2293361acb059d467cffd3b11f1346dfc52e99bd2a161521775e8)
    - Contract being called: GroveBasinFactory (`0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
    - Function being called: `deploy(address owner, address liquidityProvider, address swapToken, address collateralToken, address creditToken, address swapTokenRateProvider, address collateralTokenRateProvider, address creditTokenRateProvider)`
    - Function arguments:
        1. `owner`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA
        2. `liquidityProvider`
            - Argument value: `0x491EDFB0B8b608044e227225C715981a30F3A44E` (ALM Proxy)
            - External source: grove-address-registry `Ethereum.ALM_PROXY`
        3. `swapToken`
            - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
            - External source: grove-address-registry `Ethereum.USDS`
        4. `collateralToken`
            - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
            - External source: grove-address-registry `Ethereum.USDC`
        5. `creditToken`
            - Argument value: `0x7712c34205737192402172409a8F7ccef8aA2AEc` (BUIDL)
            - External source: Script constant `BUIDL_TOKEN`
        6. `swapTokenRateProvider`
            - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (Fixed 1:1 ChronicleRateProvider for USDS/USDC)
            - External source: Script constant `USDS_USDC_FIXED_RATE_PROVIDER`
        7. `collateralTokenRateProvider`
            - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (same as swapTokenRateProvider)
            - External source: Script constant `USDS_USDC_FIXED_RATE_PROVIDER`
        8. `creditTokenRateProvider`
            - Argument value: `0x69a171853575FFD41574EA80Abfc6337AcbC4d43` (BUIDL ChronicleRateProvider)
            - External source: Script constant `BUIDL_CHRONICLE_RATE_PROVIDER`
    - Note: Factory internally seeds 1 USDS to `address(0)` as dead shares via `depositInitial`.

3. **Grant MANAGER_ADMIN_ROLE to Grove Proxy**
    - Transaction trace URL: [0x99b6fd7702e92f8d5acd168aeb405a11567e9edab819be42b61ec1c344b4c9fa](https://etherscan.io/tx/0x99b6fd7702e92f8d5acd168aeb405a11567e9edab819be42b61ec1c344b4c9fa)
    - Contract being called: GroveBasin (newly deployed)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ADMIN_ROLE` = `keccak256("MANAGER_ADMIN_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
            - External source: grove-address-registry `Ethereum.GROVE_PROXY`

4. **Grant MANAGER_ADMIN_ROLE to deployer**
    - Transaction trace URL: [0x38c03a33f7603349362169b82f90a506075bb37a80afe868e29ac91b3ba04b89](https://etherscan.io/tx/0x38c03a33f7603349362169b82f90a506075bb37a80afe868e29ac91b3ba04b89)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ADMIN_ROLE` = `keccak256("MANAGER_ADMIN_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

5. **Deploy UsdsUsdcPocket**
    - Transaction trace URL: [0xc6f0e579c7636321f4b27c4ec2f701e9afd6ce01488c111de66f932c5eaf8b5c](https://etherscan.io/tx/0xc6f0e579c7636321f4b27c4ec2f701e9afd6ce01488c111de66f932c5eaf8b5c)
    - Contract being deployed: `UsdsUsdcPocket`
    - Constructor arguments:
        1. `basin_`
            - Argument value: GroveBasin address (deployed in step 2)
        2. `usdc_`
            - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
            - External source: grove-address-registry `Ethereum.USDC`
        3. `usds_`
            - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
            - External source: grove-address-registry `Ethereum.USDS`
        4. `psm_`
            - Argument value: `0xA188EEC8F81263234dA3622A406892F3D630f98c` (USDS PSM Wrapper)
            - External source: Script constant `USDS_PSM_WRAPPER`
        5. `groveProxy_`
            - Argument value: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
            - External source: grove-address-registry `Ethereum.GROVE_PROXY`
    - Note: Constructor grants max USDS approval to basin and Grove Proxy.

6. **Set pocket on GroveBasin**
    - Transaction trace URL: [0x94d4ad13e24e7dd6ee912d8a966d68a432e76a16f10de598847d7e1d4cd3f450](https://etherscan.io/tx/0x94d4ad13e24e7dd6ee912d8a966d68a432e76a16f10de598847d7e1d4cd3f450)
    - Contract being called: GroveBasin
    - Function being called: `setPocket(address newPocket)`
    - Function arguments:
        1. `newPocket`
            - Argument value: UsdsUsdcPocket address (deployed in step 5)
            - External source: Deterministic from deployment

7. **Deploy and add BUIDLTokenRedeemer** _(skipped — BUIDL_REDEMPTION_ADDRESS not set)_
    - Transaction trace URL: N/A
    - Note: Not included in the current deployment. Will be deployed separately once Securitize shares the redemption address.

8. **Grant MANAGER_ROLE to ALM Relayer**
    - Transaction trace URL: [0xc4afd2c3627b74160acdc2e4f25a9c4bea822304a00a218df0b899e5d4eb1739](https://etherscan.io/tx/0xc4afd2c3627b74160acdc2e4f25a9c4bea822304a00a218df0b899e5d4eb1739)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ROLE` = `keccak256("MANAGER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f` (ALM Relayer)
            - External source: grove-address-registry `Ethereum.ALM_RELAYER`

9. **Grant PAUSER_ROLE to ALM Freezer**
    - Transaction trace URL: [0x852e5da8ab758fd1143fd93f2d511e63fcef7a77412b1790ffc93614db63ff27](https://etherscan.io/tx/0x852e5da8ab758fd1143fd93f2d511e63fcef7a77412b1790ffc93614db63ff27)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
            - External source: grove-address-registry `Ethereum.ALM_FREEZER`

10. **Grant REDEEMER_ROLE** _(skipped — SECURITIZE_REDEEMER_ADDRESS not set)_
    - Transaction trace URL: N/A
    - Note: Not included in the current deployment. Will be granted separately once Securitize shares the redeemer address.

11. **Grant PAUSER_ROLE to deployer (temporary)**
    - Transaction trace URL: [0x3168f24a1804b3dbb14506b8cf32b01a185b81078e37e6edf30f71d103e49515](https://etherscan.io/tx/0x3168f24a1804b3dbb14506b8cf32b01a185b81078e37e6edf30f71d103e49515)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA
    - Note: Temporary grant to allow the deployer to call `setPaused` in steps 12--15. Revoked in step 17.

12. **Pause SWAP_SWAP_TO_CREDIT**
    - Transaction trace URL: [0x72861d77034bda9b5e29fe84fe6892fec36e201317651aa2c00867702ddbebef](https://etherscan.io/tx/0x72861d77034bda9b5e29fe84fe6892fec36e201317651aa2c00867702ddbebef)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_SWAP_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_SWAP_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

13. **Pause SWAP_COLLATERAL_TO_CREDIT**
    - Transaction trace URL: [0x5a783b6aa377d7cae4f4b3b01517407967709d48de3bc6cc336895f4eda785f7](https://etherscan.io/tx/0x5a783b6aa377d7cae4f4b3b01517407967709d48de3bc6cc336895f4eda785f7)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_COLLATERAL_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_COLLATERAL_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

14. **Pause DEPOSIT_CREDIT**
    - Transaction trace URL: [0xaaf15b5dc577fa5d99abeb4d89bd408aa559aa841149077fc5a33e4989581ae7](https://etherscan.io/tx/0xaaf15b5dc577fa5d99abeb4d89bd408aa559aa841149077fc5a33e4989581ae7)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_DEPOSIT_CREDIT` = `bytes4(keccak256("PAUSED_DEPOSIT_CREDIT"))`
            - External source: GroveBasin.sol constant

15. **Pause WITHDRAW_CREDIT**
    - Transaction trace URL: [0xa1f8a81c2d7bc635bb0bbd8b455f093af022d9ecb8fd0f93f6d994d5b12240ce](https://etherscan.io/tx/0xa1f8a81c2d7bc635bb0bbd8b455f093af022d9ecb8fd0f93f6d994d5b12240ce)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_WITHDRAW_CREDIT` = `bytes4(keccak256("PAUSED_WITHDRAW_CREDIT"))`
            - External source: GroveBasin.sol constant

16. **Set fee bounds to [0, 500] bps (0% to 5%)**
    - Transaction trace URL: [0x3d8de864e93b9bc11c295f6c9f04e8f6016bf31343139c32cd0807cd984eb81d](https://etherscan.io/tx/0x3d8de864e93b9bc11c295f6c9f04e8f6016bf31343139c32cd0807cd984eb81d)
    - Contract being called: GroveBasin
    - Function being called: `setFeeBounds(uint256 newMinFee, uint256 newMaxFee)`
    - Function arguments:
        1. `newMinFee`
            - Argument value: `0`
            - External source: Script hardcoded value
        2. `newMaxFee`
            - Argument value: `500` (5% in BPS)
            - External source: Script hardcoded value

17. **Revoke deployer PAUSER_ROLE**
    - Transaction trace URL: [0x9d6f71de497bcca04853fcacc995226d59a2cfacdf94159c0cf64597a0064b99](https://etherscan.io/tx/0x9d6f71de497bcca04853fcacc995226d59a2cfacdf94159c0cf64597a0064b99)
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

18. **Grant OWNER_ROLE to BUIDL Admin TimelockController**
    - Transaction trace URL: [0x04db0842f877a05936c2e50b247dd6830dc0c4a04d25b7f6674f32377edd0c0b](https://etherscan.io/tx/0x04db0842f877a05936c2e50b247dd6830dc0c4a04d25b7f6674f32377edd0c0b)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `OWNER_ROLE` = `DEFAULT_ADMIN_ROLE` = `bytes32(0)`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34` (BUIDL Admin TimelockController)
            - External source: Script constant `BUIDL_ADMIN_TIMELOCK`

19. **Revoke deployer OWNER_ROLE**
    - Transaction trace URL: [0x03327e82537885cf6632aff4c2587b9afc12b087fb1f2ee723e2444ed4e18911](https://etherscan.io/tx/0x03327e82537885cf6632aff4c2587b9afc12b087fb1f2ee723e2444ed4e18911)
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `OWNER_ROLE` = `DEFAULT_ADMIN_ROLE` = `bytes32(0)`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

### SetupJTRSYUsdsUsdcBasin post-deploy configuration

1. **Approve GroveBasinFactory to spend 1 USDS (seed amount)**
    - Transaction trace URL: [0x05da550286223c26f06c8a58249b753ce11a9d69051f388283ccc9ad761e844d](https://etherscan.io/tx/0x05da550286223c26f06c8a58249b753ce11a9d69051f388283ccc9ad761e844d)
    - Contract being called: USDS (`0xdC035D45d973E3EC169d2276DDab16f1e407384F`)
    - Function being called: `approve(address spender, uint256 amount)`
    - Function arguments:
        1. `spender`
            - Argument value: `0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a` (GroveBasinFactory)
            - External source: Script constant `GROVE_BASIN_FACTORY`
        2. `amount`
            - Argument value: `1e18` (1 USDS)
            - External source: `10 ** IERC20(USDS).decimals()`

2. **Deploy GroveBasin via GroveBasinFactory**
    - Transaction trace URL: [0x7d3a7d8b0e3f06bd945482ee9d10bbd8c8f0dc2524736edc81d3ed99f94f0b82](https://etherscan.io/tx/0x7d3a7d8b0e3f06bd945482ee9d10bbd8c8f0dc2524736edc81d3ed99f94f0b82)
    - Contract being called: GroveBasinFactory (`0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
    - Function being called: `deploy(address owner, address liquidityProvider, address swapToken, address collateralToken, address creditToken, address swapTokenRateProvider, address collateralTokenRateProvider, address creditTokenRateProvider)`
    - Function arguments:
        1. `owner`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA
        2. `liquidityProvider`
            - Argument value: `0x491EDFB0B8b608044e227225C715981a30F3A44E` (ALM Proxy)
            - External source: grove-address-registry `Ethereum.ALM_PROXY`
        3. `swapToken`
            - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
            - External source: grove-address-registry `Ethereum.USDS`
        4. `collateralToken`
            - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
            - External source: grove-address-registry `Ethereum.USDC`
        5. `creditToken`
            - Argument value: `0x8c213ee79581Ff4984583C6a801e5263418C4b86` (JTRSY)
            - External source: Script constant `JTRSY_TOKEN`
        6. `swapTokenRateProvider`
            - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (Fixed 1:1 ChronicleRateProvider for USDS/USDC)
            - External source: Script constant `USDS_USDC_FIXED_RATE_PROVIDER`
        7. `collateralTokenRateProvider`
            - Argument value: `0x7928A185B8137D1CD2a0996a810A04dB2837419D` (same as swapTokenRateProvider)
            - External source: Script constant `USDS_USDC_FIXED_RATE_PROVIDER`
        8. `creditTokenRateProvider`
            - Argument value: `0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5` (JTRSY ChronicleRateProvider)
            - External source: Script constant `JTRSY_CHRONICLE_RATE_PROVIDER`
    - Note: Factory internally seeds 1 USDS to `address(0)` as dead shares via `depositInitial`.

3. **Grant MANAGER_ADMIN_ROLE to Grove Proxy**
    - Transaction trace URL: [0xb24ed0117b8f334a0e8ada430002a87219db8b583a1ee188d60744dd6ec5ce5c](https://etherscan.io/tx/0xb24ed0117b8f334a0e8ada430002a87219db8b583a1ee188d60744dd6ec5ce5c)
    - Contract being called: GroveBasin (newly deployed)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ADMIN_ROLE` = `keccak256("MANAGER_ADMIN_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
            - External source: grove-address-registry `Ethereum.GROVE_PROXY`

4. **Grant MANAGER_ADMIN_ROLE to deployer**
    - Transaction trace URL: [0x807577f9bf0c4f2907fa688cd11c472a99e8c66c2af36e798acc4712b96d39f3](https://etherscan.io/tx/0x807577f9bf0c4f2907fa688cd11c472a99e8c66c2af36e798acc4712b96d39f3)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ADMIN_ROLE` = `keccak256("MANAGER_ADMIN_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

5. **Deploy UsdsUsdcPocket**
    - Transaction trace URL: [0x64604be1965dda0a8b72745206d43630fc0a7f8e598d40d75d0a183f420def81](https://etherscan.io/tx/0x64604be1965dda0a8b72745206d43630fc0a7f8e598d40d75d0a183f420def81)
    - Contract being deployed: `UsdsUsdcPocket`
    - Constructor arguments:
        1. `basin_`
            - Argument value: GroveBasin address (deployed in step 2)
        2. `usdc_`
            - Argument value: `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` (USDC)
            - External source: grove-address-registry `Ethereum.USDC`
        3. `usds_`
            - Argument value: `0xdC035D45d973E3EC169d2276DDab16f1e407384F` (USDS)
            - External source: grove-address-registry `Ethereum.USDS`
        4. `psm_`
            - Argument value: `0xA188EEC8F81263234dA3622A406892F3D630f98c` (USDS PSM Wrapper)
            - External source: Script constant `USDS_PSM_WRAPPER`
        5. `groveProxy_`
            - Argument value: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
            - External source: grove-address-registry `Ethereum.GROVE_PROXY`
    - Note: Constructor grants max USDS approval to basin and Grove Proxy.

6. **Set pocket on GroveBasin**
    - Transaction trace URL: [0x5dbd4ead55333e3189d75e9be52f3292b5d964ace4a57db6108ed3ed927febd2](https://etherscan.io/tx/0x5dbd4ead55333e3189d75e9be52f3292b5d964ace4a57db6108ed3ed927febd2)
    - Contract being called: GroveBasin
    - Function being called: `setPocket(address newPocket)`
    - Function arguments:
        1. `newPocket`
            - Argument value: UsdsUsdcPocket address (deployed in step 5)
            - External source: Deterministic from deployment

7. **Deploy JTRSYTokenRedeemer**
    - Transaction trace URL: [0x2386be7468d4c752f78d92d6f9435af778e8d1e92d8b93c85e9ed3891a562b82](https://etherscan.io/tx/0x2386be7468d4c752f78d92d6f9435af778e8d1e92d8b93c85e9ed3891a562b82)
    - Contract being deployed: `JTRSYTokenRedeemer`
    - Constructor arguments:
        1. `creditToken_`
            - Argument value: `0x8c213ee79581Ff4984583C6a801e5263418C4b86` (JTRSY)
            - External source: Script constant `JTRSY_TOKEN`
        2. `vault_`
            - Argument value: `0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A` (Centrifuge JTRSY vault)
            - External source: grove-address-registry `Ethereum.CENTRIFUGE_JTRSY`
        3. `basin_`
            - Argument value: GroveBasin address (deployed in step 2)

8. **Register JTRSYTokenRedeemer on GroveBasin**
    - Transaction trace URL: [0x741c44317437e17018ca9e7faf2e8a3860126719245225f175e41e3b1155a86f](https://etherscan.io/tx/0x741c44317437e17018ca9e7faf2e8a3860126719245225f175e41e3b1155a86f)
    - Contract being called: GroveBasin
    - Function being called: `addTokenRedeemer(address redeemer)`
    - Function arguments:
        1. `redeemer`
            - Argument value: JTRSYTokenRedeemer address (deployed in step 7)
            - External source: Deterministic from deployment
    - Note: This grants `REDEEMER_CONTRACT_ROLE` to the redeemer and calls `setUp()` on it.

9. **Grant MANAGER_ROLE to ALM Relayer**
    - Transaction trace URL: [0x61e948691b5e4ad03c4c6919792d51051d9bc28948c10404edb6a80ae32e282c](https://etherscan.io/tx/0x61e948691b5e4ad03c4c6919792d51051d9bc28948c10404edb6a80ae32e282c)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ROLE` = `keccak256("MANAGER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f` (ALM Relayer)
            - External source: grove-address-registry `Ethereum.ALM_RELAYER`

10. **Grant PAUSER_ROLE to ALM Freezer**
    - Transaction trace URL: [0x389bd400f5d99fdafc6b818ecd4ad8658ff14b8e5e287da6482f6b39cb2e8673](https://etherscan.io/tx/0x389bd400f5d99fdafc6b818ecd4ad8658ff14b8e5e287da6482f6b39cb2e8673)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
            - External source: grove-address-registry `Ethereum.ALM_FREEZER`

11. **Grant REDEEMER_ROLE**
    - Transaction trace URL: [0xde757885f0f0f005e02121275ff5849b1efbcfe236af7e2e927fadab3a57c129](https://etherscan.io/tx/0xde757885f0f0f005e02121275ff5849b1efbcfe236af7e2e927fadab3a57c129)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `REDEEMER_ROLE` = `keccak256("REDEEMER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a`
            - External source: Hardcoded in script

12. **Grant PAUSER_ROLE to deployer (temporary)**
    - Transaction trace URL: [0xbff160f4246731b72df39a4b61ab903e20024e3b32a248070f2d72f804aea385](https://etherscan.io/tx/0xbff160f4246731b72df39a4b61ab903e20024e3b32a248070f2d72f804aea385)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA
    - Note: Temporary grant to allow the deployer to call `setPaused` in steps 13--16. Revoked in step 18.

13. **Pause SWAP_SWAP_TO_CREDIT**
    - Transaction trace URL: [0x3f318fdff79bf42a85ed786dd9a4c32d10b1670fd9d9ca0d1903550b3f81ea89](https://etherscan.io/tx/0x3f318fdff79bf42a85ed786dd9a4c32d10b1670fd9d9ca0d1903550b3f81ea89)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_SWAP_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_SWAP_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

14. **Pause SWAP_COLLATERAL_TO_CREDIT**
    - Transaction trace URL: [0x764052528bbb8620b5ec31f529972f22b9f519dd98bd1c227c985166a4d02e11](https://etherscan.io/tx/0x764052528bbb8620b5ec31f529972f22b9f519dd98bd1c227c985166a4d02e11)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_COLLATERAL_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_COLLATERAL_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

15. **Pause DEPOSIT_CREDIT**
    - Transaction trace URL: [0x02e281a8ac7c37df904b44aa0912f20e27378165fc22267f75ac781456a9295c](https://etherscan.io/tx/0x02e281a8ac7c37df904b44aa0912f20e27378165fc22267f75ac781456a9295c)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_DEPOSIT_CREDIT` = `bytes4(keccak256("PAUSED_DEPOSIT_CREDIT"))`
            - External source: GroveBasin.sol constant

16. **Pause WITHDRAW_CREDIT**
    - Transaction trace URL: [0xe580e3f4e0807d84f2f9904f56d1c3a745526c33adb9dce2eaefe1ef5c7ce68a](https://etherscan.io/tx/0xe580e3f4e0807d84f2f9904f56d1c3a745526c33adb9dce2eaefe1ef5c7ce68a)
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_WITHDRAW_CREDIT` = `bytes4(keccak256("PAUSED_WITHDRAW_CREDIT"))`
            - External source: GroveBasin.sol constant

17. **Set fee bounds to [0, 500] bps (0% to 5%)**
    - Transaction trace URL: [0xa2b18aadd6b73cdade768ca7eb97774faeced3dc2bf2e3b61e06f5a00217eb96](https://etherscan.io/tx/0xa2b18aadd6b73cdade768ca7eb97774faeced3dc2bf2e3b61e06f5a00217eb96)
    - Contract being called: GroveBasin
    - Function being called: `setFeeBounds(uint256 newMinFee, uint256 newMaxFee)`
    - Function arguments:
        1. `newMinFee`
            - Argument value: `0`
            - External source: Script hardcoded value
        2. `newMaxFee`
            - Argument value: `500` (5% in BPS)
            - External source: Script hardcoded value

18. **Revoke deployer PAUSER_ROLE**
    - Transaction trace URL: [0x65991011467870dece52b7a1279c37e46cb73a076f9648dd1c0dd44e7bfc72c8](https://etherscan.io/tx/0x65991011467870dece52b7a1279c37e46cb73a076f9648dd1c0dd44e7bfc72c8)
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

19. **Grant OWNER_ROLE to JTRSY Admin TimelockController**
    - Transaction trace URL: [0xa43f67df69d677abc0623a2d385998b69f3c72b935c176bcd41975d1d6b1f2dc](https://etherscan.io/tx/0xa43f67df69d677abc0623a2d385998b69f3c72b935c176bcd41975d1d6b1f2dc)
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `OWNER_ROLE` = `DEFAULT_ADMIN_ROLE` = `bytes32(0)`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xA52dC9876aB4A9DB6dAfbb83410554086054d140` (JTRSY Admin TimelockController)
            - External source: Script constant `JTRSY_ADMIN_TIMELOCK`

20. **Revoke deployer OWNER_ROLE**
    - Transaction trace URL: [0x08bd1f13395e4e222a71a343af837e54313ba1477aa7c73732e22f09c90dd03f](https://etherscan.io/tx/0x08bd1f13395e4e222a71a343af837e54313ba1477aa7c73732e22f09c90dd03f)
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `OWNER_ROLE` = `DEFAULT_ADMIN_ROLE` = `bytes32(0)`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: deployer address (from `DEPLOYER` env var)
            - External source: Deployer EOA

## Pre-requirements

### BUIDL ChronicleRateProvider

1. **Chronicle to add BUIDL ChronicleRateProvider to oracle allowlist**
    - Intended end goal: `0x69a171853575FFD41574EA80Abfc6337AcbC4d43` (BUIDL ChronicleRateProvider) must be allowlisted on the Chronicle BUIDL/USD oracle (`0x8c68E0CacB61a065b99E2104457aCC829d61cbB0`) via `kiss(address)` so it can call `readWithAge()`.
    - Why is it required to be done in advance: Chronicle oracles use a toll mechanism; un-whitelisted addresses will revert on `readWithAge()`.
    - Proof that it was done or planned to be done: Chronicle called `kiss(address(0))` on the BUIDL/USD oracle, opening the toll to BUIDL ChronicleRateProvider. Transaction: [0xd5451a2bbe5caff73462ce516739c9106c8267c51e070d1083dd7547ffa41a3a](https://etherscan.io/tx/0xd5451a2bbe5caff73462ce516739c9106c8267c51e070d1083dd7547ffa41a3a)

### JTRSY ChronicleRateProvider

1. **Chronicle to add JTRSY ChronicleRateProvider to oracle allowlist**
    - Intended end goal: `0x29209ceCFeFa6f675E6f1f829320D67cE2b025E5` (JTRSY ChronicleRateProvider) must be allowlisted on the Chronicle JTRSY/USD oracle (`0xE980a33EFA3EDDaa689eCbdCE4B2278D4DB94471`) via `kiss(address)` so it can call `readWithAge()`.
    - Why is it required to be done in advance: Chronicle oracles use a toll mechanism; un-whitelisted addresses will revert on `readWithAge()`.
    - Proof that it was done or planned to be done: Chronicle called `kiss(address(0))` on the JTRSY/USD oracle, opening the toll to JTRSY ChronicleRateProvider. Transaction: [0x92c0c642a0fc8b4dc2c801dfe282b80247f5f18c643976cfcaecd3d71cd6f832](https://etherscan.io/tx/0x92c0c642a0fc8b4dc2c801dfe282b80247f5f18c643976cfcaecd3d71cd6f832)

### BUIDL Basin TimelockController

1. **Transfer PROPOSER_ROLE from deployer to Securitize owner address**
    - Intended end goal: The BUIDL Admin TimelockController's `PROPOSER_ROLE` must be transferred from the deployer (temporary initial proposer) to the Securitize owner address. This requires granting `PROPOSER_ROLE` to the Securitize address and revoking it from the deployer.
    - Why is it required to be done in advance: The deployer is set as the initial proposer only as a placeholder. The issuer (Securitize) must hold the proposer role before the system is considered live.
    - Proof that it was done or planned to be done: TODO — transaction granting `PROPOSER_ROLE` to Securitize and revoking from deployer, once Securitize shares their owner address

2. **Deployer to revoke own admin role**
    - Intended end goal: The deployer must call `revokeRole(DEFAULT_ADMIN_ROLE, deployer)` on the BUIDL Basin TimelockController so that no single EOA retains admin privileges. After this, roles can only be managed through the timelock itself.
    - Why is it required to be done in advance: The deployer holds `DEFAULT_ADMIN_ROLE` after deployment, which allows bypassing the timelock delay for role changes. This must be revoked before the system is considered live.
    - Proof that it was done or planned to be done: TODO

### JTRSY Basin TimelockController

1. **Deployer to revoke own admin role**
    - Intended end goal: The deployer must call `revokeRole(DEFAULT_ADMIN_ROLE, deployer)` on the JTRSY Basin TimelockController so that no single EOA retains admin privileges. After this, roles can only be managed through the timelock itself.
    - Why is it required to be done in advance: The deployer holds `DEFAULT_ADMIN_ROLE` after deployment, which allows bypassing the timelock delay for role changes. This must be revoked before the system is considered live.
    - Proof that it was done or planned to be done: TODO

### SetupBUIDLUsdsUsdcBasin

1. **Securitize to share the BUIDL redemption address**
    - Intended end goal: The BUIDL redemption address is required to deploy the `BUIDLTokenRedeemer` contract, which is passed as a constructor argument. Without it, the redeemer cannot be deployed and the basin will not support BUIDL redemptions.
    - Why is it required to be done in advance: The `BUIDLTokenRedeemer` constructor requires the redemption address; the deployment script cannot proceed without it.
    - Proof that it was done or planned to be done: TODO — waiting on Securitize to share the redemption address

2. **Securitize to share a redeemer address for REDEEMER_ROLE**
    - Intended end goal: A valid address to grant the `REDEEMER_ROLE` on the BUIDL GroveBasin. This address will be authorized to trigger redemptions.
    - Why is it required to be done in advance: Currently set to `address(0)` in the script; the conditional skip means no redeemer role holder will be set until the address is provided.
    - Proof that it was done or planned to be done: TODO — waiting on Securitize to share their redeemer address

3. **BUIDL Basin must be allowlisted on BUIDL token**
    - Intended end goal: The BUIDL Basin contract (`0x10b3d3A96646720f8B3a29229cF96d513f3C84F1`) can hold BUIDL tokens
    - Why is it required to be done in advance: BUIDL requires holders to be on an allowlist.
    - Proof that it was done or planned to be done: TODO

### SetupJTRSYUsdsUsdcBasin

1. **JTRSYTokenRedeemer must be allowlisted on Centrifuge vault and JTRSY token**
    - Intended end goal: The redeemer contract can call `requestRedeem` and `redeem` on the Centrifuge vault.
    - Why is it required to be done in advance: The Centrifuge vault requires callers to be on an allowlist.
    - Proof that it was done or planned to be done: TODO

2. **JTRSY Basin must be allowlisted on JTRSY token**
    - Intended end goal: The JTRSY Basin contract can hold JTRSY tokens
    - Why is it required to be done in advance: JTRSY requires holders to be on an allowlist.
    - Proof that it was done or planned to be done: TODO

## Proposed actions



## Post-checks

1. **Verify GroveBasin initialization**
    - What will be done: Read all immutable and state variables on each deployed GroveBasin.
    - How it will be done: Run `test/VerifyDeployment.sol`
    - Expected outcome: All values match script parameters. `totalShares > 0` (seed deposit worked). Paused keys are set as expected. Fee bounds are [0, 500].
    - Who will perform this action: Deployer / reviewer

2. **Verify role assignments**
    - What will be done: Check `hasRole()` for all expected role holders on each basin. Also verifies deployer does not hold privileged roles.
    - How it will be done: Run `test/VerifyDeployment.sol`
    - Expected outcome: All roles correctly assigned. For JTRSY basin: `OWNER_ROLE` held by JTRSY Admin TimelockController (`0xA52dC9876aB4A9DB6dAfbb83410554086054d140`), deployer has NO `OWNER_ROLE`. For BUIDL basin: `OWNER_ROLE` held by BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`), deployer has NO `OWNER_ROLE`. Deployer retains `MANAGER_ADMIN_ROLE` on both basins. Deployer does NOT have `PAUSER_ROLE` (revoked in script for both basins).
    - Who will perform this action: Deployer / reviewer

3. **Verify pocket configuration**
    - What will be done: Check that each basin's pocket is set correctly and holds the expected swap token balance.
    - How it will be done: Run `test/VerifyDeployment.sol`
    - Expected outcome: Pocket addresses match deployed contracts. `basin()` on each pocket returns the correct GroveBasin address.
    - Who will perform this action: Deployer / reviewer

4. **Verify token redeemer configuration**
    - What will be done: Check that each basin has the correct token redeemer registered.
    - How it will be done: Run `test/VerifyDeployment.sol`
    - Expected outcome: Returns true for the deployed redeemer addresses.
    - Who will perform this action: Deployer / reviewer

5. **Verify rate providers return valid rates**
    - What will be done: Call `getConversionRate()` on all rate providers.
    - How it will be done: Run `test/VerifyDeployment.sol`
    - Expected outcome: All return non-zero values. ChronicleRateProviders return rates that are not stale (within stalenessThreshold).
    - Who will perform this action: Deployer / reviewer

6. **Test swap transaction**
    - What will be done: Perform a small test swap on each basin to confirm end-to-end functionality.
    - How it will be done: Run `test/VerifyDeployment.sol`
    - Expected outcome: Swap succeeds, expected output amount is received.
    - Who will perform this action: Deployer or designated tester

7. **Verify source code on block explorer**
    - What will be done: Confirm all deployed contracts have verified source code on Etherscan.
    - How it will be done: Check each contract address on etherscan.io for the "Contract" tab showing verified source.
    - Expected outcome: All contracts show verified source matching audited commit.
    - Who will perform this action: Deployer / reviewer


## Research and additional notes

### Deployment script analysis

Two deployment scripts cover all basin configurations:

| Script | Swap Token | Collateral | Credit Token | Pocket Type | Redeemer Type |
|---|---|---|---|---|---|
| `SetupBUIDLUsdsUsdcBasin` | USDS | USDC | BUIDL | UsdsUsdcPocket (PSM) | BUIDLTokenRedeemer (offchain) |
| `SetupJTRSYUsdsUsdcBasin` | USDS | USDC | JTRSY | UsdsUsdcPocket (PSM) | JTRSYTokenRedeemer (ERC-7540) |

### Key architectural notes

- **GroveBasinFactory** uses CREATE2 with salt `keccak256(abi.encode(owner, swapToken, collateralToken, creditToken))` for deterministic addresses.
- **Dead shares**: Factory seeds 1 unit to `address(0)` to prevent share inflation attacks.
- **Pocket pattern**: Swap tokens are custodied in the pocket (not the basin). Basin uses `transferFrom` from the pocket for outgoing swap token transfers.
- **Rate provider precision**: All rates are in 1e27 precision (WAD * 1e9). ChronicleRateProvider scales from Chronicle's 1e18 to 1e27.

### Compiler settings

- Solidity version: 0.8.24
- Optimizer: enabled, 180 runs
- Remappings: `forge-std`, `erc20-helpers`, `openzeppelin-contracts`, `ds-test`

### Open TODOs in scripts

1. `SetupBUIDLUsdsUsdcBasin.s.sol`: BUIDLTokenRedeemer deployment and REDEEMER_ROLE grant deferred — waiting on Securitize to share the redemption address and redeemer address

# General Technical Scope Template

## Trusted addresses

| **Contract name** | **Address with URL** |
|---|---|
| USDS | [0xdC035D45d973E3EC169d2276DDab16f1e407384F](https://etherscan.io/address/0xdC035D45d973E3EC169d2276DDab16f1e407384F) |
| USDC | [0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48](https://etherscan.io/address/0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) |
| BUIDL | [0x7712c34205737192402172409a8F7ccef8aA2AEc](https://etherscan.io/address/0x7712c34205737192402172409a8F7ccef8aA2AEc) |
| JTRSY | [0x8c213ee79581Ff4984583C6a801e5263418C4b86](https://etherscan.io/address/0x8c213ee79581Ff4984583C6a801e5263418C4b86) |
| Centrifuge JTRSY Vault | [0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A](https://etherscan.io/address/0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A) |
| USDS PSM Wrapper | [0xA188EEC8F81263234dA3622A406892F3D630f98c](https://etherscan.io/address/0xA188EEC8F81263234dA3622A406892F3D630f98c) |
| ALM Proxy | [0x491EDFB0B8b608044e227225C715981a30F3A44E](https://etherscan.io/address/0x491EDFB0B8b608044e227225C715981a30F3A44E) |
| ALM Relayer | [0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f](https://etherscan.io/address/0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f) |
| ALM Freezer | [0xB0113804960345fd0a245788b3423319c86940e5](https://etherscan.io/address/0xB0113804960345fd0a245788b3423319c86940e5) |
| Grove Proxy | [0x1369f7b2b38c76B6478c0f0E66D94923421891Ba](https://etherscan.io/address/0x1369f7b2b38c76B6478c0f0E66D94923421891Ba) |
| Chronicle BUIDL/USD Oracle Router | [0x8c68E0CacB61a065b99E2104457aCC829d61cbB0](https://etherscan.io/address/0x8c68E0CacB61a065b99E2104457aCC829d61cbB0) |
| Chronicle JTRSY/USD Oracle Router | [0xE980a33EFA3EDDaa689eCbdCE4B2278D4DB94471](https://etherscan.io/address/0xE980a33EFA3EDDaa689eCbdCE4B2278D4DB94471) |

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
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`QmavWW8CzA2QfPxLGw1YbE2489SJ8YYexoKwQGnXFjj6Nv`, solc=0.8.24.
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
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`QmchhEbJcxoU5HDDea198wCoJUYTKNpaVrPygkaEdQCsaF`, solc=0.8.24.
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
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`Qmc6Mfao8kmpCpktgMNfTrMyJrykDctcsrBkog5ZW2nhPc`, solc=0.8.24.
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
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`Qmc6Mfao8kmpCpktgMNfTrMyJrykDctcsrBkog5ZW2nhPc`, solc=0.8.24.
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
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Constructor arguments:
            1. `minDelay`
                - Argument value: `604800` (7 days)
                - External source: Script constant `MIN_DELAY`
            2. `proposers`
                - Argument value: `[0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c]`
                - External source: JTRSY proposer multisig address (provided by Anemoy)
            3. `executors`
                - Argument value: `[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]` (Grove Proxy)
                - External source: grove-address-registry `Ethereum.GROVE_PROXY`
            4. `admin`
                - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
                - External source: Deployer EOA
    - Additional parameters configured on the contract by a privileged actor: `CANCELLER_ROLE` granted to ALM Freezer (`0xB0113804960345fd0a245788b3423319c86940e5`) in the deployment script.
    - Ownership, roles, privilege callers:
        - `PROPOSER_ROLE`: `0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c` (Anemoy proposer)
        - `EXECUTOR_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
        - `CANCELLER_ROLE`: `0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c` (proposer, via constructor) + `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer, via script)
        - `DEFAULT_ADMIN_ROLE`: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer — to be revoked as pre-requirement)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 forge script script/DeployTimelockController.s.sol:DeployTimelockController --rpc-url mainnet --sig "run(address)" 0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c --account grove-basin-deployer --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0xA52dC9876aB4A9DB6dAfbb83410554086054d140#code)
    - The deployer no longer has a privileged role: `DEFAULT_ADMIN_ROLE` revoked in tx [0x6ec10f73...](https://etherscan.io/tx/0x6ec10f73b0451935de484c233c0d949624debf424e79ff0c53e240f6e129249f).

6. **BUIDL Admin TimelockController**
    - Chain name: Ethereum Mainnet
    - Contract address: [0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34](https://etherscan.io/address/0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34)
    - Library version: [OpenZeppelin Contracts v5.5.0](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/fcbae5394ae8ad52d8e580a3477db99814b9d565)
    - Deployment transaction trace: [0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8](https://etherscan.io/tx/0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8)
    - Code verification
        - Source code URL (at the audited commit hash): [OpenZeppelin `TimelockController`](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/fcbae5394ae8ad52d8e580a3477db99814b9d565/contracts/governance/TimelockController.sol)
        - External URLs to the audit reports: [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/audits/2025-10-v5.5.pdf)
        - Deployed bytecode verification: `forge verify-bytecode 0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34 lib/openzeppelin-contracts/contracts/governance/TimelockController.sol:TimelockController --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(uint256,address[],address[],address)" 604800 "[0x6D99f476E7E9FCcd189fb87023cFa301364Fa817]" "[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]" 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817)`
            - Creation code matched with status `full`. Runtime code matched with status `full`.
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
        - `PROPOSER_ROLE`: ~~`0x551e841e6fb54431a0664C8776784F6d7E611428`~~ → `0x453A28B31fdc31858C35B02bc3A42BCD8bfbAd3a` (Securitize owner address, changed)
        - `EXECUTOR_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy)
        - `CANCELLER_ROLE`: ~~`0x551e841e6fb54431a0664C8776784F6d7E611428`~~ → `0x453A28B31fdc31858C35B02bc3A42BCD8bfbAd3a` (Securitize owner address, changed) + `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer, via script)
        - `DEFAULT_ADMIN_ROLE`: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer — to be revoked as pre-requirement)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 forge script script/DeployTimelockController.s.sol:DeployTimelockController --rpc-url mainnet --sig "run(address)" 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --account grove-basin-deployer --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: [Yes](https://etherscan.io/address/0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34#code)
    - The deployer no longer has a privileged role: TODO — `DEFAULT_ADMIN_ROLE` must be revoked after Securitize provides an owner address and does a test transaction (see pre-requirements).

7. **JTRSY GroveBasin**
    - Chain name: Ethereum Mainnet
    - Contract address: TBD (pending redeployment)
    - Deployment transaction trace: TBD (pending redeployment; will be deployed via `GroveBasinFactory.deploy()` at `0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
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
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: `DEPLOYER` env var in the deployment script. Can be verified by checking the `msg.sender` of the `GroveBasinFactory.deploy()` call in the deployment transaction trace (TBD). Grove to confirm.
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
    - Additional parameters configured on the contract by a privileged actor: Pocket set to TBD (UsdsUsdcPocket, pending redeployment). Token redeemer TBD (JTRSYTokenRedeemer, pending redeployment) registered. Fee bounds set to [0, 500]. Four pause keys enabled (PAUSED_SWAP_SWAP_TO_CREDIT, PAUSED_SWAP_COLLATERAL_TO_CREDIT, PAUSED_DEPOSIT_CREDIT, PAUSED_WITHDRAW_CREDIT). See [SetupJTRSYUsdsUsdcBasin post-deploy configuration](#setupjtrsyusdsusdcbasin-post-deploy-configuration) for full details.
    - Ownership, roles, privilege callers:
        - `OWNER_ROLE` (`DEFAULT_ADMIN_ROLE`): `0xA52dC9876aB4A9DB6dAfbb83410554086054d140` (JTRSY Admin TimelockController)
        - `MANAGER_ADMIN_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy) + `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
        - `MANAGER_ROLE`: `0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f` (ALM Relayer)
        - `PAUSER_ROLE`: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
        - `REDEEMER_ROLE`: `0xb6e8D3E47c4FC5606E6C24D097Dd1791885Ce05a` ()
        - `REDEEMER_CONTRACT_ROLE`: TBD (JTRSYTokenRedeemer, pending redeployment)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
        forge script script/SetupJTRSYUsdsUsdcBasin.s.sol:SetupJTRSYUsdsUsdcBasin \
            --rpc-url mainnet \
            --account grove-basin-deployer \
            --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
            --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: TBD (pending redeployment)
    - The deployer no longer has a privileged role: `MANAGER_ADMIN_ROLE` revoked in tx TBD.

8. **JTRSY UsdsUsdcPocket**
    - Chain name: Ethereum Mainnet
    - Contract address: TBD (pending redeployment)
    - Deployment transaction trace: TBD (pending redeployment)
    - Code verification
        - Source code URL (at the audited commit hash): [src/pockets/UsdsUsdcPocket.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/pockets/UsdsUsdcPocket.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode <TBD: pocket address> src/pockets/UsdsUsdcPocket.sol:UsdsUsdcPocket --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" <TBD: JTRSY GroveBasin address> 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0xdC035D45d973E3EC169d2276DDab16f1e407384F 0xA188EEC8F81263234dA3622A406892F3D630f98c 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba)`
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`QmTUwRpfBkq1ZAwmTjHLW1MTAZTVKypXb1bJpwzrSNzRFu`, solc=0.8.24.
        - Constructor arguments:
            1. `basin_`
                - Argument value: TBD (JTRSY GroveBasin, pending redeployment)
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
    - Source code is verified on the block explorer: TBD (pending redeployment)
    - The deployer no longer has a privileged role: N/A — no access control.

9. **JTRSY JTRSYTokenRedeemer**
    - Chain name: Ethereum Mainnet
    - Contract address: TBD (pending redeployment)
    - Deployment transaction trace: TBD (pending redeployment)
    - Code verification
        - Source code URL (at the audited commit hash): [src/redeemers/JTRSYTokenRedeemer.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/redeemers/JTRSYTokenRedeemer.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode <TBD: redeemer address> src/redeemers/JTRSYTokenRedeemer.sol:JTRSYTokenRedeemer --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address)" 0x8c213ee79581Ff4984583C6a801e5263418C4b86 0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A <TBD: JTRSY GroveBasin address>)`
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`QmTdhLbu1GU2uygH13BLQ9T8QMdD2sr7dZ4ALgAFFcoWWY`, solc=0.8.24.
        - Constructor arguments:
            1. `creditToken_`
                - Argument value: `0x8c213ee79581Ff4984583C6a801e5263418C4b86` (JTRSY)
                - External source: Script constant `JTRSY_TOKEN`
            2. `vault_`
                - Argument value: `0xFE6920eB6C421f1179cA8c8d4170530CDBdfd77A` (Centrifuge JTRSY vault)
                - External source: grove-address-registry `Ethereum.CENTRIFUGE_JTRSY`
            3. `basin_`
                - Argument value: TBD (JTRSY GroveBasin, pending redeployment)
                - External source: Deployed in step 2 of SetupJTRSYUsdsUsdcBasin
    - Additional parameters configured on the contract by a privileged actor: None — JTRSYTokenRedeemer is immutable. Registered on the basin via `addTokenRedeemer()` which grants `REDEEMER_CONTRACT_ROLE` and calls `setUp()`.
    - Ownership, roles, privilege callers: None — no access control. Callable by the GroveBasin contract (`onlyBasin` modifier) and the basin's manager admin (Grove Proxy `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`).
    - Deployment command: Deployed within `SetupJTRSYUsdsUsdcBasin` script (see item 7).
    - Source code is verified on the block explorer: TBD (pending redeployment)
    - The deployer no longer has a privileged role: N/A — no access control.

10. **BUIDL GroveBasin**
    - Chain name: Ethereum Mainnet
    - Contract address: TBD (pending redeployment)
    - Deployment transaction trace: TBD (pending redeployment; will be deployed via `GroveBasinFactory.deploy()` at `0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
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
                - External source of the value or an explanation of how this value can be verified, and who has to confirm it: `DEPLOYER` env var in the deployment script. Can be verified by checking the `msg.sender` of the `GroveBasinFactory.deploy()` call in the deployment transaction trace (TBD). Grove to confirm.
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
    - Additional parameters configured on the contract by a privileged actor: Pocket set to TBD (UsdsUsdcPocket, pending redeployment). Token redeemer TBD (BUIDLTokenRedeemer, pending redeployment) registered. Fee bounds set to [0, 500]. Four pause keys enabled (PAUSED_SWAP_SWAP_TO_CREDIT, PAUSED_SWAP_COLLATERAL_TO_CREDIT, PAUSED_DEPOSIT_CREDIT, PAUSED_WITHDRAW_CREDIT). See [SetupBUIDLUsdsUsdcBasin post-deploy configuration](#setupbuidlusdsusdcbasin-post-deploy-configuration) for full details.
    - Ownership, roles, privilege callers:
        - `OWNER_ROLE` (`DEFAULT_ADMIN_ROLE`): `0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34` (BUIDL Admin TimelockController)
        - `MANAGER_ADMIN_ROLE`: `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba` (Grove Proxy) + `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
        - `MANAGER_ROLE`: `0x0eEC86649E756a23CBc68d9EFEd756f16aD5F85f` (ALM Relayer)
        - `PAUSER_ROLE`: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
        - `REDEEMER_ROLE`: ~~`0xdfC603076EA75895DD4d59c6e2ee5038f881CB74`~~ → `0x488F27168a19472c51f003fbC5b75B1ACc3B7b4c` (Securitize redeemer address, changed)
        - `REDEEMER_CONTRACT_ROLE`: TBD (BUIDLTokenRedeemer, pending redeployment)
    - Deployment command:
        ```
        DEPLOYER=0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
        forge script script/SetupBUIDLUsdsUsdcBasin.s.sol:SetupBUIDLUsdsUsdcBasin \
            --rpc-url mainnet \
            --account grove-basin-deployer \
            --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 \
            --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: TBD (pending redeployment)
    - The deployer no longer has a privileged role: TODO — deployer to give up `MANAGER_ADMIN_ROLE` after redeemer address, redemption vault address, and test admin transaction from Securitize.

11. **BUIDL UsdsUsdcPocket**
    - Chain name: Ethereum Mainnet
    - Contract address: TBD (pending redeployment)
    - Deployment transaction trace: TBD (pending redeployment)
    - Code verification
        - Source code URL (at the audited commit hash): [src/pockets/UsdsUsdcPocket.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/pockets/UsdsUsdcPocket.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode <TBD: pocket address> src/pockets/UsdsUsdcPocket.sol:UsdsUsdcPocket --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" <TBD: BUIDL GroveBasin address> 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0xdC035D45d973E3EC169d2276DDab16f1e407384F 0xA188EEC8F81263234dA3622A406892F3D630f98c 0x1369f7b2b38c76B6478c0f0E66D94923421891Ba)`
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`QmTUwRpfBkq1ZAwmTjHLW1MTAZTVKypXb1bJpwzrSNzRFu`, solc=0.8.24.
        - Constructor arguments:
            1. `basin_`
                - Argument value: TBD (BUIDL GroveBasin, pending redeployment)
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
    - Source code is verified on the block explorer: TBD (pending redeployment)
    - The deployer no longer has a privileged role: N/A — no access control.

9. **BUIDL BUIDLTokenRedeemer (old — superseded by #13)**
    - Chain name: Ethereum Mainnet
    - Contract address: TBD (pending redeployment)
    - Deployment transaction trace: TBD (pending redeployment)
    - **Status**: Superseded. `REDEEMER_CONTRACT_ROLE` must be revoked from this contract. Replaced by #13 due to Securitize redemption vault address change.
    - Code verification
        - Source code URL (at the audited commit hash): [src/redeemers/BUIDLTokenRedeemer.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/redeemers/BUIDLTokenRedeemer.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode <TBD: redeemer address> src/redeemers/BUIDLTokenRedeemer.sol:BUIDLTokenRedeemer --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address)" 0x7712c34205737192402172409a8F7ccef8aA2AEc 0x0d671C15Aa427fFc31C3A484C3ACdd8043F73052 <TBD: BUIDL GroveBasin address>)`
            - Creation code matched with status `full`. Runtime code matched with status `full`.
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`QmQshJETAUWw5CJR4ushQEdSSV5v2kucCqLffY87TjaXDG`, solc=0.8.24.
        - Constructor arguments:
            1. `creditToken_`
                - Argument value: `0x7712c34205737192402172409a8F7ccef8aA2AEc` (BUIDL)
                - External source: Script constant `BUIDL_TOKEN`
            2. `redemptionAddress_`
                - Argument value: `0x0d671C15Aa427fFc31C3A484C3ACdd8043F73052` (old Securitize redemption address)
                - External source: Provided by Securitize (BUIDL primary redemption address)
            3. `basin_`
                - Argument value: TBD (BUIDL GroveBasin, pending redeployment)
                - External source: Pre-deployed contract #10 (BUIDL GroveBasin), deployed in step 2 of SetupBUIDLUsdsUsdcBasin
    - Additional parameters configured on the contract by a privileged actor: None — BUIDLTokenRedeemer is immutable. Registered on the basin via `addTokenRedeemer()` which grants `REDEEMER_CONTRACT_ROLE` and calls `setUp()`.
    - Ownership, roles, privilege callers: None — no access control. Callable by the GroveBasin contract (`onlyBasin` modifier) and the basin's manager admin (Grove Proxy `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`).
    - Deployment command:
        ```
        forge script script/SetupBUIDLUsdsUsdcBasin.s.sol:SetupBUIDLUsdsUsdcBasin \
            --sig "deployRedeemerContractAndGrantRedeemerRole(address)" <TBD: BUIDL GroveBasin address> \
            --rpc-url mainnet \
            --account grove-basin-deployer \
            --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: TBD (pending redeployment)
    - The deployer no longer has a privileged role: N/A — no access control.

13. **BUIDL BUIDLTokenRedeemer (current — replaces #9)**
    - Chain name: Ethereum Mainnet
    - Contract address: TBD (pending redeployment)
    - Deployment transaction trace: TBD (pending redeployment)
    - Code verification
        - Source code URL (at the audited commit hash): [src/redeemers/BUIDLTokenRedeemer.sol](https://github.com/grove-labs/grove-basin/blob/a79269a3f5f0253110e9cbca15d79aa9ffb62c4d/src/redeemers/BUIDLTokenRedeemer.sol)
        - External URLs to the audit reports: 
            - Cantina audit: https://cantina.xyz/portfolio/71794706-b078-4579-8f50-a9bd25d732d3
            - Chain Security Audit: https://reports.chainsecurity.com/GroveLabs/ChainSecurity_GroveLabs_Basin_Audit.pdf
        - Deployed bytecode verification: `forge verify-bytecode <TBD: redeemer address> src/redeemers/BUIDLTokenRedeemer.sol:BUIDLTokenRedeemer --rpc-url mainnet --encoded-constructor-args $(cast abi-encode "constructor(address,address,address)" 0x7712c34205737192402172409a8F7ccef8aA2AEc 0x8780Dd016171B91E4Df47075dA0a947959C34200 <TBD: BUIDL GroveBasin address>)`
        - Compilation optimizations match optimizer=true, runs=180, evm_version=cancun, source solc 0.8.24. Bytecode CBOR metadata: bytecodeHash=ipfs, IPFS CID=`QmQshJETAUWw5CJR4ushQEdSSV5v2kucCqLffY87TjaXDG`, solc=0.8.24.
        - Constructor arguments:
            1. `creditToken_`
                - Argument value: `0x7712c34205737192402172409a8F7ccef8aA2AEc` (BUIDL)
                - External source: Script constant `BUIDL_TOKEN`
            2. `redemptionAddress_`
                - Argument value: `0x8780Dd016171B91E4Df47075dA0a947959C34200` (new Securitize redemption address)
                - External source: Provided by Securitize
            3. `basin_`
                - Argument value: TBD (BUIDL GroveBasin, pending redeployment)
                - External source: Pre-deployed contract #10 (BUIDL GroveBasin)
    - Additional parameters configured on the contract by a privileged actor: None — BUIDLTokenRedeemer is immutable. Registered on the basin via `addTokenRedeemer()` which grants `REDEEMER_CONTRACT_ROLE` and calls `setUp()`.
    - Ownership, roles, privilege callers: None — no access control. Callable by the GroveBasin contract (`onlyBasin` modifier) and the basin's manager admin (Grove Proxy `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`).
    - Deployment command:
        ```
        forge script script/SetupBUIDLUsdsUsdcBasin.s.sol:SetupBUIDLUsdsUsdcBasin \
            --sig "deployRedeemerContractAndGrantRedeemerRole(address)" <TBD: BUIDL GroveBasin address> \
            --rpc-url mainnet \
            --account grove-basin-deployer \
            --sender 0x6D99f476E7E9FCcd189fb87023cFa301364Fa817 --broadcast --slow --verify
        ```
    - Source code is verified on the block explorer: TBD (pending redeployment)
    - The deployer no longer has a privileged role: N/A — no access control.

## Pre-configurations

### BUIDL Basin TimelockController

1. **Deploy TimelockController**
    - Transaction trace URL: [0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8](https://etherscan.io/tx/0x63a9952301836480eea0f6fe830243eaa2a71ca23457f4c8a2792e015df526d8)
    - Contract being deployed: BUIDL Admin `TimelockController` (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`) (OpenZeppelin)
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

2. **Grant CANCELLER_ROLE to ALM Freezer**
    - Transaction trace URL: [0x211e0cab507ef6affbe69283e0270ffd41e84906fa6a347ac43b5889122d64e3](https://etherscan.io/tx/0x211e0cab507ef6affbe69283e0270ffd41e84906fa6a347ac43b5889122d64e3)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
            - External source: grove-address-registry `Ethereum.ALM_FREEZER`
    - Note: The constructor also grants `CANCELLER_ROLE` to the proposer by default.

3. **Grant PROPOSER_ROLE to Securitize owner address**
    - Transaction trace URL: [0x13708c4b25bacae1fc473709c229943ec095af29833dd3ce813c9077536d825d](https://etherscan.io/tx/0x13708c4b25bacae1fc473709c229943ec095af29833dd3ce813c9077536d825d)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PROPOSER_ROLE` = `keccak256("PROPOSER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x551e841e6fb54431a0664C8776784F6d7E611428` (Securitize owner address)
            - External source: Provided by Securitize

4. **Grant CANCELLER_ROLE to Securitize owner address**
    - Transaction trace URL: [0xbdc05e7f7a38de9fcc25bf0b19a5e4afee54e45284a9db3cb124ead56c7dd17b](https://etherscan.io/tx/0xbdc05e7f7a38de9fcc25bf0b19a5e4afee54e45284a9db3cb124ead56c7dd17b)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x551e841e6fb54431a0664C8776784F6d7E611428` (Securitize owner address)
            - External source: Provided by Securitize

5. **Revoke PROPOSER_ROLE from deployer**
    - Transaction trace URL: [0xbf846cf6e99603750864247a3697abdaf44c086c20bc25d9177cdf90c30d9880](https://etherscan.io/tx/0xbf846cf6e99603750864247a3697abdaf44c086c20bc25d9177cdf90c30d9880)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PROPOSER_ROLE` = `keccak256("PROPOSER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA

6. **Revoke CANCELLER_ROLE from deployer**
    - Transaction trace URL: [0x1a22124df961eee66a3d21b45ae9709a0fda7ca532bc77ad28750667790aaa3c](https://etherscan.io/tx/0x1a22124df961eee66a3d21b45ae9709a0fda7ca532bc77ad28750667790aaa3c)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA
    - Note: The deployer held `CANCELLER_ROLE` via the constructor (granted to the initial proposer by default).

7. **Issuer to propose a test transaction (sending 0 wei of ETH)**
    - Transaction trace URL: [Etherscan](https://etherscan.io/tx/0xb4b00a311f9a5edcdec2cdfc8ea69fda6e0974c95ca11cc286cb640f356c4dea)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)`
    - Function arguments:
        1. `target` - Securitize owner address (`0x453A28B31fdc31858C35B02bc3A42BCD8bfbAd3a`)
        2. `value` - `0`
        3. `data` - `0x` (empty calldata)
        4. `predecessor` - `bytes32(0)`
        5. `salt` - `bytes32(0)`
        6. `delay` - `604800` (7 days)
    - Who will perform this action: Issuer (proposer)

8. **Grove to simulate executing the test transaction with Grove Proxy on Tenderly**
    - Transaction trace URL: [Tenderly](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/e7893a1c-cc85-45f4-8445-7c0c7f11b7e9/tx/0x7c78b8ff899ad3d2417d030115429304585a893d7a325a4297fc49aedc68e79c)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `execute(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt)`
    - Function arguments: Same target/value/data/predecessor/salt as step 7
    - Who will perform this action: Grove
    - Note: This is a Tenderly simulation only, not an on-chain execution. Verifies the executor role is correctly configured.

9. **Grove to cancel the test transaction with the freezer multisig**
    - Transaction trace URL: [Tenderly testnet tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/1a16f08c-7266-4d33-9691-b5878a0a938d/tx/0x5f4961549c6ecaa14ac94591cc7134f1ac106b9a8f7b8cc6a2275fca0bfbb766)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `cancel(bytes32 id)`
    - Function arguments:
        1. `id` - `0x13bdfcbacee698fdfbc8de83e0ce86a238900e77348b0fa964df0efce295892e` (operation hash from the `schedule` call in step 7)
    - Who will perform this action: Grove (via ALM Freezer `0xB0113804960345fd0a245788b3423319c86940e5`)
    - Note: This will be performed on a Tenderly testnet, not on-chain. Verifies the CANCELLER_ROLE is correctly configured for the freezer multisig.

10. **Grant PROPOSER_ROLE to new Securitize owner address**
    - Transaction trace URL: [0xc24439197b6c9fdcde9ea9ea45f6dd6c65cd3d0634e6011dc5477a948579f59e](https://etherscan.io/tx/0xc24439197b6c9fdcde9ea9ea45f6dd6c65cd3d0634e6011dc5477a948579f59e)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PROPOSER_ROLE` = `keccak256("PROPOSER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x453A28B31fdc31858C35B02bc3A42BCD8bfbAd3a` (new Securitize owner address)
            - External source: Provided by Securitize
    - Note: Replacing old Securitize owner address `0x551e841e6fb54431a0664C8776784F6d7E611428`.

11. **Grant CANCELLER_ROLE to new Securitize owner address**
    - Transaction trace URL: [0x87d10db8cb37d90216b44c8da3c18ac2a6684de20078a26503163b3f56f56aa4](https://etherscan.io/tx/0x87d10db8cb37d90216b44c8da3c18ac2a6684de20078a26503163b3f56f56aa4)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x453A28B31fdc31858C35B02bc3A42BCD8bfbAd3a` (new Securitize owner address)
            - External source: Provided by Securitize
    - Note: Replacing old Securitize owner address `0x551e841e6fb54431a0664C8776784F6d7E611428`.

12. **Revoke PROPOSER_ROLE from old Securitize owner address**
    - Transaction trace URL: [0x64638b5dd25690f514cc134b028bccd59f420bb137e7536d79f02de51de0f09c](https://etherscan.io/tx/0x64638b5dd25690f514cc134b028bccd59f420bb137e7536d79f02de51de0f09c)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PROPOSER_ROLE` = `keccak256("PROPOSER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x551e841e6fb54431a0664C8776784F6d7E611428` (old Securitize owner address)
            - External source: Previously provided by Securitize

13. **Revoke CANCELLER_ROLE from old Securitize owner address**
    - Transaction trace URL: [0x5a65ee1d8ca2f2e76276edcbf29dd6847924f3c116e94bb2f5c8cc5a22662cb8](https://etherscan.io/tx/0x5a65ee1d8ca2f2e76276edcbf29dd6847924f3c116e94bb2f5c8cc5a22662cb8)
    - Contract being called: BUIDL Admin TimelockController (`0xdB8C7c814E9780659B23478EF4Bda9032CC9Ff34`)
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0x551e841e6fb54431a0664C8776784F6d7E611428` (old Securitize owner address)
            - External source: Previously provided by Securitize

### JTRSY Basin TimelockController

1. **Deploy TimelockController**
    - Transaction trace URL: [0xec51cda57fcb7698dbc3fb9a7da1bd8eb0fca506332700546a311ffd3b265b9d](https://etherscan.io/tx/0xec51cda57fcb7698dbc3fb9a7da1bd8eb0fca506332700546a311ffd3b265b9d)
    - Contract being deployed: JTRSY Admin `TimelockController` (`0xA52dC9876aB4A9DB6dAfbb83410554086054d140`) (OpenZeppelin)
    - Constructor arguments:
        1. `minDelay`
            - Argument value: `604800` (7 days)
            - External source: Script constant `MIN_DELAY`
        2. `proposers`
            - Argument value: `[0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c]`
            - External source: JTRSY proposer multisig address (provided by Anemoy)
        3. `executors`
            - Argument value: `[0x1369f7b2b38c76B6478c0f0E66D94923421891Ba]` (Grove Proxy)
            - External source: grove-address-registry `Ethereum.GROVE_PROXY`
        4. `admin`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA

2. **Grant CANCELLER_ROLE to ALM Freezer**
    - Transaction trace URL: [0x69e236ea1ad036bea9775e735768f63d311d1ec45ff75933c1fbc0a55d9a472f](https://etherscan.io/tx/0x69e236ea1ad036bea9775e735768f63d311d1ec45ff75933c1fbc0a55d9a472f)
    - Contract being called: JTRSY Admin TimelockController (`0xA52dC9876aB4A9DB6dAfbb83410554086054d140`)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `CANCELLER_ROLE` = `keccak256("CANCELLER_ROLE")`
            - External source: TimelockController constant
        2. `account`
            - Argument value: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
            - External source: grove-address-registry `Ethereum.ALM_FREEZER`
    - Note: The constructor also grants `CANCELLER_ROLE` to the proposer by default.

3. **Issuer to propose a test transaction (sending 0 wei of ETH)**
    - Transaction trace URL: [Etherscan](https://etherscan.io/tx/0xcb534ea4d3379ad43147e07d4beb7f61ecc9bf49854534b571f7df310aa3b09b)
    - Contract being called: JTRSY Admin TimelockController (`0xA52dC9876aB4A9DB6dAfbb83410554086054d140`)
    - Function being called: `schedule(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt, uint256 delay)`
    - Function arguments:
        1. `target` - JTRSY proposer multisig (`0x9184DdBCc4824B76CE2AEFA72534a1a87aA5037c`)
        2. `value` - `0` (1 wei)
        3. `data` - `0x` (empty calldata)
        4. `predecessor` - `bytes32(0)`
        5. `salt` - `bytes32(0)`
        6. `delay` - `604800` (7 days)
    - Who will perform this action: Issuer (proposer)

4. **Grove to simulate executing the test transaction with Grove Proxy on Tenderly**
    - Transaction trace URL: [Tenderly testnet tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/e7893a1c-cc85-45f4-8445-7c0c7f11b7e9/tx/0x18284a30a32f80c4eb7481631086765e75a6fab237473aa01e6a92fedcc0847e)
    - Contract being called: JTRSY Admin TimelockController (`0xA52dC9876aB4A9DB6dAfbb83410554086054d140`)
    - Function being called: `execute(address target, uint256 value, bytes data, bytes32 predecessor, bytes32 salt)`
    - Function arguments: Same target/value/data/predecessor/salt as step 3
    - Who will perform this action: Grove (via Grove Proxy `0x1369f7b2b38c76B6478c0f0E66D94923421891Ba`)
    - Note: This is a Tenderly simulation only, not an on-chain execution. Verifies the executor role is correctly configured.

5. **Grove to cancel the test transaction with the freezer multisig**
    - Transaction trace URL: [Tenderly testnet tx](https://dashboard.tenderly.co/steakhouse/bloom-production/testnet/9ff0d894-9609-4323-8c5e-4c771244f600/tx/0x35dd44f9ce319487949882c6c102819f210fcbf12c425d31f615500b5b1eef24)
    - Contract being called: JTRSY Admin TimelockController (`0xA52dC9876aB4A9DB6dAfbb83410554086054d140`)
    - Function being called: `cancel(bytes32 id)`
    - Function arguments:
        1. `id` - operation hash from the `schedule` call in step 3
    - Who will perform this action: Grove (via ALM Freezer `0xB0113804960345fd0a245788b3423319c86940e5`)
    - Note: This will be performed on a Tenderly testnet, not on-chain. Verifies the CANCELLER_ROLE is correctly configured for the freezer multisig.

### SetupBUIDLUsdsUsdcBasin post-deploy configuration

1. **Approve GroveBasinFactory to spend 1 USDS (seed amount)**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD (pending redeployment)
    - Contract being called: GroveBasinFactory (`0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
    - Function being called: `deploy(address owner, address liquidityProvider, address swapToken, address collateralToken, address creditToken, address swapTokenRateProvider, address collateralTokenRateProvider, address creditTokenRateProvider)`
    - Function arguments:
        1. `owner`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
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
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ADMIN_ROLE` = `keccak256("MANAGER_ADMIN_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA

5. **Deploy UsdsUsdcPocket**
    - Transaction trace URL: TBD (pending redeployment)
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPocket(address newPocket)`
    - Function arguments:
        1. `newPocket`
            - Argument value: UsdsUsdcPocket address (deployed in step 5)
            - External source: Deterministic from deployment

7. **Deploy and add BUIDLTokenRedeemer**
    - Transaction trace URL: TBD (pending redeployment)
    - Contract being deployed: BUIDLTokenRedeemer at TBD (pending redeployment)
    - Constructor arguments:
        1. `creditToken_`: `******************************************` (BUIDL)
        2. `redemptionAddress_`: `0x8780Dd016171B91E4Df47075dA0a947959C34200` (Securitize redemption address)
        3. `basin_`: TBD (BUIDL GroveBasin, pending redeployment)
    - Registered on basin via `addTokenRedeemer()` which grants `REDEEMER_CONTRACT_ROLE` and calls `setUp()`.

8. **Grant MANAGER_ROLE to ALM Relayer**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xB0113804960345fd0a245788b3423319c86940e5` (ALM Freezer)
            - External source: grove-address-registry `Ethereum.ALM_FREEZER`

10. **Grant REDEEMER_ROLE**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `REDEEMER_ROLE` = `keccak256("REDEEMER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xdfC603076EA75895DD4d59c6e2ee5038f881CB74` (old Securitize redeemer address)
            - External source: Previously provided by Securitize

10a. **Grant REDEEMER_ROLE to new Securitize redeemer address**
    - Transaction trace URL: TBD (pending redeployment)
    - Contract being called: GroveBasin (TBD, pending redeployment)
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `REDEEMER_ROLE` = `keccak256("REDEEMER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x488F27168a19472c51f003fbC5b75B1ACc3B7b4c` (new Securitize redeemer address)
            - External source: Provided by Securitize
    - Note: Replacing old redeemer address `0xdfC603076EA75895DD4d59c6e2ee5038f881CB74`.

10b. **Revoke REDEEMER_ROLE from old Securitize redeemer address**
    - Transaction trace URL: TBD (pending redeployment)
    - Contract being called: GroveBasin (TBD, pending redeployment)
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `REDEEMER_ROLE` = `keccak256("REDEEMER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0xdfC603076EA75895DD4d59c6e2ee5038f881CB74` (old Securitize redeemer address)
            - External source: Previously provided by Securitize

10c. **Remove old BUIDLTokenRedeemer (revoke REDEEMER_CONTRACT_ROLE)**
    - Transaction trace URL: TBD (pending redeployment)
    - Contract being called: GroveBasin (TBD, pending redeployment)
    - Function being called: `removeTokenRedeemer(address redeemer)`
    - Function arguments:
        1. `redeemer`
            - Argument value: TBD (old BUIDLTokenRedeemer, superseded by #13)
            - External source: Pre-deployed contract #9
    - Note: `removeTokenRedeemer` revokes `REDEEMER_CONTRACT_ROLE` from the old redeemer. Required because the new BUIDLTokenRedeemer (TBD) was registered via `addTokenRedeemer` in the redeployment script, but the old one still holds the role.

11. **Grant PAUSER_ROLE to deployer (temporary)**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA
    - Note: Temporary grant to allow the deployer to call `setPaused` in steps 12--15. Revoked in step 17.

12. **Pause SWAP_SWAP_TO_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_SWAP_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_SWAP_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

13. **Pause SWAP_COLLATERAL_TO_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_COLLATERAL_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_COLLATERAL_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

14. **Pause DEPOSIT_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_DEPOSIT_CREDIT` = `bytes4(keccak256("PAUSED_DEPOSIT_CREDIT"))`
            - External source: GroveBasin.sol constant

15. **Pause WITHDRAW_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_WITHDRAW_CREDIT` = `bytes4(keccak256("PAUSED_WITHDRAW_CREDIT"))`
            - External source: GroveBasin.sol constant

16. **Set fee bounds to [0, 500] bps (0% to 5%)**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA

18. **Grant OWNER_ROLE to BUIDL Admin TimelockController**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `OWNER_ROLE` = `DEFAULT_ADMIN_ROLE` = `bytes32(0)`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA

### SetupJTRSYUsdsUsdcBasin post-deploy configuration

1. **Approve GroveBasinFactory to spend 1 USDS (seed amount)**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD (pending redeployment)
    - Contract being called: GroveBasinFactory (`0x78Dc98D689Fe9A1b0056ac1cDFC14722bDA6D49a`)
    - Function being called: `deploy(address owner, address liquidityProvider, address swapToken, address collateralToken, address creditToken, address swapTokenRateProvider, address collateralTokenRateProvider, address creditTokenRateProvider)`
    - Function arguments:
        1. `owner`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
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
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `MANAGER_ADMIN_ROLE` = `keccak256("MANAGER_ADMIN_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA

5. **Deploy UsdsUsdcPocket**
    - Transaction trace URL: TBD (pending redeployment)
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPocket(address newPocket)`
    - Function arguments:
        1. `newPocket`
            - Argument value: UsdsUsdcPocket address (deployed in step 5)
            - External source: Deterministic from deployment

7. **Deploy JTRSYTokenRedeemer**
    - Transaction trace URL: TBD (pending redeployment)
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `addTokenRedeemer(address redeemer)`
    - Function arguments:
        1. `redeemer`
            - Argument value: JTRSYTokenRedeemer address (deployed in step 7)
            - External source: Deterministic from deployment
    - Note: This grants `REDEEMER_CONTRACT_ROLE` to the redeemer and calls `setUp()` on it.

9. **Grant MANAGER_ROLE to ALM Relayer**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `grantRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA
    - Note: Temporary grant to allow the deployer to call `setPaused` in steps 13--16. Revoked in step 18.

13. **Pause SWAP_SWAP_TO_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_SWAP_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_SWAP_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

14. **Pause SWAP_COLLATERAL_TO_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_SWAP_COLLATERAL_TO_CREDIT` = `bytes4(keccak256("PAUSED_SWAP_COLLATERAL_TO_CREDIT"))`
            - External source: GroveBasin.sol constant

15. **Pause DEPOSIT_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_DEPOSIT_CREDIT` = `bytes4(keccak256("PAUSED_DEPOSIT_CREDIT"))`
            - External source: GroveBasin.sol constant

16. **Pause WITHDRAW_CREDIT**
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `setPaused(bytes4 key)`
    - Function arguments:
        1. `key`
            - Argument value: `PAUSED_WITHDRAW_CREDIT` = `bytes4(keccak256("PAUSED_WITHDRAW_CREDIT"))`
            - External source: GroveBasin.sol constant

17. **Set fee bounds to [0, 500] bps (0% to 5%)**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `PAUSER_ROLE` = `keccak256("PAUSER_ROLE")`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
            - External source: Deployer EOA

19. **Grant OWNER_ROLE to JTRSY Admin TimelockController**
    - Transaction trace URL: TBD
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
    - Transaction trace URL: TBD
    - Contract being called: GroveBasin
    - Function being called: `revokeRole(bytes32 role, address account)`
    - Function arguments:
        1. `role`
            - Argument value: `OWNER_ROLE` = `DEFAULT_ADMIN_ROLE` = `bytes32(0)`
            - External source: GroveBasin.sol constant
        2. `account`
            - Argument value: `0x6D99f476E7E9FCcd189fb87023cFa301364Fa817` (deployer)
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

1. **Transfer PROPOSER_ROLE and CANCELLER_ROLE from deployer to Securitize owner address**
    - Intended end goal: The BUIDL Admin TimelockController's `PROPOSER_ROLE` must be transferred from the deployer (temporary initial proposer) to the Securitize owner address. This requires granting `PROPOSER_ROLE` to the Securitize address and revoking it from the deployer.
    - Why is it required to be done in advance: The deployer is set as the initial proposer only as a placeholder. The issuer (Securitize) must hold the proposer role before the system is considered live.
    - Proof that it was done or planned to be done: 
        - `PROPOSER_ROLE` granted to `0x551e841e6fb54431a0664C8776784F6d7E611428` in tx [0x13708c4b...](https://etherscan.io/tx/0x13708c4b25bacae1fc473709c229943ec095af29833dd3ce813c9077536d825d). 
        - `CANCELLER_ROLE` granted to `0x551e841e6fb54431a0664C8776784F6d7E611428` in tx [0xbdc05e7f...](https://etherscan.io/tx/0xbdc05e7f7a38de9fcc25bf0b19a5e4afee54e45284a9db3cb124ead56c7dd17b). 
        - `PROPOSER_ROLE` revoked from deployer in tx [0xbf846cf6...](https://etherscan.io/tx/0xbf846cf6e99603750864247a3697abdaf44c086c20bc25d9177cdf90c30d9880).
        - `CANCELLER_ROLE` revoked from deployer in tx [0x1a22124d...](https://etherscan.io/tx/0x1a22124df961eee66a3d21b45ae9709a0fda7ca532bc77ad28750667790aaa3c).
    - **Address change**: Securitize changed their proposer/owner address. Roles must be rotated from `0x551e841e6fb54431a0664C8776784F6d7E611428` to `0x453A28B31fdc31858C35B02bc3A42BCD8bfbAd3a`. See BUIDL Basin TimelockController pre-configuration steps 10–13.

2. **Deployer to revoke own admin role**
    - Intended end goal: The deployer must call `revokeRole(DEFAULT_ADMIN_ROLE, deployer)` on the BUIDL Basin TimelockController so that no single EOA retains admin privileges. After this, roles can only be managed through the timelock itself.
    - Why is it required to be done in advance: The deployer holds `DEFAULT_ADMIN_ROLE` after deployment, which allows bypassing the timelock delay for role changes. This must be revoked before the system is considered live.
    - Proof that it was done or planned to be done: TODO

### JTRSY Basin TimelockController

1. **Deployer to revoke own admin role**
    - Intended end goal: The deployer must call `revokeRole(DEFAULT_ADMIN_ROLE, deployer)` on the JTRSY Basin TimelockController so that no single EOA retains admin privileges. After this, roles can only be managed through the timelock itself.
    - Why is it required to be done in advance: The deployer holds `DEFAULT_ADMIN_ROLE` after deployment, which allows bypassing the timelock delay for role changes. This must be revoked before the system is considered live.
    - Proof that it was done or planned to be done: `DEFAULT_ADMIN_ROLE` revoked from deployer in tx [0x6ec10f73...](https://etherscan.io/tx/0x6ec10f73b0451935de484c233c0d949624debf424e79ff0c53e240f6e129249f).

### BUIDL Basin

1. **BUIDLTokenRedeemer must be deployed**
    - Intended end goal: The BUIDL redemption address is required to deploy the `BUIDLTokenRedeemer` contract, which is passed as a constructor argument. Without it, the redeemer cannot be deployed and the basin will not support BUIDL redemptions.
    - Why is it required to be done in advance: The `BUIDLTokenRedeemer` constructor requires the redemption address; the deployment script cannot proceed without it.
    - Proof that it was done or planned to be done: Deployed at TBD in tx TBD. Redemption address: `0x0d671C15Aa427fFc31C3A484C3ACdd8043F73052`.
    - **Address change**: Securitize changed their redemption vault address from `0x0d671C15Aa427fFc31C3A484C3ACdd8043F73052` to `0x8780Dd016171B91E4Df47075dA0a947959C34200`. Since `redemptionAddress_` is an immutable constructor argument, a new `BUIDLTokenRedeemer` must be deployed with the new vault address and registered on the basin via `removeTokenRedeemer` / `addTokenRedeemer`.
    - **Mainnet deployment**: Deployed at TBD in tx TBD. Redemption address: `0x8780Dd016171B91E4Df47075dA0a947959C34200`. `addTokenRedeemer` in tx TBD. Source code verified on Etherscan: TBD.

2. **Grant redeemer address the REDEEMER_ROLE**
    - Intended end goal: A valid address to grant the `REDEEMER_ROLE` on the BUIDL GroveBasin. This address will be authorized to trigger redemptions.
    - Why is it required to be done in advance: Currently set to `address(0)` in the script; the conditional skip means no redeemer role holder will be set until the address is provided.
    - Proof that it was done or planned to be done: `REDEEMER_ROLE` granted to `0xdfC603076EA75895DD4d59c6e2ee5038f881CB74` in tx TBD.
    - **Address change**: Securitize changed their redeemer address. `REDEEMER_ROLE` must be rotated from `0xdfC603076EA75895DD4d59c6e2ee5038f881CB74` to `0x488F27168a19472c51f003fbC5b75B1ACc3B7b4c`. See SetupBUIDLUsdsUsdcBasin pre-configuration steps 10a–10b.

3. **BUIDL Basin must be allowlisted on BUIDL token**
    - Intended end goal: The BUIDL Basin contract (TBD, pending redeployment) can hold BUIDL tokens
    - Why is it required to be done in advance: BUIDL requires holders to be on an allowlist.
    - Proof that it was done or planned to be done: TODO

4. **Revoke MANAGER_ADMIN_ROLE from deployer**
    - Intended end goal: The deployer must call `revokeRole(MANAGER_ADMIN_ROLE, deployer)` on the BUIDL GroveBasin so that no single EOA retains admin privileges. After this, roles can only be managed through the timelock itself.
    - Why is it required to be done in advance: The deployer holds `MANAGER_ADMIN_ROLE` after deployment, which allows bypassing the timelock delay to set up the token redeeemer contract (step 1) and add a redeemer (step 2). This must be revoked before the system is considered live so that no address other thatn Grove Proxy holds the MANAGER_ADMIN_ROLE
    - Proof that it was done or planned to be done: TODO

### SetupJTRSYUsdsUsdcBasin

1. **JTRSYTokenRedeemer must be allowlisted on Centrifuge vault and JTRSY token**
    - Intended end goal: The redeemer contract (TBD, pending redeployment) can call `requestRedeem` and `redeem` on the Centrifuge vault, and can hold/transfer JTRSY tokens.
    - Why is it required to be done in advance: The Centrifuge vault requires callers to be on an allowlist.
    - Proof that it was done or planned to be done: Allowlisted via `updateRestriction` on the Centrifuge restriction manager (`0xA4A7Bb3831958463b3FE3E27A6a160F764341953`). The `UpdateMember` event confirms the redeemer was added to the JTRSY token member list with `validUntil = 4294967295` (type(uint32).max, i.e. no expiry). Transaction: TBD.

2. **JTRSY Basin must be allowlisted on JTRSY token**
    - Intended end goal: The JTRSY Basin contract (TBD, pending redeployment) can hold JTRSY tokens.
    - Why is it required to be done in advance: JTRSY requires holders to be on an allowlist.
    - Proof that it was done or planned to be done: Allowlisted via `updateRestriction` on the Centrifuge restriction manager (`0xA4A7Bb3831958463b3FE3E27A6a160F764341953`). Transaction: TBD.

3. **Revoke MANAGER_ADMIN_ROLE from deployer**
    - Intended end goal: The deployer must call `revokeRole(MANAGER_ADMIN_ROLE, deployer)` on the JTRSY GroveBasin so that no single EOA retains admin privileges. After this, roles can only be managed through the timelock itself.
    - Why is it required to be done in advance: The deployer holds `MANAGER_ADMIN_ROLE` after deployment, which allows bypassing the timelock delay to set up the token redeeemer contract (step 1) and add a redeemer (step 2). This must be revoked before the system is considered live so that no address other thatn Grove Proxy holds the MANAGER_ADMIN_ROLE
    - Proof that it was done or planned to be done: `MANAGER_ADMIN_ROLE` revoked from deployer in tx TBD.

## Proposed actions

**JTRSY Initial Deposit**
- Business reason behind this action: To seed the JTRSY basin with initial liquidity and establish a baseline for the system to operate.
- Who will perform this action: Grove Proxy
- Important arguments:
    - `amount`: 50M USDS; Grove to confirm
    - `receiver`: Grove ALM Proxy

**BUIDL Initial Deposit**
- Business reason behind this action: To seed the JTRSY basin with initial liquidity and establish a baseline for the system to operate.
- Who will perform this action: Grove Proxy
- Important arguments:
    - `amount`: 50M USDS; Grove to confirm
    - `receiver`: Grove ALM Proxy
- _Note_: contingent on Securitize onboarding completion (see Pre-requirements §1–§3 and §7); if Securitize is not ready by spell execution, this item moves to a future spell.


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

6. **Test swap transaction (BUIDL Basin — swap to USDS)**
    - What will be done: Perform a small test swap on the BUIDL GroveBasin (TBD, pending redeployment) to confirm end-to-end functionality.
    - How it will be done: Tenderly simulation (liquidity deposit does not exist until the June 4th spell)
    - Expected outcome: Swap succeeds, expected output amount is received.
    - Who will perform this action: Deployer or designated tester, working with the issuer

7. **Test swap transaction (BUIDL Basin — swap to USDC)**
    - What will be done: Perform a small test swap on the BUIDL GroveBasin (TBD, pending redeployment) to confirm end-to-end functionality.
    - How it will be done: Tenderly simulation (liquidity deposit does not exist until the June 4th spell)
    - Expected outcome: Swap succeeds, expected output amount is received.
    - Who will perform this action: Deployer or designated tester, working with the issuer

8. **Test swap transaction (JTRSY Basin — swap to USDS)**
    - Transaction trace URL: TBD
    - What will be done: Perform a small test swap on the JTRSY GroveBasin (TBD, pending redeployment) to confirm end-to-end functionality.
    - How it will be done: Tenderly simulation (liquidity deposit does not exist until the June 4th spell)
    - Expected outcome: Swap of 0.5 JTRSY for 0.552347 USDS succeeds.
    - Who will perform this action: Deployer or designated tester, working with the issuer

9. **Test swap transaction (JTRSY Basin — swap to USDC)**
    - Transaction trace URL: TBD
    - What will be done: Perform a small test swap on the JTRSY GroveBasin (TBD, pending redeployment) to confirm end-to-end functionality.
    - How it will be done: Tenderly simulation (liquidity deposit does not exist until the June 4th spell)
    - Expected outcome: Swap of 0.5 JTRSY for 0.552347 USDC succeeds.
    - Who will perform this action: Deployer or designated tester, working with the issuer

10. **Test redemption transaction (BUIDL Basin)**
    - What will be done: Perform a small test redemption on the BUIDL GroveBasin (TBD, pending redeployment) to confirm end-to-end functionality.
    - How it will be done: Tenderly simulation (liquidity deposit does not exist until the June 4th spell)
    - Expected outcome: Redemption succeeds, expected output amount is received.
    - Who will perform this action: Deployer or designated tester, working with the issuer

11. **Test redemption transaction (JTRSY Basin — initiate redeem)**
    - Transaction trace URL: TBD
    - What will be done: Perform a small test redemption on the JTRSY GroveBasin (TBD, pending redeployment) to confirm end-to-end functionality.
    - How it will be done: Tenderly simulation (liquidity deposit does not exist until the June 4th spell)
    - Expected outcome: Redemption succeeds, expected output amount is received.
    - Who will perform this action: Deployer or designated tester, working with the issuer

12. **Verify source code on block explorer**
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

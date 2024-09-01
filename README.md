# Some audit guidelines

- We want to ensure our contracts are safe for our users. We don't want malicious actors to be able to take our users' tokens.
- We want to ensure our users can trade our NFTs only through our exchange contract.
- We want to ensure our exchange fees cannot be bypassed.
- We want to ensure nobody can mint new NFTs without following our minter configurations (rules).
- We don't really care about gas optimization, please don’t waste your precious audit time on them.

# Fantasy Gameplay 
- Fantasy is a Trading Card Game in which players collect cards featuring crypto influencers to compete and earn ETH, BLAST, more cards, and FAN Points.
- Players acquire cards on the Fantasy marketplace, using them to assemble a deck and compete in the Fantasy Tournaments.
- Players are ranked based on their influencers' performance on Twitter. At the end of a competition, rewards are distributed according to the players' rankings.
- Newly distributed cards are minted, completing the initial distribution of cards, which was initiated through an airdrop and a sale.
- A VRGDA allows players to buy cards from the Fantasy Shop.
- Details can be found here https://aaa-angel.notion.site/fantasy-top-1b35a92e51934478bb542a5115469302?pvs=4


# Fantasy Contracts

**ExecutionDelegate** contract is responsible for executing token transfers on behalf of the user. It is therefore the only contract the user needs to approve for token transfers. It is also the only contract allowed to transfer and mint fantasy cards. The ExecutionDelegate functions are opened to whitelisted contracts (aka Exchange and Minter)

**FantasyCards** contract is an ERC721; it can only be transferred and minted by the ExecutionDelegate contract. This is to ensure only contracts approved by the protocol have access to these functions.

**Exchange** contract is responsible for trading fantasy cards. When buying or selling a card, a fee is taken and sent to the protocol's treasury address. The buy and sell functions of this contract can only be called by EOAs

**Minter** contract is responsible for minting new fantasy cards. The owner of the Minter contract can configure the minting dynamics. The minter can be configured to use a fixed price or a linear gradual dutch auction.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Run local node Anvil

```shell
$ anvil
```

### Deploy Local

Run local node first:

```shell
$ anvil
```

In an other terminal run:

```shell
$ forge script script/deploy_local.s.sol:Deploy --rpc-url http://127.0.0.1:8545 --broadcast
```

### Deploy Mainnet
```shell
forge script script/deploy_mainnet.s.sol:Deploy --rpc-url https://rpc.blast.io --broadcast
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```


# MAINNET ADDRESSES

## Official addresses
TREASURY_ADDRESS:  0x8Ab15fE88a00b03724aC91EE4eE1f998064F2e31
GOVERNANCE_ADDRESS:  0x87300D35353D21479e0c96B87D9a7997726f4c16
DEPLOYER 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918
MINT_CONFIG_MASTER: 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918 (deployer)
PAUSER_ROLE: 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918 (deployer)

## Official contracts mainnet
FANTASY COLLECTION:  0x0AAADCf421A3143E5cB2dDB8452c03ae595B0734
EXECUTION DELEGATE:  0xA11Bf3A1b86A977e3beAb2a2E20c67ffDE9DEF7e
MINTER:  0x86b58ca576c24F79aD1e5459aee01d40BEA22828
EXCHANGE:  0x56BFb3a51A7A2D4F685e5107CEE05a58A0F1ad61

# VERIFYING CONTRACTS

## VERIFY EXECUTION DELEGATE
```shell
forge verify-contract EXECUTION_DELEGATE_ADDRESS src/ExecutionDelegate.sol:ExecutionDelegate --verifier-url https://api.blastscan.io/api --etherscan-api-key ETHERSCAN_API_KEY  --compiler-version 0.8.20
```

## VERIFY MINTER
```shell
forge verify-contract MINTER_ADDRESS  src/Minter.sol:Minter --verifier-url https://api.blastscan.io/api --etherscan-api-key ETHERSCAN_API_KEY --compiler-version 0.8.20 --constructor-args $(cast abi-encode "constructor(address _treasury, address _executionDelegate, uint256 _cardsRequiredForLevelUp, uint256 _cardsRequiredForBurnToDraw, uint256 _cardsDrawnPerBurn)" TREASURY_ADDRESS EXECUTION ardsRequiredForLevelUp cardsRequiredForBurnToDraw cardsDrawnPerBurn)
```

## VERIFY FANTASY CARDS
```shell
forge verify-contract FANTASY_COLLECTION_ADDRESS src/FantasyCards.sol:FantasyCards --verifier-url https://api.blastscan.io/api --etherscan-api-key ETHERSCAN_API_KEY  --compiler-version 0.8.20
```

## VERIFY EXCHANGE

```shell
forge verify-contract EXCHANGE_ADDRESS src/Exchange.sol:Exchange --verifier-url https://api.blastscan.io/api --etherscan-api-key ETHERSCAN_API_KEY  --compiler-version 0.8.20 --constructor-args $(cast abi-encode "constructor(address _protocolFeeRecipient, uint256 _protocolFeeBps, address _executionDelegate)" TREASURY_ADDRESS 300 EXECUTION_DELEGATE) --libraries "src/libraries/OrderLib.sol:OrderLib:ORDERLIB_ADDRESS" --watch
```

## Official contracts Staging Mainnet
FANTASY COLLECTION:  0xC8E519e51115F4CE1d4D9FDd27B0D3c0eF26d55D
EXECUTION DELEGATE:  0x83B56a9C077eF4DC0E2D8e9c3748Fe78242e976F
MINTER:  0x2742a5d853a0a6C97665bc00F42A67AD8Ca77fBc
EXCHANGE:  0x1c0f0E8ac40a11ea2DB96E6A3577bDDd15839fa1
ORDERLIB: 0x09B59376ddce9620D385F75fD4bBb6b1B5C3A6F0


<!-- FANTASY COLLECTION: 0x0908f097497054A753763Fa40e1D2c216F9B3847
EXECUTION DELEGATE: 0x3Da2a1D0C88dc1E5567970C305d09249Fc7ae08a
MINTER: 0x01655f68D8063234e2E8e069608AfCcA90cbbAf1
EXCHANGE: 0xDb922BD2c4B3F44d75Aa91A789296410F0f20b0e
ORDERLIB: 0x98d4B5BFBE71bE9c28DBB7045B9a30B831f53853 -->




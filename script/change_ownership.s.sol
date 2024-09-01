pragma solidity ^0.8.20;

// import "../lib/forge-std/src/Script.sol";
// import "../lib/forge-std/src/console.sol";

// import "../src/FantasyCards.sol";
// import "../src/Exchange.sol";
// import "../src/ExecutionDelegate.sol";
// import "../src/Minter.sol";

// contract TransferOwnership is Script {
//     // multisig for the treasury
//     address _treasury = 0x8Ab15fE88a00b03724aC91EE4eE1f998064F2e31;
//     // multisig for the governance
//     address _admin = 0x87300D35353D21479e0c96B87D9a7997726f4c16;
//     // eoa for managing mint configs
//     address _mintConfigMaster = 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918;
//     bytes32 public constant MINT_CONFIG_MASTER = keccak256("MINT_CONFIG_MASTER");
//     bytes32 public constant DEFAULT_ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
//     bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

//     // eoa for pausing the protocol
//     address _pauserExecutionDelegate = 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918;

//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
//         vm.startBroadcast(deployerPrivateKey);
//         // --------------------------------------------
//         /* MINTER SETUP */
//         // --------------------------------------------
//         // change treasury in minter to treasury multisig
//         address minterAddress = vm.envAddress("MINTER_ADDRESS");
//         Minter minter = Minter(minterAddress);
//         minter.setTreasury(_treasury);

//         // move default admin role to governance multisig
//         minter.beginDefaultAdminTransfer(_admin);
//         // TODO: accept the default admin transfer via the governance multisig

//         // change mint config master to mint config master eoa
//         minter.grantRole(MINT_CONFIG_MASTER, _mintConfigMaster);

//         // --------------------------------------------
//         /* EXCHANGE SETUP */
//         // --------------------------------------------
//         // change treasury in exchange
//         address exchangeAddress = vm.envAddress("EXCHANGE_ADDRESS");
//         Exchange exchange = Exchange(exchangeAddress);

//         // change protocol fee recipient to treasury multisig
//         exchange.setProtocolFeeRecipient(_treasury);

//         // transfer the ownership of the exchange to the governance multisig
//         exchange.transferOwnership(_admin);
//         // TODO: accept the ownership transfer via the governance multisig

//         // --------------------------------------------
//         /* EXECUTION DELEGATE SETUP */
//         // --------------------------------------------
//         address executionDelegateAddress = vm.envAddress("EXECUTION_DELEGATE_ADDRESS");
//         ExecutionDelegate executionDelegate = ExecutionDelegate(executionDelegateAddress);
//         executionDelegate.beginDefaultAdminTransfer(_admin);
//         // TODO: accept the default admin transfer via the governance multisig

//         // change pauser role to pauser eoa
//         executionDelegate.grantRole(PAUSER_ROLE, _pauserExecutionDelegate);

//         // --------------------------------------------
//         /* FANTASY CARDS SETUP */
//         // --------------------------------------------
//         address fantasyCardsAddress = vm.envAddress("FANTASY_CARDS_ADDRESS");
//         FantasyCards fantasyCards = FantasyCards(fantasyCardsAddress);
//         fantasyCards.beginDefaultAdminTransfer(_admin);
//         // TODO: accept the default admin transfer via the governance multisig
//         vm.stopBroadcast();
//     }
// }

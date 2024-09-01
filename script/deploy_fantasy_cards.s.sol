pragma solidity ^0.8.20;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

import "../src/FantasyCards.sol";
import "../src/Exchange.sol";
import "../src/ExecutionDelegate.sol";
import "../src/Minter.sol";
import {BlastMock} from "../test/helpers/BlastMock.sol";

contract Deploy is Script {
    FantasyCards fantasyCards;
    // Exchange exchange;
    // ExecutionDelegate executionDelegate;
    // Minter minter;

    address weth = 0x4300000000000000000000000000000000000004;

    uint256 protocolFeeBps = 300;
    uint256 wethMinimumPrice = 1000000000000000; // 0.001 eth
    uint256 cardsRequiredForLevelUp = 5;
    uint256 cardsRequiredForBurnToDraw = 15;
    uint256 cardsDrawnPerBurn = 1;

    bytes32 public constant MINT_CONFIG_MASTER = keccak256("MINT_CONFIG_MASTER");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PK");
        address governance = vm.envAddress("GOVERNANCE_ADDRESS");
        address deployer = vm.addr(deployerPrivateKey);
        address minterAddress = vm.envAddress("MINTER_ADDRESS");
        address exchangeAddress = vm.envAddress("EXCHANGE_ADDRESS");
        address executionDelegateAddress = vm.envAddress("EXECUTION_DELEGATE_ADDRESS");

        console.log("GOVERNANCE_ADDRESS: ", governance);
        console.log("DEPLOYER", address(deployer));

        vm.startBroadcast(deployerPrivateKey);

        // --------------------------------------------
        /* FANTASY CARDS SETUP */
        // --------------------------------------------
        // Deploys the contract
        fantasyCards = new FantasyCards();
        console.log("FANTASY COLLECTION: ", address(fantasyCards));
        // Initiates the transfer of ownership to governance multisig
        // TODO: accept the default admin transfer via the governance multisig
        fantasyCards.beginDefaultAdminTransfer(governance);
        // --------------------------------------------
        /* END OF FANTASY CARDS SETUP */
        // --------------------------------------------

        // --------------------------------------------
        /* EXECUTION DELEGATE SETUP */
        // --------------------------------------------
        // Attache to execution delegate contract
        ExecutionDelegate executionDelegate = ExecutionDelegate(executionDelegateAddress);
        // --------------------------------------------
        /* END OF EXECUTION DELEGATE SETUP */
        // --------------------------------------------

        // --------------------------------------------
        /* MINTER SETUP */
        // --------------------------------------------
        // Attach to the minter contract
        Minter minter = Minter(minterAddress);
        minter.whiteListCollection(address(fantasyCards));
        // --------------------------------------------
        /* END OF MINTER SETUP */
        // --------------------------------------------

        // --------------------------------------------
        /* EXCHANGE SETUP */
        // --------------------------------------------
        // Attach to the exchange contract
        Exchange exchange = Exchange(exchangeAddress);
        // Whitelists the fantasy card collection
        exchange.whiteListCollection(address(fantasyCards));
        // --------------------------------------------
        /*  END OF EXCHANGE SETUP */
        // --------------------------------------------

        // REST OF THE SETUP;

        fantasyCards.grantRole(fantasyCards.EXECUTION_DELEGATE_ROLE(), address(executionDelegate));

        console.log("SCRIPT FINISHED");

        vm.stopBroadcast();
    }
}

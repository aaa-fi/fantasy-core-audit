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
    Exchange exchange;
    ExecutionDelegate executionDelegate;
    Minter minter;

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
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        address governance = vm.envAddress("GOVERNANCE_ADDRESS");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("TREASURY_ADDRESS: ", treasury);
        console.log("GOVERNANCE_ADDRESS: ", governance);
        console.log("DEPLOYER", address(deployer));
        require(treasury != address(0), "Invalid treasury address");
        require(governance != address(0), "Invalid governance address");

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
        // Deploys the contract
        executionDelegate = new ExecutionDelegate();
        console.log("EXECUTION DELEGATE: ", address(executionDelegate));
        // Sets the PAUSER_ROLE to the deployer
        executionDelegate.grantRole(PAUSER_ROLE, deployer);
        // Initiates the transfer of ownership to governance multisig
        // TODO: accept the admin transfer via the governance multisig
        executionDelegate.beginDefaultAdminTransfer(governance);
        // --------------------------------------------
        /* END OF EXECUTION DELEGATE SETUP */
        // --------------------------------------------

        // --------------------------------------------
        /* MINTER SETUP */
        // --------------------------------------------
        // Deploys the contract
        minter = new Minter(
            treasury,
            address(executionDelegate),
            cardsRequiredForLevelUp,
            cardsRequiredForBurnToDraw,
            cardsDrawnPerBurn
        );
        console.log("MINTER: ", address(minter));
        // Whitelists the fantasy card collection
        minter.whiteListCollection(address(fantasyCards));
        // Grants the MINT_CONFIG_MASTER role to the deployer
        minter.grantRole(MINT_CONFIG_MASTER, deployer);
        // Initiates the transfer of ownership to governance multisig
        // TODO: accept the ownership via the governance multisig
        minter.beginDefaultAdminTransfer(governance);
        // --------------------------------------------
        /* END OF MINTER SETUP */
        // --------------------------------------------

        // --------------------------------------------
        /* EXCHANGE SETUP */
        // --------------------------------------------
        // Deploys the contract
        exchange = new Exchange(treasury, protocolFeeBps, address(executionDelegate));
        console.log("EXCHANGE: ", address(exchange));
        // Whitelists the fantasy card collection
        exchange.whiteListCollection(address(fantasyCards));
        // Whitelists the wrapped ETH token and sets the minimum price
        exchange.whiteListPaymentToken(weth, wethMinimumPrice);
        // Initiates the transfer of ownership to governance multisig
        // TODO: accept the ownership transfer via the governance multisig
        exchange.transferOwnership(governance);
        // --------------------------------------------
        /*  END OF EXCHANGE SETUP */
        // --------------------------------------------

        // REST OF THE SETUP
        executionDelegate.approveContract(address(minter));
        executionDelegate.approveContract(address(exchange));

        fantasyCards.grantRole(fantasyCards.EXECUTION_DELEGATE_ROLE(), address(executionDelegate));

        console.log("SCRIPT FINISHED");

        vm.stopBroadcast();
    }
}

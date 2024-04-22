pragma solidity ^0.8.20;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

import "../src/FantasyCards.sol";
import "../src/Exchange.sol";
import "../src/ExecutionDelegate.sol";
import "../src/Minter.sol";

import "../src/interfaces/IBlast.sol";
import "../src/interfaces/IBlastPoints.sol";

contract DeploymentSanityCheck is Script {
    address wethAddress = 0x4300000000000000000000000000000000000004;
    address blastPointsAddress = 0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800;
    address blastGasAddress = 0x4300000000000000000000000000000000000002;

    address fantasyCardsAddress = 0x0908f097497054A753763Fa40e1D2c216F9B3847;
    address executionDelegateAddress = 0x3Da2a1D0C88dc1E5567970C305d09249Fc7ae08a;
    address minterAddress = 0x01655f68D8063234e2E8e069608AfCcA90cbbAf1;
    address exchangeAddress = 0xDb922BD2c4B3F44d75Aa91A789296410F0f20b0e;

    address treasuryAddress = 0x8Ab15fE88a00b03724aC91EE4eE1f998064F2e31;
    address governanceAddress = 0x87300D35353D21479e0c96B87D9a7997726f4c16;
    address mintConfigMasterAddress = 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918; // TODO: update
    address pauserAddress = 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918; // TODO: update
    address deployerAddress = 0x70aC9FA233435d1b764DF4e6d2F5C94eB0551918; // TODO: remove

    uint256 cardsRequiredForBurnToDraw = 15;
    uint256 cardsRequiredForLevelUp = 5;
    uint256 cardsDrawnPerBurn = 1;
    uint256 minimumPricePerPaymentToken = 1000000000000000; // 0.001 ether
    uint256 protocolFeeBps = 300; // 3%

    FantasyCards fantasyCards = FantasyCards(fantasyCardsAddress);
    ExecutionDelegate executionDelegate = ExecutionDelegate(executionDelegateAddress);
    Minter minter = Minter(minterAddress);
    Exchange exchange = Exchange(exchangeAddress);

    IBlast blastGas = IBlast(blastGasAddress);
    IBlastPoints blastPoints = IBlastPoints(blastPointsAddress);

    function run() external {
        // --------------------------------------------
        /* Fantasy Cards Sanity Check */
        // --------------------------------------------
        // Check Execution Delegate role
        require(
            fantasyCards.hasRole(fantasyCards.EXECUTION_DELEGATE_ROLE(), executionDelegateAddress),
            "FantasyCards has the wrong ExecutionDelegate"
        );
        // Check Default Admin role
        require(
            fantasyCards.hasRole(fantasyCards.DEFAULT_ADMIN_ROLE(), governanceAddress),
            "FantasyCards has the wrong Default Admin"
        );
        // Check Gas Governor
        require(
            blastGas.governorMap(fantasyCardsAddress) == deployerAddress,
            "FantasyCards has the wrong Gas Governor"
        ); // TODO: update from deployer
        // Check Points Operator
        require(
            blastPoints.operators(fantasyCardsAddress) == deployerAddress,
            "FantasyCards has the wrong Points Operator"
        ); // TODO: update from deployer

        // --------------------------------------------
        /* Execution Delegate Sanity Check */
        // --------------------------------------------
        // Check Default Admin role
        require(
            executionDelegate.hasRole(executionDelegate.DEFAULT_ADMIN_ROLE(), governanceAddress),
            "ExecutionDelegate has the wrong Default Admin"
        );
        // Check Pauser role
        require(
            executionDelegate.hasRole(executionDelegate.PAUSER_ROLE(), pauserAddress),
            "ExecutionDelegate has the wrong Pauser"
        );
        // Check Exchange is whitelisted
        require(executionDelegate.contracts(exchangeAddress), "ExecutionDelegate has not whitelisted the Exchange");
        // Check Minter is whitelisted
        require(executionDelegate.contracts(minterAddress), "ExecutionDelegate has not whitelisted the Exchange");
        // Check Gas Governor
        require(
            blastGas.governorMap(executionDelegateAddress) == deployerAddress,
            "ExecutionDelegate has the wrong Gas Governor"
        ); // TODO: update from deployer
        // Check Points Operator
        require(
            blastPoints.operators(executionDelegateAddress) == deployerAddress,
            "ExecutionDelegate has the wrong Points Operator"
        ); // TODO: update from deployer

        // --------------------------------------------
        /* Minter Sanity Check */
        // --------------------------------------------
        // Check Default Admin role
        require(minter.hasRole(minter.DEFAULT_ADMIN_ROLE(), governanceAddress), "Minter has the wrong Default Admin");
        // Check Treasury
        require(minter.treasury() == treasuryAddress, "Minter has the wrong Treasury");
        // Check Execution Delegate
        require(
            address(minter.executionDelegate()) == executionDelegateAddress,
            "Minter has the wrong ExecutionDelegate"
        );
        // Check Mint Config Master
        require(
            minter.hasRole(minter.MINT_CONFIG_MASTER(), mintConfigMasterAddress),
            "Minter has the wrong Mint Config Master"
        );
        // Check Cards required for burn to Draw
        require(
            minter.cardsRequiredForBurnToDraw() == cardsRequiredForBurnToDraw,
            "Minter has the wrong number of Cards required for burn to draw"
        );
        // Check Cards required for level up
        require(
            minter.cardsRequiredForLevelUp() == cardsRequiredForLevelUp,
            "Minter has the wrong number of Cards required for burn to draw"
        );
        // Check Cards Drawn Per Burn
        require(minter.cardsDrawnPerBurn() == cardsDrawnPerBurn, "Minter has the wrong number of Cards drawn per burn");
        // Check Gas Governor
        require(blastGas.governorMap(minterAddress) == deployerAddress, "Minter has the wrong Gas Governor"); // TODO: update from deployer
        // Check Points Operator
        require(blastPoints.operators(minterAddress) == deployerAddress, "Minter has the wrong Points Operator"); // TODO: update from deployer

        // --------------------------------------------
        /* Exchange Sanity Check */
        // --------------------------------------------
        // Check Default Admin role
        require(exchange.owner() == governanceAddress, "Exchange has the wrong Default Admin");
        // Check Treasury
        require(
            exchange.protocolFeeRecipient() == treasuryAddress,
            "Exchange has the wrong Treasury (aka protocolFeeRecipient)"
        );
        // Check Execution Delegate
        require(
            address(exchange.executionDelegate()) == executionDelegateAddress,
            "Exchange has the wrong ExecutionDelegate"
        );
        // Check WETH whitelist
        require(exchange.whitelistedPaymentTokens(wethAddress), "Exchange has not whitelisted WETH");
        // Check WETH minimum price
        require(
            exchange.minimumPricePerPaymentToken(wethAddress) == minimumPricePerPaymentToken,
            "Exchange has the wrong minimum price for WETH"
        );
        // Check Protocol Fee Bps
        require(exchange.protocolFeeBps() == protocolFeeBps, "Exchange has the wrong protocolFeeBps");
        // Check Fantasy Cards is whitelisted
        require(exchange.whitelistedCollections(fantasyCardsAddress), "Exchange has not whitelisted FantasyCards");
        // Check Gas Governor
        require(blastGas.governorMap(exchangeAddress) == deployerAddress, "Exchange has the wrong Gas Governor"); // TODO: update from deployer
        // Check Points Operator
        require(blastPoints.operators(exchangeAddress) == deployerAddress, "Exchange has the wrong Points Operator"); // TODO: update from deployer
    }
}

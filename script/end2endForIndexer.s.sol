pragma solidity ^0.8.20;

import "../lib/forge-std/src/Script.sol";
import "../lib/forge-std/src/console.sol";

import "../src/FantasyCards.sol";
import "../src/Exchange.sol";
import "../src/ExecutionDelegate.sol";
import "../src/Minter.sol";
import "../test/tokens/WrappedETH.sol";
import "../src/libraries/OrderLib.sol";
import "../test/helpers/HashLib.sol";

contract End2endForIndexer is Script {
    FantasyCards fantasyCards = FantasyCards(0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512);
    Exchange exchange = Exchange(0x5FC8d32690cc91D4c39d9d3abcBD16989F875707);
    ExecutionDelegate executionDelegate = ExecutionDelegate(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
    Minter minter = Minter(0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9);
    WrappedETH weth = WrappedETH(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0);

    uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 treasuryPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 user1PrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 user2PrivateKey = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;

    address deployer = vm.addr(deployerPrivateKey);
    address treasury = vm.addr(treasuryPrivateKey);
    address user1 = vm.addr(user1PrivateKey);
    address user2 = vm.addr(user2PrivateKey);

    bytes32 merkleRoot;
    bytes32[] merkleProof = new bytes32[](2);

    function newMintConfig() internal {
        address collection = address(fantasyCards);
        uint256 cardsPerPack = 1;
        uint256 maxPacks = 100;
        address paymentToken = address(weth);
        uint256 fixedPrice = 1 ether;
        uint256 maxPacksPerAddress = 0;
        bool requiresWhitelist = false;
        bytes32 _merkleRoot = 0x3000000000000000000000000000000000000000000000000000000000000000;
        uint256 startTimestamp = 0;
        uint256 expirationTimestamp = 9999999999999999999999;

        minter.newMintConfig(
            collection,
            cardsPerPack,
            maxPacks,
            paymentToken,
            fixedPrice,
            maxPacksPerAddress,
            requiresWhitelist,
            _merkleRoot,
            startTimestamp,
            expirationTimestamp
        );
    }

    function run() external {
        // Create new mint config
        vm.startBroadcast(deployerPrivateKey);
        newMintConfig();
        vm.stopBroadcast();

        // User1 buys a pack
        vm.startBroadcast(user1PrivateKey);
        weth.getFaucet(1 ether);
        weth.approve(address(executionDelegate), 1 ether);
        minter.mint(0, new bytes32[](0), 1 ether);
        vm.stopBroadcast();

        // User2 buys a pack
        vm.startBroadcast(user2PrivateKey);
        weth.getFaucet(1 ether);
        weth.approve(address(executionDelegate), 1 ether);
        minter.mint(0, new bytes32[](0), 1 ether);
        vm.stopBroadcast();

        //User1 lists a card for sale
        uint256 tokenId = 0;
        uint256 price = 1 ether;
        vm.startBroadcast(user1PrivateKey);
        fantasyCards.approve(address(executionDelegate), tokenId);
        vm.stopBroadcast();

        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            tokenId,
            address(weth),
            price,
            999999999999999999999,
            bytes32(0),
            0
        );
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        // User2 buys the card
        vm.startBroadcast(user2PrivateKey);
        weth.getFaucet(sellOrder.price);
        weth.approve(address(executionDelegate), sellOrder.price);
        exchange.buy(sellOrder, sellerSignature, false);
        vm.stopBroadcast();

        // User1 bids on a card
        merkleRoot = 0x2c24f92f65cdd0fde0264c1f41fadf17cb35cdffeaca769e5673e72b072be707; // Merkle root for ids 0 , 1, 2 and 3
        OrderLib.Order memory buyOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Buy,
            address(fantasyCards),
            tokenId,
            address(weth),
            price,
            999999999999999999999,
            merkleRoot,
            0
        );
        bytes32 buyOrderHash = HashLib.getTypedDataHash(buyOrder, exchange.domainSeparator());
        (uint8 vBuyer, bytes32 rBuyer, bytes32 sBuyer) = vm.sign(user1PrivateKey, buyOrderHash);
        bytes memory buyerSignature = abi.encodePacked(rBuyer, sBuyer, vBuyer);
        vm.startBroadcast(user1PrivateKey);
        weth.getFaucet(price);
        weth.approve(address(executionDelegate), price);
        vm.stopBroadcast();

        // User2 sells the card into the bid of user1
        merkleProof[0] = 0xb10e2d527612073b26eecdfd717e6a320cf44b4afac2b0732d9fcbe2b7fa0cf6;
        merkleProof[1] = 0xc5fd106a8e5214837c622e5fdef112b1d83ad6de66beafb53451c77843c9d04e;
        vm.startBroadcast(user2PrivateKey);
        fantasyCards.approve(address(executionDelegate), 0);
        exchange.sell(buyOrder, buyerSignature, 0, merkleProof);
        vm.stopBroadcast();
    }
}

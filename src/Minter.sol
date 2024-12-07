/**                                                                                                                                     
    ______            __                  
   / ____/___ _____  / /_____ ________  __
  / /_  / __ `/ __ \/ __/ __ `/ ___/ / / /
 / __/ / /_/ / / / / /_/ /_/ (__  ) /_/ / 
/_/    \__,_/_/ /_/\__/\__,_/____/\__, /  
                                 /____/   

**/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./VRGDA/LinearVRGDA.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";
import "./interfaces/IExecutionDelegate.sol";
import "./interfaces/IFantasyCards.sol";
import "./interfaces/IMinter.sol";
import {wadLn} from "solmate/utils/SignedWadMath.sol";
import {toTimeUnitWadUnsafe} from "./VRGDA/wadMath.sol";

/// @title A contract for minting Fantasy Cards NFTs using VRGDA pricing
contract Minter is IMinter, AccessControlDefaultAdminRules, ReentrancyGuard, LinearVRGDA {
    /// @notice Configuration for a mint operation
    struct MintConfig {
        address collection; // The collection address of the NFT
        uint256 cardsPerPack; // Number of cards per pack
        uint256 maxPacks; // Total number of packs available for minting
        address paymentToken; // Token used for payments (address(0) for ETH)
        VRGDAConfig vrgdaConfig; // VRGDA configuration
        uint256 fixedPrice; // Setting this parameter to a positive non zero value will disable the VRGDA mechanism
        uint256 maxPacksPerAddress; // Maximum number of packs that can be minted by a single address
        bool requiresWhitelist; // If true, requires user to be whitelisted
        bytes32 merkleRoot; // Root of Merkle tree for whitelist verification
        uint256 startTimestamp; // Start time for the mint config
        uint256 expirationTimestamp; // Expiration timestamp for the mint config
        mapping(address => uint256) amountMintedPerAddress; // Tracks how many packs have been minted by each address
        uint256 totalMintedPacks; // Total number of packs minted
        bool cancelled; // If true, mint config has been cancelled
    }

    /// @notice Role hash for the address allowed to cancel mintConfigs
    bytes32 public constant MINT_CONFIG_MASTER = keccak256("MINT_CONFIG_MASTER");

    /* Variables */
    mapping(uint256 mintConfigId => MintConfig) public mintConfigs;
    mapping(address collection => bool) public whitelistedCollections;
    address public treasury;
    IExecutionDelegate public executionDelegate;
    uint256 public mintConfigIdCounter;
    uint256 public cardsRequiredForLevelUp;
    uint256 public cardsRequiredForBurnToDraw;
    uint256 public cardsDrawnPerBurn;

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Function can only be called by an EOA");
        _;
    }

    /**
     * @dev Initializes the contract with treasury and execution delegate addresses.
     * @param _treasury Treasury address.
     * @param _executionDelegate Execution delegate address.
     */
    constructor(
        address _treasury,
        address _executionDelegate,
        uint256 _cardsRequiredForLevelUp,
        uint256 _cardsRequiredForBurnToDraw,
        uint256 _cardsDrawnPerBurn
    ) AccessControlDefaultAdminRules(0, msg.sender) {
        IBlast(0x4300000000000000000000000000000000000002).configureClaimableGas();
        IBlast(0x4300000000000000000000000000000000000002).configureGovernor(msg.sender);
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800).configurePointsOperator(msg.sender);

        _setTreasury(_treasury);
        _setExecutionDelegate(_executionDelegate);
        _setcardsRequiredForLevelUp(_cardsRequiredForLevelUp);
        _setcardsRequiredForBurnToDraw(_cardsRequiredForBurnToDraw);
        _setcardsDrawnPerBurn(_cardsDrawnPerBurn);
    }

    /**
     * @notice Mints packs based on the specified mint configuration
     * @dev Requires the mint configuration not to be cancelled, the user to be whitelisted (if applicable), and not to have minted before (if applicable). Transfers the payment and mints the NFTs.
     * @param configId ID of the mint configuration to use
     * @param merkleProof Proof for whitelist verification, if required
     * @param maxPrice Maximum price the user is willing to pay
     */
    function mint(
        uint256 configId,
        bytes32[] calldata merkleProof,
        uint256 maxPrice
    ) public payable nonReentrant onlyEOA {
        MintConfig storage mintConfig = mintConfigs[configId];
        require(mintConfig.startTimestamp <= block.timestamp, "Mint config not started");
        require(
            mintConfig.expirationTimestamp == 0 || mintConfig.expirationTimestamp > block.timestamp,
            "Mint config expired"
        );
        require(!mintConfig.cancelled, "Mint config cancelled");
        require(
            !mintConfig.requiresWhitelist || _verifyWhitelist(mintConfig.merkleRoot, merkleProof, msg.sender),
            "User not whitelisted"
        );
        require(
            mintConfig.maxPacksPerAddress == 0 ||
                mintConfig.amountMintedPerAddress[msg.sender] < mintConfig.maxPacksPerAddress,
            "User reached max mint limit"
        );
        require(mintConfig.maxPacks > mintConfig.totalMintedPacks, "No packs left");

        // compute the price before incrementing the total packs minted since it will push the price up otherwise
        uint256 price = getPackPrice(configId);
        require(price <= maxPrice, "Price too high");

        mintConfig.totalMintedPacks += 1;
        mintConfig.amountMintedPerAddress[msg.sender] += 1;

        _executeFundsTransfer(mintConfig.paymentToken, msg.sender, treasury, price);

        uint256 firstTokenId = IFantasyCards(mintConfig.collection).tokenCounter();

        _executeBatchMint(mintConfig.collection, mintConfig.cardsPerPack, msg.sender);

        emit Mint(
            configId,
            msg.sender,
            mintConfig.totalMintedPacks,
            firstTokenId,
            firstTokenId + mintConfig.cardsPerPack - 1,
            price
        );
    }

    /**
     * @notice Admin function to mints packs based on the specified mint configuration to multiple recipients
     * @dev Requires the mint configuration not to be cancelled, the user to be whitelisted (if applicable), and not to have minted before (if applicable). Transfers the payment and mints the NFTs.
     * @param configId ID of the mint configuration to use
     * @param merkleProofs Proofs for whitelist verifications, if required
     * @param maxPrice Maximum price the user is willing to pay
     * @param recipients Addresses to mint packs to
     */
    function batchMintCardsTo(uint256 configId, bytes32[][] calldata merkleProofs, uint256 maxPrice, address[] calldata recipients) public payable nonReentrant onlyEOA onlyRole(MINT_CONFIG_MASTER) {
        for (uint i = 0; i < recipients.length; i++) {
            _mintCardsTo(configId, merkleProofs[i], maxPrice, recipients[i]);
        }
    }

    /**
     * @dev Internal function to mint packs based on the specified mint configuration to a single recipient. This function is a very close cousin of the mint function.
     * @param configId ID of the mint configuration to use
     * @param merkleProof Proof for whitelist verification, if required
     * @param maxPrice Maximum price the user is willing to pay
     * @param recipient Address to mint packs to
     */
    function _mintCardsTo(uint256 configId, bytes32[] calldata merkleProof, uint256 maxPrice, address recipient) internal {
        MintConfig storage mintConfig = mintConfigs[configId];
        require(mintConfig.startTimestamp <= block.timestamp, "Mint config not started");
        require(
            mintConfig.expirationTimestamp == 0 || mintConfig.expirationTimestamp > block.timestamp,
            "Mint config expired"
        );
        require(!mintConfig.cancelled, "Mint config cancelled");
        require(
            !mintConfig.requiresWhitelist || _verifyWhitelist(mintConfig.merkleRoot, merkleProof, recipient),
            "User not whitelisted"
        );
        require(
            mintConfig.maxPacksPerAddress == 0 ||
                mintConfig.amountMintedPerAddress[recipient] < mintConfig.maxPacksPerAddress,
            "User reached max mint limit"
        );
        require(mintConfig.maxPacks > mintConfig.totalMintedPacks, "No packs left");

        // compute the price before incrementing the total packs minted since it will push the price up otherwise
        uint256 price = getPackPrice(configId);
        require(price <= maxPrice, "Price too high");

        mintConfig.totalMintedPacks += 1;
        mintConfig.amountMintedPerAddress[recipient] += 1;

        _executeFundsTransfer(mintConfig.paymentToken, recipient, treasury, price);

        uint256 firstTokenId = IFantasyCards(mintConfig.collection).tokenCounter();

        _executeBatchMint(mintConfig.collection, mintConfig.cardsPerPack, recipient);

        emit Mint(
            configId,
            recipient,
            mintConfig.totalMintedPacks,
            firstTokenId,
            firstTokenId + mintConfig.cardsPerPack - 1,
            price
        );
    }

    /**
     * @notice Creates a new mint configuration
     * @dev Only callable by the contract owner. Emits a NewMintConfig event upon success.
     * @param collection Address of the NFT collection for the packs
     * @param cardsPerPack Number of cards in each pack
     * @param maxPacks Maximum number of packs available for this configuration
     * @param paymentToken Token used for payments (address(0) for ETH)
     * @param fixedPrice The amount of paymentToken payed by the user to mint
     * @param maxPacksPerAddress Maximum number of packs that can be minted by a single address
     * @param requiresWhitelist Require users to be whitelisted if true
     * @param merkleRoot Root of Merkle tree for whitelist verification
     * @param startTimestamp Timestamp before which the mintConfig is not usable, also used to determine pricing for VRGDA mintConfigs
     * @param expirationTimestamp Expiration timestamp for the mint config
     */
    function newMintConfig(
        address collection,
        uint256 cardsPerPack,
        uint256 maxPacks,
        address paymentToken,
        uint256 fixedPrice,
        uint256 maxPacksPerAddress,
        bool requiresWhitelist,
        bytes32 merkleRoot,
        uint256 startTimestamp,
        uint256 expirationTimestamp
    ) public onlyRole(MINT_CONFIG_MASTER) {
        require(whitelistedCollections[collection], "Collection is not whitelisted");
        require(collection != address(0), "Collection address cannot be 0x0");
        require(cardsPerPack > 0, "Cards per pack must be greater than 0");
        require(maxPacks > 0, "Max packs must be greater than 0");
        require(startTimestamp >= block.timestamp, "Mint must start immediately or in the future");
        require(expirationTimestamp == 0 || expirationTimestamp > startTimestamp, "invalid expirationTimestamp");
        if (requiresWhitelist) {
            require(merkleRoot != 0, "missing merkleRoot");
        }

        MintConfig storage config = mintConfigs[mintConfigIdCounter];
        config.collection = collection;
        config.cardsPerPack = cardsPerPack;
        config.maxPacks = maxPacks;
        config.paymentToken = paymentToken;
        config.fixedPrice = fixedPrice;
        config.maxPacksPerAddress = maxPacksPerAddress;
        config.requiresWhitelist = requiresWhitelist;
        config.merkleRoot = merkleRoot;
        config.startTimestamp = startTimestamp;
        config.expirationTimestamp = expirationTimestamp;

        emit NewMintConfig(
            mintConfigIdCounter,
            collection,
            cardsPerPack,
            maxPacks,
            paymentToken,
            fixedPrice,
            maxPacksPerAddress,
            requiresWhitelist,
            merkleRoot,
            expirationTimestamp
        );

        mintConfigIdCounter++;
    }

    /**
     * @notice Gets the current pack price based on the VRGDA contract
     * @dev The price will depend on the start time, target price and decay constant
     * @param configId ID of the mint configuration to use
     */
    function getPackPrice(uint256 configId) public view returns (uint256) {
        MintConfig storage mintConfig = mintConfigs[configId];
        require(!mintConfig.cancelled, "Mint config cancelled");

        // If no VRGDA configuration is set, return the fixed price
        if (mintConfig.vrgdaConfig.targetPrice == 0) {
            return mintConfig.fixedPrice;
        }

        VRGDAConfig memory vrgdaConfig = mintConfig.vrgdaConfig;
        require((block.timestamp - mintConfig.startTimestamp) >= 0, "INVALID_TIMESTAMP");
        unchecked {
            return
                getVRGDAPrice(
                    toTimeUnitWadUnsafe(block.timestamp - mintConfig.startTimestamp, vrgdaConfig.secondsPerTimeUnit),
                    mintConfig.totalMintedPacks,
                    vrgdaConfig.targetPrice,
                    vrgdaConfig.priceDecayPercent,
                    vrgdaConfig.perTimeUnit
                );
        }
    }

    /**
     * @notice Allows a user to upgrade their hero card to the next level of rarity by burning a specified number of cards of the same hero and rarity.
     * @dev Burns the specified amount of cards (tokens) of the same hero and rarity to mint a new card of that hero with increased rarity. The levelUp happens at the metadata level. if tokenIds are not of the same hero and rarity, or if the 5 cards are at the maximum rarity level (legendary), the newly minted card will not receive any metadata.
     * @param tokenIds An array of token IDs representing the cards to be burned. All cards must be of the same hero and the same rarity.
     * @param collection The address of the NFT collection from which the cards will be burned and the new card will be minted.
     */
    function levelUp(uint256[] calldata tokenIds, address collection) public {
        require(whitelistedCollections[collection], "Collection is not whitelisted");
        require(tokenIds.length == cardsRequiredForLevelUp, "wrong amount of cards to level up");

        for (uint i = 0; i < cardsRequiredForLevelUp; i++) {
            require(
                IFantasyCards(collection).ownerOf(tokenIds[i]) == msg.sender,
                "caller does not own one of the tokens"
            );
            executionDelegate.burnFantasyCard(address(collection), tokenIds[i]);
        }

        uint256 mintedTokenId = IFantasyCards(collection).tokenCounter();
        executionDelegate.mintFantasyCard(address(collection), msg.sender);

        emit LevelUp(tokenIds, mintedTokenId, collection, msg.sender);
    }

    /**
     * @notice Allows a user to burn their hero cards to draw new random cards. This function is provided for backward compatibility and convenience, although similar functionality can be achieved using
     * `batchBurnToDraw` with an array containing a single burn.
     * @dev Burns the specified amount of cards to draw new cards. The burnToDraw happens at the metadata level. Using this method directly might result in loss of cards if the cards do not meet the game rules.
     * @param tokenIds An array of token IDs representing the cards to be burned.
     * @param collection The address of the NFT collection from which the cards will be burned and the new card(s) will be minted.
     */
    function burnToDraw(uint256[] calldata tokenIds, address collection) public {
       _burnToDraw(tokenIds, collection);
    }

    /**
     * @notice Allows a user to burn multiple sets of cards to draw new cards
     * @param tokenIds An array of token IDs arrays representing the cards to be burned. Each internal array represents a different burn.
     * @param collection The address of the NFT collection from which the cards will be burned and the new card(s) will be minted.
     */
    function batchBurnToDraw(uint256[][] calldata tokenIds, address collection) public {
        for (uint i = 0; i < tokenIds.length; i++) {
            _burnToDraw(tokenIds[i], collection);
        }
    }

    /**
     * @dev Internal function to burn cards to draw new cards
     * @param tokenIds An array of token IDs representing the cards to be burned
     * @param collection The address of the NFT collection from which the cards will be burned and the new card(s) will be minted.
    */
    function _burnToDraw(uint256[] calldata tokenIds, address collection) internal {
        require(whitelistedCollections[collection], "Collection is not whitelisted");
        require(tokenIds.length == cardsRequiredForBurnToDraw, "wrong amount of cards to draw new cards");

        for (uint i = 0; i < cardsRequiredForBurnToDraw; i++) {
            require(
                IFantasyCards(collection).ownerOf(tokenIds[i]) == msg.sender,
                "caller does not own one of the tokens"
            );
            executionDelegate.burnFantasyCard(address(collection), tokenIds[i]);
        }

        uint256[] memory drawnCardIds = new uint256[](cardsDrawnPerBurn);

        for (uint i = 0; i < cardsDrawnPerBurn; i++) {
            uint256 mintedTokenId = IFantasyCards(collection).tokenCounter();
            executionDelegate.mintFantasyCard(address(collection), msg.sender);
            drawnCardIds[i] = mintedTokenId;
        }

        emit BurnToDraw(tokenIds, drawnCardIds, collection, msg.sender);
    }


    /**
     * @notice Burns multiple cards in a single transaction
     * @dev Iterates through the list of tokenIds and burns each one
     * @param collection The address of the collection from which the cards will be burned
     * @param tokenIds The array of tokenIds to be burned
     */
    function batchBurn(address collection, uint256[] calldata tokenIds) public {
        require(tokenIds.length > 0, "no tokens to burn");
        require(whitelistedCollections[collection], "Collection is not whitelisted");
        // check that the caller owns all the tokens
        for (uint i = 0; i < tokenIds.length; i++) {
            require(IFantasyCards(collection).ownerOf(tokenIds[i]) == msg.sender, "caller does not own one of the tokens");
        }
        for (uint i = 0; i < tokenIds.length; i++) {
            executionDelegate.burnFantasyCard(address(collection), tokenIds[i]);
        }
        emit BatchBurn(tokenIds, collection, msg.sender);
    }


    /**
     * @notice Updates the NFT collection address for a specific mint configuration
     * @dev Only callable by the contract owner.
     * @param mintConfigId The ID of the mint configuration to update
     * @param collection The new collection address
     */
    function setCollectionForMintConfig(uint256 mintConfigId, address collection) public onlyRole(MINT_CONFIG_MASTER) {
        require(whitelistedCollections[collection], "Collection is not whitelisted");
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        require(collection != address(0), "Collection address cannot the zero address");

        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.collection = collection;

        emit CollectionUpdatedForMintConfig(mintConfigId, collection);
    }

    /**
     * @notice Updates the number of cards per pack for a specific mint configuration
     * @dev Only callable by the contract owner.
     * @param mintConfigId The ID of the mint configuration to update
     * @param cardsPerPack The new number of cards per pack
     */
    function setCardsPerPackForMintConfig(
        uint256 mintConfigId,
        uint256 cardsPerPack
    ) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        require(cardsPerPack > 0, "Cards per pack must be greater than 0");
        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.cardsPerPack = cardsPerPack;

        emit CardsPerPackUpdatedForMintConfig(mintConfigId, cardsPerPack);
    }

    /**
     * @notice Updates the total number of packs for a specific mint configuration
     * @dev Only callable by the contract owner.
     * @param mintConfigId The ID of the mint configuration to update
     * @param maxPacks The maximum number of packs available
     */
    function setMaxPacksForMintConfig(uint256 mintConfigId, uint256 maxPacks) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        require(maxPacks > 0, "Maximum packs must be greater than 0");
        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.maxPacks = maxPacks;

        emit MaxPacksUpdatedForMintConfig(mintConfigId, maxPacks);
    }

    /**
     * @notice Will set a fixed price for a specific mint configuration. If no fixed price was set before, it will also disable the VRGDA mechanism
     * @dev Only callable by the contract owner.
     * @param mintConfigId The ID of the mint configuration to update
     * @param fixedPrice A non zero positive value will disable the VRGDA mechanism and set a fixed price for the pack. This price input should be inputed with the correct token decimals coresponding to the payment token used in the mintconfig
     */
    function setFixedPriceForMintConfig(uint256 mintConfigId, uint256 fixedPrice) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.fixedPrice = fixedPrice;
        // Disable VRGDA mechanism if any
        config.vrgdaConfig.targetPrice = 0;
        emit FixedPriceUpdatedForMintConfig(mintConfigId, fixedPrice);
    }

    /**
     * @notice Updates the VRGDA config for a specific mint configuration, will require the mint config to not have an eth payment token (0 address)
     * @dev Only callable by the admin
     * @param mintConfigId The ID of the mint configuration to update
     * @param targetPrice The target price for a pack if sold on pace, scaled by the token decimals, e.g 1e18 for 1 ether, 1e6 for 1 usdc
     * @param priceDecayPercent The percent price decays per unit of time with no sales, scaled by 1e18, e.g 3e17 for 30%
     * @param perTimeUnit The targeted number of packs to sell in 1 full unit of time, scaled by 1e18, e.g 1e18 for 1 pack
     * @param secondsPerTimeUnit The total number of seconds in a time unit. 60 for a minute, 3600 for an hour, 86400 for a day.
     */
    function setVRGDAForMintConfig(
        uint256 mintConfigId,
        int256 targetPrice,
        int256 priceDecayPercent,
        int256 perTimeUnit,
        int256 secondsPerTimeUnit
    ) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        require(targetPrice > 0, "Non zero target price");
        require(secondsPerTimeUnit > 0, "Non zero seconds per time unit");
        int256 decayConstant = wadLn(1e18 - priceDecayPercent);

        // The decay constant must be negative for VRGDAs to work.
        require(decayConstant < 0, "NON_NEGATIVE_DECAY_CONSTANT");

        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        require(config.paymentToken != address(0), "Payment token cannot be ETH");

        VRGDAConfig memory newVrgdaConfig = VRGDAConfig({
            targetPrice: targetPrice,
            priceDecayPercent: priceDecayPercent,
            perTimeUnit: perTimeUnit,
            secondsPerTimeUnit: secondsPerTimeUnit
        });

        // update the VRGDA config
        config.vrgdaConfig = newVrgdaConfig;

        // set the fixed price to 0
        config.fixedPrice = 0;

        emit VRGDAUpdatedForMintConfig(mintConfigId, targetPrice, priceDecayPercent, perTimeUnit);
    }

    /**
     * @notice Updates the one per address restriction for a specific mint configuration
     * @dev Only callable by the contract owner.
     * @param mintConfigId The ID of the mint configuration to update
     * @param maxPacksPerAddress The new maximum number of packs that can be minted by a single address
     */
    function setMaxPacksPerAddressForMintConfig(
        uint256 mintConfigId,
        uint256 maxPacksPerAddress
    ) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.maxPacksPerAddress = maxPacksPerAddress;

        emit MaxPacksPerAddressUpdatedForMintConfig(mintConfigId, maxPacksPerAddress);
    }

    /**
     * @notice Updates the whitelist requirement for a specific mint configuration
     * @dev Only callable by the contract owner.
     * @param mintConfigId The ID of the mint configuration to update
     * @param requiresWhitelist The new whitelist requirement state
     */
    function setRequiresWhitelistForMintConfig(
        uint256 mintConfigId,
        bool requiresWhitelist
    ) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.requiresWhitelist = requiresWhitelist;

        emit WhitelistRequirementUpdatedForMintConfig(mintConfigId, requiresWhitelist);
    }

    /**
     * @notice Updates the merkle root for whitelist verification for a specific mint configuration
     * @dev Only callable by the contract owner.
     * @param mintConfigId The ID of the mint configuration to update
     * @param merkleRoot The new merkle root for whitelist verification
     */
    function setMerkleRootForMintConfig(uint256 mintConfigId, bytes32 merkleRoot) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");
        require(merkleRoot != bytes32(0), "Invalid merkleRoot");

        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.merkleRoot = merkleRoot;

        emit MerkleRootUpdatedForMintConfig(mintConfigId, merkleRoot);
    }

    /**
     * @notice Sets the expiration timestamp for a specific mint configuration, after which minting is no longer allowed.
     * @dev Only callable by the contract owner. Useful for time-limited minting opportunities.
     * @param mintConfigId The ID of the mint configuration to update.
     * @param expirationTimestamp The UNIX timestamp at which the minting configuration expires.
     */
    function setExpirationTimestampForMintConfig(
        uint256 mintConfigId,
        uint256 expirationTimestamp
    ) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");

        MintConfig storage config = mintConfigs[mintConfigId];
        require(!config.cancelled, "Mint config cancelled");
        config.expirationTimestamp = expirationTimestamp;

        emit ExpirationTimestampUpdatedForMintConfig(mintConfigId, expirationTimestamp);
    }

    /**
     * @notice Cancels a specific mint configuration, preventing further minting
     * @param mintConfigId The ID of the mint configuration to cancel
     */
    function cancelMintConfig(uint256 mintConfigId) public onlyRole(MINT_CONFIG_MASTER) {
        require(mintConfigId < mintConfigIdCounter, "Invalid mintConfigId");

        MintConfig storage config = mintConfigs[mintConfigId];
        config.cancelled = true;

        emit MintConfigCancelled(mintConfigId);
    }

    /**
     * @notice Updates the number of cards required for the level-up operation.
     * @dev Only callable by the contract owner. Adjusts how many cards must be burned to mint a new one in the level-up process.
     * @param _cardsRequiredForLevelUp The new number of cards required to perform a level-up.
     */
    function setcardsRequiredForLevelUp(uint256 _cardsRequiredForLevelUp) public onlyRole(MINT_CONFIG_MASTER) {
        _setcardsRequiredForLevelUp(_cardsRequiredForLevelUp);
    }

    /**
     * @notice Updates the number of cards required for the burn to draw operation.
     * @dev Only callable by the contract owner. Adjusts how many cards must be burned to mint during the burn to draw process
     * @param _cardsRequiredForBurnToDraw The new number of cards required to perform a burn to draw.
     */
    function setcardsRequiredForBurnToDraw(uint256 _cardsRequiredForBurnToDraw) public onlyRole(MINT_CONFIG_MASTER) {
        _setcardsRequiredForBurnToDraw(_cardsRequiredForBurnToDraw);
    }

    /**
     * @notice Updates the number of cards that will be minted during the burn to draw operation.
     * @dev Only callable by the contract owner. Adjusts how many cards will be minted during the burn to draw process
     * @param _cardsDrawnPerBurn The new number of cards minted during the burn to draw process
     */
    function setcardsDrawnPerBurn(uint256 _cardsDrawnPerBurn) public onlyRole(MINT_CONFIG_MASTER) {
        _setcardsDrawnPerBurn(_cardsDrawnPerBurn);
    }

    /**
     * @notice Sets a new treasury address for collecting payments from minting operations.
     * @param _treasury The address of the new treasury. Must be a non-zero address.
     */
    function setTreasury(address _treasury) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTreasury(_treasury);
    }

    /**
     * @notice Updates the execution delegate address.
     * @param _executionDelegate New delegate address.
     */
    function setExecutionDelegate(address _executionDelegate) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setExecutionDelegate(_executionDelegate);
    }

    /**
     * @dev Function to retrieve funds mistakenly sent to the mint contract.
     * @param paymentToken ERC20 token address, or zero for Ether.
     * @param to Recipient's address.
     * @param amount Transfer amount.
     */
    function saveFunds(address paymentToken, address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (paymentToken == address(0)) {
            payable(to).transfer(amount);
        } else {
            ERC20(paymentToken).transfer(to, amount);
        }
    }

    /**
     * @notice Whitelists a collection for levelUp or burnToDraw
     * @dev Only callable by the contract Admin.
     * @param _collection The address of the ERC-721 token collection to whitelist
     */
    function whiteListCollection(address _collection) public onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedCollections[_collection] = true;

        emit NewWhitelistedCollection(_collection);
    }

    /**
     * @notice Removes a collection from the whitelists for levelUp or burnToDraw
     * @dev Only callable by the contract Admin.
     * @param _collection The address of the ERC-721 token collection to remove from the whitelist
     */
    function unWhiteListCollection(address _collection) public onlyRole(DEFAULT_ADMIN_ROLE) {
        whitelistedCollections[_collection] = false;

        emit UnWhitelistedCollection(_collection);
    }

    /**
     * @notice Retrieves details of a specific mint configuration
     * @param mintConfigId The ID of the mint configuration to retrieve
     * @return collection The NFT collection address
     * @return cardsPerPack The number of cards per pack
     * @return maxPacks The maximum number of packs available
     * @return paymentToken The token used for payments
     * @return fixedPrice The current fixed price for the packs. 0 if VRGDA is enabled
     * @return maxPacksPerAddress The maximum number of packs that can be minted by a single address
     * @return requiresWhitelist The whitelist requirement state
     * @return merkleRoot The merkle root for whitelist verification
     * @return startTimestamp The start timestamp for the mint configuration
     * @return expirationTimestamp The expiration timestamp for the mint configuration
     * @return totalMintedPacks The total number of packs minted
     * @return cancelled The cancellation state of the mint configuration
     */
    function getMintConfig(
        uint256 mintConfigId
    )
        public
        view
        returns (address, uint256, uint256, address, uint256, uint256, bool, bytes32, uint256, uint256, uint256, bool)
    {
        MintConfig storage config = mintConfigs[mintConfigId];
        return (
            config.collection,
            config.cardsPerPack,
            config.maxPacks,
            config.paymentToken,
            config.fixedPrice,
            config.maxPacksPerAddress,
            config.requiresWhitelist,
            config.merkleRoot,
            config.startTimestamp,
            config.expirationTimestamp,
            config.totalMintedPacks,
            config.cancelled
        );
    }

    /**
     * @notice Checks if a user has already minted from a specific mint configuration
     * @param mintConfigId The ID of the mint configuration to check
     * @param user The address of the user to check
     * @return hasMinted Whether the user has already minted
     */
    function getAmountMintedPerAddressForMintConfig(uint256 mintConfigId, address user) public view returns (uint256) {
        MintConfig storage config = mintConfigs[mintConfigId];
        return config.amountMintedPerAddress[user];
    }

    /**
     * @notice Returns the VRGDA configuration for a mint configuration. Reverts if fixed price is set
     * @param mintConfigId The ID of the mint configuration to check
     * @return vrgdaConfig The VRGDA configuration
     */
    function getVRGDAConfig(uint256 mintConfigId) public view returns (VRGDAConfig memory) {
        MintConfig storage config = mintConfigs[mintConfigId];
        require(config.fixedPrice == 0, "VRGDA not enabled");
        return config.vrgdaConfig;
    }

    /**
     * @notice Internal function that sets a new treasury address for collecting payments from minting operations.
     * @param _treasury The address of the new treasury. Must be a non-zero address.
     */
    function _setTreasury(address _treasury) internal {
        require(_treasury != address(0), "Treasury address cannot be 0x0");
        treasury = _treasury;

        emit NewTreasury(_treasury);
    }

    /**
     * @notice Internal function that updates the execution delegate address.
     * @param _executionDelegate New delegate address.
     */
    function _setExecutionDelegate(address _executionDelegate) internal {
        require(_executionDelegate != address(0), "Execution delegate address cannot be 0x0");
        executionDelegate = IExecutionDelegate(_executionDelegate);

        emit NewExecutionDelegate(_executionDelegate);
    }

    /**
     * @notice Internal function that sets the number of cards required for a level up.
     * @param _cardsRequiredForLevelUp The number of cards required for a level up.
     */
    function _setcardsRequiredForLevelUp(uint256 _cardsRequiredForLevelUp) internal {
        require(_cardsRequiredForLevelUp > 0, "cardsRequiredForLevelUp must be greater than 0");
        cardsRequiredForLevelUp = _cardsRequiredForLevelUp;

        emit NewNumberOfCardsRequiredForLevelUp(_cardsRequiredForLevelUp);
    }

    /**
     * @notice Internal function that sets the number of cards required for a burn to draw
     * @param _cardsRequiredForBurnToDraw The number of cards required for a burn to draw
     */
    function _setcardsRequiredForBurnToDraw(uint256 _cardsRequiredForBurnToDraw) internal {
        require(_cardsRequiredForBurnToDraw > 0, "cardsRequiredToBurnToDraw must be greater than 0");
        cardsRequiredForBurnToDraw = _cardsRequiredForBurnToDraw;

        emit NewNumberOfCardsRequiredForBurnToDraw(_cardsRequiredForBurnToDraw);
    }

    /**
     * @notice Internal function that sets the number of cards that will be minted per burn
     * @param _cardsDrawnPerBurn The number of cards minted during a burn to draw operation
     */
    function _setcardsDrawnPerBurn(uint256 _cardsDrawnPerBurn) internal {
        require(_cardsDrawnPerBurn > 0, "cardsDrawnPerBurn must be greater than 0");
        cardsDrawnPerBurn = _cardsDrawnPerBurn;

        emit NewNumberOfCardsDrawnPerBurn(_cardsDrawnPerBurn);
    }

    /**
     * @dev Checks if user is whitelisted via Merkle proof.
     * @param merkleRoot Root of Merkle tree.
     * @param merkleProof Merkle proof for user.
     * @param user User's address to check.
     * @return isWhitelisted True if whitelisted, else false.
     */
    function _verifyWhitelist(
        bytes32 merkleRoot,
        bytes32[] calldata merkleProof,
        address user
    ) internal pure returns (bool isWhitelisted) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }

    /**
     * @dev Transfers funds or Ether based on the payment type.
     * @param paymentToken Token contract address, or zero for Ether.
     * @param from Sender's address.
     * @param to Recipient's address.
     * @param amount Amount to transfer.
     */
    function _executeFundsTransfer(address paymentToken, address from, address to, uint256 amount) internal {
        if (paymentToken == address(0)) {
            require(msg.value == amount, "Incorrect ETH amount");
        }
        /* Transfer remainder to seller. */
        _transferTo(paymentToken, from, to, amount);
    }

    /**
     * @dev Transfers Ether or ERC20 tokens from one address to another.
     * @param paymentToken ERC20 token address, or zero for Ether.
     * @param from Sender's address.
     * @param to Recipient's address.
     * @param amount Transfer amount.
     */
    function _transferTo(address paymentToken, address from, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (paymentToken == address(0)) {
            payable(to).transfer(amount);
        } else {
            executionDelegate.transferERC20(paymentToken, from, to, amount);
        }
    }

    /**
     * @dev Mints multiple cards to a buyer's address.
     * @param collection NFT collection address.
     * @param cardsPerPack Quantity of cards to mint.
     * @param buyer Recipient address.
     */
    function _executeBatchMint(address collection, uint256 cardsPerPack, address buyer) internal {
        for (uint256 i = 0; i < cardsPerPack; i++) {
            executionDelegate.mintFantasyCard(collection, buyer);
        }
    }
}

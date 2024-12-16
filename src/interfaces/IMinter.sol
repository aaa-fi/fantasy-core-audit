// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMinter {
    /// @notice Configuration for the vrgda calculation
    struct VRGDAConfig {
        int256 targetPrice; // Target price for a pack scaled by the decimals of the payment token.
        int256 priceDecayPercent; // Percent price decays per unit of time with no sales, scaled by 1e18.
        int256 perTimeUnit; // The total number of packs to target selling every full unit of time scaled by 1e18.
        int256 secondsPerTimeUnit; // The total number of seconds in a time unit. 60 for a minute, 3600 for an hour, 86400 for a day.
    }

    // Events
    event NewMintConfig(
        uint256 mintConfigId,
        address collection,
        uint256 cardsPerPack,
        uint256 maxPacks,
        address paymentToken,
        uint256 fixedPrice,
        uint256 maxPacksPerAddress,
        bool requiresWhitelist,
        bytes32 merkleRoot,
        uint256 expirationTimestamp
    );
    event Mint(
        uint256 mintConfigId,
        address buyer,
        uint256 totalMintedPacks,
        uint256 firstTokenId,
        uint256 lastTokenId,
        uint256 price
    );
    event LevelUp(uint256[] burntTokenIds, uint256 mintedTokenId, address collection, address caller);
    event BurnToDraw(uint256[] burntTokenIds, uint256[] mintedTokenIds, address collection, address caller);
    event BatchBurn(uint256[] burntTokenIds, address collection, address caller);
    event NewTreasury(address treasury);
    event NewExecutionDelegate(address _executionDelegate);
    event CollectionUpdatedForMintConfig(uint256 mintConfigId, address newCollection);
    event CardsPerPackUpdatedForMintConfig(uint256 mintConfigId, uint256 newCardsPerPack);
    event MaxPacksUpdatedForMintConfig(uint256 mintConfigId, uint256 newMaxPacks);
    event PaymentTokenUpdatedForMintConfig(uint256 mintConfigId, address newPaymentToken);
    event FixedPriceUpdatedForMintConfig(uint256 mintConfigId, uint256 newFixedPrice);
    event VRGDAUpdatedForMintConfig(
        uint256 mintConfigId,
        int256 targetPrice,
        int256 priceDecayPercent,
        int256 perTimeUnit
    );
    event MaxPacksPerAddressUpdatedForMintConfig(uint256 mintConfigId, uint256 maxPacksPerAddress);
    event WhitelistRequirementUpdatedForMintConfig(uint256 mintConfigId, bool newRequiresWhitelist);
    event MerkleRootUpdatedForMintConfig(uint256 mintConfigId, bytes32 newMerkleRoot);
    event MintConfigCancelled(uint256 mintConfigId);
    event NewNumberOfCardsRequiredForLevelUp(uint256 _cardsRequiredForLevelUp);
    event NewNumberOfCardsRequiredForBurnToDraw(uint256 _cardsRequiredForBurnToDraw);
    event NewNumberOfCardsDrawnPerBurn(uint256 _cardsDrawnPerBurn);
    event ExpirationTimestampUpdatedForMintConfig(uint256 mintConfigId, uint256 newExpirationTimestamp);
    event NewWhitelistedCollection(address collection);
    event UnWhitelistedCollection(address collection);

    // Functions
    function mint(uint256 configId, bytes32[] calldata merkleProof, uint256 maxPrice) external payable;

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
    ) external;

    function levelUp(uint256[] calldata tokenIds, address collection) external;

    function setCollectionForMintConfig(uint256 mintConfigId, address collection) external;

    function setCardsPerPackForMintConfig(uint256 mintConfigId, uint256 cardsPerPack) external;

    function setMaxPacksForMintConfig(uint256 mintConfigId, uint256 maxPacks) external;

    function setFixedPriceForMintConfig(uint256 mintConfigId, uint256 fixedPrice) external;

    function setVRGDAForMintConfig(
        uint256 mintConfigId,
        int256 targetPrice,
        int256 priceDecayPercent,
        int256 perTimeUnit,
        int256 secondsPerTimeUnit
    ) external;

    function setMaxPacksPerAddressForMintConfig(uint256 mintConfigId, uint256 maxPacksPerAddress) external;

    function setRequiresWhitelistForMintConfig(uint256 mintConfigId, bool requiresWhitelist) external;

    function setMerkleRootForMintConfig(uint256 mintConfigId, bytes32 merkleRoot) external;

    function cancelMintConfig(uint256 mintConfigId) external;

    function setTreasury(address _treasury) external;

    function setExecutionDelegate(address _executionDelegate) external;

    // View functions to get config details might be included based on the requirement
    function getMintConfig(
        uint256 mintConfigId
    )
        external
        view
        returns (
            address collection,
            uint256 cardsPerPack,
            uint256 maxPacks,
            address paymentToken,
            uint256 fixedPrice,
            uint256 maxPacksPerAddress,
            bool requiresWhitelist,
            bytes32 merkleRoot,
            uint256 startTimestamp,
            uint256 expirationTimestamp,
            uint256 totalMintedPacks,
            bool cancelled
        );

    function getAmountMintedPerAddressForMintConfig(uint256 mintConfigId, address user) external view returns (uint256);

    function saveFunds(address paymentToken, address to, uint256 amount) external;
}

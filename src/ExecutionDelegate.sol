/**                                                                                                                                     
    ______            __                  
   / ____/___ _____  / /_____ ________  __
  / /_  / __ `/ __ \/ __/ __ `/ ___/ / / /
 / __/ / /_/ / / / / /_/ /_/ (__  ) /_/ / 
/_/    \__,_/_/ /_/\__/\__,_/____/\__, /  
                                 /____/   

**/
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";
import "./interfaces/IFantasyCards.sol";
import "./interfaces/IExecutionDelegate.sol";

/**
 * @title ExecutionDelegate
 * @dev Proxy contract to manage user token approvals
 */
contract ExecutionDelegate is IExecutionDelegate, AccessControlDefaultAdminRules, Pausable {
    using Address for address;

    /// @notice Role hash for the address allowed to pause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    mapping(address => bool) public contracts;
    mapping(address => bool) public revokedApproval;

    modifier approvedContract() {
        require(contracts[msg.sender], "Contract is not approved to make transfers");
        _;
    }

    constructor() AccessControlDefaultAdminRules(0, msg.sender) {
        IBlast(0x4300000000000000000000000000000000000002).configureClaimableGas();
        IBlast(0x4300000000000000000000000000000000000002).configureGovernor(msg.sender);
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800).configurePointsOperator(msg.sender);
    }

    /**
     * @dev Approve contract to call transfer functions
     * @param _contract address of contract to approve
     */
    function approveContract(address _contract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        contracts[_contract] = true;
        emit ApproveContract(_contract);
    }

    /**
     * @dev Revoke approval of contract to call transfer functions
     * @param _contract address of contract to revoke approval
     */
    function denyContract(address _contract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        contracts[_contract] = false;
        emit DenyContract(_contract);
    }

    /**
     * @dev Block contract from making transfers on-behalf of a specific user
     */
    function revokeApproval() external {
        revokedApproval[msg.sender] = true;
        emit RevokeApproval(msg.sender);
    }

    /**
     * @dev Allow contract to make transfers on-behalf of a specific user
     */
    function grantApproval() external {
        revokedApproval[msg.sender] = false;
        emit GrantApproval(msg.sender);
    }

    /**
     * @dev Mint Fantasy Card
     * @param collection address of the collection
     * @param to address of the recipient
     */
    function mintFantasyCard(address collection, address to) external whenNotPaused approvedContract {
        IFantasyCards(collection).safeMint(to);
    }

    function burnFantasyCard(address collection, uint256 tokenId, address from) external whenNotPaused approvedContract {
        require(revokedApproval[from] == false, "User has revoked approval");
        IFantasyCards(collection).burn(tokenId);
    }

    /**
     * @dev Transfer ERC721 token using `transferFrom`
     * @param collection address of the collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId
     */
    function transferERC721Unsafe(
        address collection,
        address from,
        address to,
        uint256 tokenId
    ) external whenNotPaused approvedContract {
        require(revokedApproval[from] == false, "User has revoked approval");
        IERC721(collection).transferFrom(from, to, tokenId);
    }

    /**
     * @dev Transfer ERC721 token using `safeTransferFrom`
     * @param collection address of the collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId
     */
    function transferERC721(
        address collection,
        address from,
        address to,
        uint256 tokenId
    ) external whenNotPaused approvedContract {
        require(revokedApproval[from] == false, "User has revoked approval");
        IERC721(collection).safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Transfer ERC1155 token using `safeTransferFrom`
     * @param collection address of the collection
     * @param from address of the sender
     * @param to address of the recipient
     * @param tokenId tokenId
     * @param amount amount
     */
    function transferERC1155(
        address collection,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external whenNotPaused approvedContract {
        require(revokedApproval[from] == false, "User has revoked approval");
        IERC1155(collection).safeTransferFrom(from, to, tokenId, amount, "");
    }

    /**
     * @dev Transfer ERC20 token
     * @param token address of the token
     * @param from address of the sender
     * @param to address of the recipient
     * @param amount amount
     */
    function transferERC20(
        address token,
        address from,
        address to,
        uint256 amount
    ) external whenNotPaused approvedContract {
        require(revokedApproval[from] == false, "User has revoked approval");
        bytes memory data = abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount);
        bytes memory returndata = token.functionCall(data);
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "ERC20 transfer failed");
        }
    }

    /**
     * @dev Pause contract
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause contract
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}

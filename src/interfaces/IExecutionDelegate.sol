// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IExecutionDelegate {
    event ApproveContract(address _contract);
    event DenyContract(address _contract);

    event RevokeApproval(address user);
    event GrantApproval(address user);

    function approveContract(address _contract) external;

    function denyContract(address _contract) external;

    function revokeApproval() external;

    function grantApproval() external;

    function mintFantasyCard(address collection, address to) external;

    function burnFantasyCard(address collection, uint256 tokenId, address from) external;

    function transferERC721Unsafe(address collection, address from, address to, uint256 tokenId) external;

    function transferERC721(address collection, address from, address to, uint256 tokenId) external;

    function transferERC1155(address collection, address from, address to, uint256 tokenId, uint256 amount) external;

    function transferERC20(address token, address from, address to, uint256 amount) external;
}

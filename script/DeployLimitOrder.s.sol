// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {LimitOrder} from "../src/limitOrder.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract DeployLimitOrder is Script {
    address owner = vm.envAddress("OWNER_ADDRESS");

    address uniswapRouterAddress = 0x86dcd3293C53Cf8EFd7303B57beb2a3F671dDE98;
    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(uniswapRouterAddress);

    function run() external returns (LimitOrder) {
        vm.startBroadcast(owner);
        LimitOrder limitOrder = new LimitOrder(uniswapRouter);
        vm.stopBroadcast();
        return (limitOrder);
    }
}

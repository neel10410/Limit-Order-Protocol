// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {LimitOrder} from "../src/limitOrder.sol";
import {DeployLimitOrder} from "../script/DeployLimitOrder.s.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IUniswapV2Router02} from "../src/interfaces/IUniswapV2Router.sol";
import "forge-std/console.sol";

contract TestLimitOrder is Test {
    string public RPC_URL =
        "https://eth-sepolia.g.alchemy.com/v2/KdgQDmf9ZbfZ2KIwLN5XB6Lz_bSgblZp";
    LimitOrder limitOrder;
    IUniswapV2Router02 uniswapRouter =
        IUniswapV2Router02(0x86dcd3293C53Cf8EFd7303B57beb2a3F671dDE98);

    ERC20 Dai = ERC20(0xFF34B3d4Aee8ddCd6F9AFFFB6Fe49bD371b8a357);
    ERC20 Link = ERC20(0xf8Fb3713D459D7C1018BD0A49D19b4C44290EBE5);
    ERC20 public Weth;

    address public owner;
    address public trader;
    uint256 START_BAL = 10 ether;

    function setUp() external {
        uint256 forkID = vm.createFork(RPC_URL);
        vm.selectFork(forkID);

        owner = vm.envAddress("OWNER_ADDRESS");
        trader = makeAddr("trader");

        Weth = ERC20(uniswapRouter.WETH());

        vm.prank(owner);
        vm.allowCheatcodes(0x4a434F0a9A4400a1365a0F3bFe0797e3703F81db); // have to change
        DeployLimitOrder deployLimitOrder = new DeployLimitOrder();
        limitOrder = deployLimitOrder.run();

        deal(address(Dai), trader, START_BAL);
        deal(address(Weth), trader, START_BAL);
        deal(trader, START_BAL);
    }

    function testConstructor() public {
        vm.prank(owner);
        assertEq(limitOrder.owner(), owner);
        assertEq(limitOrder.executor(), owner);
        assertEq(limitOrder.MAX_POSITIONS(), 100);
        assertEq(limitOrder.EXECUTOR_FEE(), 1e15);
        assertEq(limitOrder.ordersNum(), 0);
    }

    function testUpdateExecutor() public {
        vm.prank(owner);
        limitOrder.update_executor(trader);
        assertEq(limitOrder.executor(), trader);
    }

    function testSetNewExecutorFee() public {
        vm.prank(owner);
        limitOrder.setNewExecutorFee(1e16);
        assertEq(limitOrder.EXECUTOR_FEE(), 1e16);
    }

    function testCreateOrder() public {
        // Test `TokensForToken` order type

        address[] memory path = new address[](2);
        path[0] = address(Dai);
        path[1] = address(Link);

        LimitOrder.Limit memory limit = LimitOrder.Limit({
            orderType: LimitOrder.OrderType.TokensForToken,
            assetIn: address(Dai),
            assetOut: address(Link),
            assetInOffered: 1 ether,
            assetOutExpected: 239262002969711656,
            slippage: 0,
            path: path,
            executorFee: 0.001 ether,
            expire: 1719373903
        });

        vm.startPrank(trader);
        Dai.approve(address(limitOrder), START_BAL);
        limitOrder.createOrder{value: 0.001 ether}(limit);
        vm.stopPrank();

        uint orderId = limitOrder.ordersNum() - 1;

        LimitOrder.Order memory order = limitOrder.getOrderFromOrderBook(
            orderId
        );

        assertEq(uint(order.orderState), uint(LimitOrder.OrderState.Created));
        assertEq(
            uint(order.orderType),
            uint(LimitOrder.OrderType.TokensForToken)
        );
        assertEq(order.traderAddress, trader);
        assertEq(order.assetIn, address(Dai));
        assertEq(order.assetOut, address(Link));
        assertEq(order.assetInOffered, 1 ether);
        assertEq(order.assetOutExpected, 239262002969711656);
        assertEq(order.executorFee, 0.001 ether);
        assertEq(order.id, orderId);
        assertEq(order.ordersI, orderId);
        assertEq(order.slippage, 0);
        assertEq(order.expire, 1719373903);
        assertEq(order.inDecimals, 18);
        assertEq(order.outDecimals, 18);
        assertTrue(order.created > 0);
        assertTrue(order.updated > 0);

        // Test `EthForTokens` order type

        address[] memory path1 = new address[](2);
        path1[0] = address(Dai);
        path1[1] = address(Link);

        limit = LimitOrder.Limit({
            orderType: LimitOrder.OrderType.EthForTokens,
            assetIn: address(Weth),
            assetOut: address(Dai),
            assetInOffered: 0.1 ether,
            assetOutExpected: 239262002969711656,
            slippage: 0,
            path: path1,
            executorFee: 0.001 ether,
            expire: 1719373903
        });

        vm.startPrank(trader);
        Weth.approve(address(limitOrder), START_BAL);
        limitOrder.createOrder{value: 0.101 ether}(limit); // Including executor fee
        vm.stopPrank();

        orderId = limitOrder.ordersNum() - 1;
        order = limitOrder.getOrderFromOrderBook(orderId);

        assertEq(
            uint(order.orderType),
            uint(LimitOrder.OrderType.EthForTokens)
        );
        assertEq(order.assetInOffered, 0.1 ether);
        assertEq(order.executorFee, 0.001 ether);

        // Test `TokensForEth` order type

        address[] memory path2 = new address[](2);
        path2[0] = address(Dai);
        path2[1] = address(Weth);

        limit = LimitOrder.Limit({
            orderType: LimitOrder.OrderType.TokensForEth,
            assetIn: address(Dai),
            assetOut: address(Weth),
            assetInOffered: 1 ether,
            assetOutExpected: 239262002969711656,
            slippage: 0,
            path: path2,
            executorFee: 0.001 ether,
            expire: 1719373903
        });

        vm.startPrank(trader);
        Dai.approve(address(limitOrder), START_BAL);
        limitOrder.createOrder{value: 0.001 ether}(limit);
        vm.stopPrank();

        orderId = limitOrder.ordersNum() - 1;
        order = limitOrder.getOrderFromOrderBook(orderId);

        assertEq(
            uint(order.orderType),
            uint(LimitOrder.OrderType.TokensForEth)
        );
        assertEq(order.assetInOffered, 1 ether);
        assertEq(order.executorFee, 0.001 ether);

        // Test for revert conditions
        // Invalid assetInOffered
        limit.assetInOffered = 0;
        vm.startPrank(trader);
        vm.expectRevert("must be greater than 0");
        limitOrder.createOrder{value: 0.001 ether}(limit);
        vm.stopPrank();

        // Invalid assetOutExpected
        limit.assetInOffered = 1 ether;
        limit.assetOutExpected = 0;
        vm.startPrank(trader);
        vm.expectRevert("must be greater than 0");
        limitOrder.createOrder{value: 0.001 ether}(limit);
        vm.stopPrank();

        // Invalid executor fee
        limit.assetOutExpected = 239262002969711656;
        limit.executorFee = 0;
        vm.startPrank(trader);
        vm.expectRevert("Invalid fee");
        limitOrder.createOrder{value: 0.001 ether}(limit);
        vm.stopPrank();
    }

    function testCancelOrder() public {
        // Address setup
        address[] memory path = new address[](2);
        path[0] = address(Dai);
        path[1] = address(Link);

        // Define the limit order
        LimitOrder.Limit memory limit = LimitOrder.Limit({
            orderType: LimitOrder.OrderType.TokensForToken,
            assetIn: address(Dai),
            assetOut: address(Link),
            assetInOffered: 1 ether,
            assetOutExpected: 239262002969711656,
            slippage: 0,
            path: path,
            executorFee: 0.001 ether,
            expire: 1719373903
        });

        // Prank caller for order creation
        vm.startPrank(trader);
        Dai.approve(address(limitOrder), 1 ether);
        limitOrder.createOrder{value: 0.001 ether}(limit);
        vm.stopPrank();

        // Verify the order creation
        uint orderId = limitOrder.ordersNum() - 1;
        LimitOrder.Order memory order = limitOrder.getOrderFromOrderBook(
            orderId
        );

        // Assertions for order details
        assertEq(uint(order.orderState), uint(LimitOrder.OrderState.Created));
        assertEq(
            uint(order.orderType),
            uint(LimitOrder.OrderType.TokensForToken)
        );
        assertEq(order.traderAddress, trader);
        assertEq(order.assetIn, address(Dai));
        assertEq(order.assetOut, address(Link));
        assertEq(order.assetInOffered, 1 ether);
        assertEq(order.assetOutExpected, 239262002969711656);
        assertEq(order.executorFee, 0.001 ether);
        assertEq(order.id, orderId);
        assertEq(order.ordersI, orderId);
        assertEq(order.slippage, 0);
        assertEq(order.expire, 1719373903);
        assertEq(order.inDecimals, 18);
        assertEq(order.outDecimals, 18);
        assertTrue(order.created > 0);
        assertTrue(order.updated > 0);

        // Cancel the order
        vm.startPrank(trader);
        limitOrder.cancelOrder(orderId);
        vm.stopPrank();

        // Verify the order cancellation
        order = limitOrder.getOrderFromOrderBook(orderId);
        assertEq(uint(order.orderState), uint(LimitOrder.OrderState.Cancelled));

        // Verify the refund
        uint256 daiBalanceAfter = Dai.balanceOf(trader);
        uint256 ethBalanceAfter = trader.balance;

        assertEq(daiBalanceAfter, START_BAL);
        assertEq(ethBalanceAfter, START_BAL); // Includes initial balance and refunded executor fee
    }

    function testExecuteOrders() public {
        // Create an EthForTokens order
        createOrderEthForTokens();

        // Create a TokensForEth order
        createOrderTokensForEth();

        // Create a TokensForToken order
        createOrderTokensForToken();

        // Execute orders
        vm.startPrank(owner); // Ensure this has the necessary permissions
        limitOrder.executeOrders(2, 1);
        vm.stopPrank();

        // Assertions for each order type
        verifyOrderExecution();
    }

    function createOrderEthForTokens() internal {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(Link);

        LimitOrder.Limit memory limit = LimitOrder.Limit({
            orderType: LimitOrder.OrderType.EthForTokens,
            assetIn: uniswapRouter.WETH(),
            assetOut: address(Link),
            assetInOffered: 1 ether,
            assetOutExpected: 1,
            slippage: 0,
            path: path,
            executorFee: 0.01 ether,
            expire: block.timestamp + 1 days
        });

        vm.startPrank(trader);
        limitOrder.createOrder{value: 1.01 ether}(limit);
        vm.stopPrank();
    }

    function createOrderTokensForEth() internal {
        address[] memory path = new address[](2);
        path[0] = address(Dai);
        path[1] = uniswapRouter.WETH();

        LimitOrder.Limit memory limit = LimitOrder.Limit({
            orderType: LimitOrder.OrderType.TokensForEth,
            assetIn: address(Dai),
            assetOut: uniswapRouter.WETH(),
            assetInOffered: 1 ether,
            assetOutExpected: 1 ether,
            slippage: 0,
            path: path,
            executorFee: 0.01 ether,
            expire: block.timestamp + 1 days
        });

        vm.startPrank(trader);
        Dai.approve(address(limitOrder), 1 ether);
        limitOrder.createOrder{value: 0.01 ether}(limit);
        vm.stopPrank();
    }

    function createOrderTokensForToken() internal {
        address[] memory path = new address[](2);
        path[0] = address(Dai);
        path[1] = address(Link);

        LimitOrder.Limit memory limit = LimitOrder.Limit({
            orderType: LimitOrder.OrderType.TokensForToken,
            assetIn: address(Dai),
            assetOut: address(Link),
            assetInOffered: 1 ether,
            assetOutExpected: 1,
            slippage: 0,
            path: path,
            executorFee: 0.01 ether,
            expire: block.timestamp + 1 days
        });

        vm.startPrank(trader);
        Dai.approve(address(limitOrder), 1 ether);
        limitOrder.createOrder{value: 0.01 ether}(limit);
        vm.stopPrank();
    }

    function verifyOrderExecution() internal {
        // Verify EthForTokens order
        // uint orderId = 0;
        // LimitOrder.Order memory order = limitOrder.getOrderFromOrderBook(
        //     orderId
        // );
        // assertEq(uint(order.orderState), uint(LimitOrder.OrderState.Finished));
        // assertTrue(Link.balanceOf(trader) > 0); // Ensure trader received Link tokens

        // // Verify TokensForEth order
        // orderId = 1;
        // order = limitOrder.getOrderFromOrderBook(orderId);
        // assertEq(uint(order.orderState), uint(LimitOrder.OrderState.Finished));
        // assertTrue(trader.balance > 1 ether); // Ensure trader received Eth

        // Verify TokensForToken order
        uint orderId = 2;
        LimitOrder.Order memory order = limitOrder.getOrderFromOrderBook(
            orderId
        );
        assertEq(uint(order.orderState), uint(LimitOrder.OrderState.Finished));
        uint balanceBefore = Link.balanceOf(trader);
        assertTrue(Link.balanceOf(trader) > 0); // Ensure trader received Link tokens
        console.log("b2", Link.balanceOf(trader));
    }
}

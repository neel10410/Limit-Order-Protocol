// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

// v2router address on sepolia - 0x86dcd3293C53Cf8EFd7303B57beb2a3F671dDE98

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "./interfaces/IUniswapV2Router.sol";

contract LimitOrder is Context {
    IUniswapV2Router02 public uniswapV2Router;

    enum OrderState {
        Created,
        Cancelled,
        Finished
    }
    enum OrderType {
        EthForTokens,
        TokensForEth,
        TokensForToken
    }

    struct Insight {
        address addressA;
        address addressB;
        uint decimalsA;
        uint decimalsB;
        bool locked;
        uint totalOrders;
        uint totalTraders;
    }

    struct Limit {
        OrderType orderType;
        address assetIn;
        address assetOut;
        uint assetInOffered;
        uint assetOutExpected;
        uint slippage;
        address[] path;
        uint executorFee;
        uint expire;
    }

    struct Order {
        OrderState orderState;
        OrderType orderType;
        address payable traderAddress;
        address assetIn;
        address assetOut;
        uint assetInOffered;
        uint assetOutExpected;
        uint executorFee;
        uint id;
        uint ordersI;
        address[] path;
        uint slippage;
        uint expire;
        uint inDecimals;
        uint outDecimals;
        uint created;
        uint updated;
    }

    uint public MAX_POSITIONS;
    uint public EXECUTOR_FEE;
    uint[] public orders;
    uint public ordersNum;
    address public executor;
    address public owner;

    mapping(uint => Order) public orderBook;
    mapping(address => uint[]) private ordersForAddress;
    mapping(bytes32 => Insight) public insightInfo;
    bytes32[] public insightId;
    mapping(bytes32 => mapping(address => bool)) recordedTrader;

    modifier onlyExecutor() {
        require(msg.sender == executor, "caller is not Executor");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /**
     * @dev Constructor that initializes the contract with the Uniswap V2 Router.
     * @param _uniswapV2Router Address of the Uniswap V2 Router contract.
     */
    constructor(IUniswapV2Router02 _uniswapV2Router) {
        uniswapV2Router = _uniswapV2Router;
        owner = msg.sender;
        executor = msg.sender;
        MAX_POSITIONS = 100;
        EXECUTOR_FEE = 1e15;
        ordersNum = 0;
    }

    /**
     * @dev Updates the lock status of an insight.
     * @param key The key of the insight to be updated.
     * @param locked The new lock status.
     */
    function updateUnlock(bytes32 key, bool locked) external onlyOwner {
        insightInfo[key].locked = locked;
    }

    /**
     * @dev Updates the executor address.
     * @param _executor The new executor address.
     */
    function update_executor(address _executor) external onlyOwner {
        executor = _executor;
    }

    /**
     * @dev Sets a new Uniswap V2 Router address.
     * @param _uniswapV2Router The new Uniswap V2 Router address.
     */
    function setUniswapRouter(
        IUniswapV2Router02 _uniswapV2Router
    ) external onlyOwner {
        uniswapV2Router = _uniswapV2Router;
    }

    /**
     * @dev Sets a new executor fee.
     * @param _EXECUTOR_FEE The new executor fee amount.
     */
    function setNewExecutorFee(uint256 _EXECUTOR_FEE) external onlyOwner {
        EXECUTOR_FEE = _EXECUTOR_FEE;
    }

    /**
     * @dev Generates a unique key for a pair of addresses.
     * @param aA Address A.
     * @param aB Address B.
     * @return key The generated key.
     */
    function getKeyPair(
        address aA,
        address aB
    ) internal pure returns (bytes32 key) {
        if (aA < aB) {
            key = keccak256(abi.encodePacked(aA, aB));
        } else {
            key = keccak256(abi.encodePacked(aB, aA));
        }
    }

    /**
     * @dev Creates a new order based on the provided limit details.
     * @param limit The details of the limit order.
     */
    function createOrder(Limit calldata limit) external payable {
        uint payment = msg.value;

        require(limit.assetInOffered > 0, "must be greater than 0");
        require(limit.assetOutExpected > 0, "must be greater than 0");
        require(limit.executorFee >= EXECUTOR_FEE, "Invalid fee");

        if (limit.orderType == OrderType.EthForTokens) {
            require(limit.assetIn == uniswapV2Router.WETH(), "WETH as assetIn");
            require(
                payment >= (limit.assetInOffered + limit.executorFee),
                "Payment = assetInOffered + executorFee"
            );
        } else {
            require(
                payment >= limit.executorFee,
                "Transaction value must match executorFee"
            );
            if (limit.orderType == OrderType.TokensForEth) {
                require(
                    limit.assetOut == uniswapV2Router.WETH(),
                    "WETH as assetOut"
                );
            }
            ERC20(limit.assetIn).transferFrom(
                _msgSender(),
                address(this),
                limit.assetInOffered
            );
        }

        uint orderId = ordersNum;
        ordersNum++;

        orderBook[orderId] = Order(
            OrderState.Created,
            limit.orderType,
            payable(msg.sender),
            limit.assetIn,
            limit.assetOut,
            limit.assetInOffered,
            limit.assetOutExpected,
            limit.executorFee,
            orderId,
            orders.length,
            limit.path,
            limit.slippage,
            limit.expire,
            ERC20(limit.assetIn).decimals(),
            ERC20(limit.assetOut).decimals(),
            block.timestamp,
            block.timestamp
        );

        ordersForAddress[msg.sender].push(orderId);
        orders.push(orderId);

        bytes32 key = getKeyPair(limit.assetIn, limit.assetOut);
        if (insightInfo[key].addressA == address(0)) {
            address aA = limit.assetIn < limit.assetOut
                ? limit.assetIn
                : limit.assetOut;
            address aB = limit.assetIn < limit.assetOut
                ? limit.assetOut
                : limit.assetIn;

            insightInfo[key] = Insight(
                aA,
                aB,
                ERC20(aA).decimals(),
                ERC20(aB).decimals(),
                false,
                0,
                0
            );
            insightId.push(key);
        }

        require(insightInfo[key].locked == false, "pair locked");

        insightInfo[key].totalOrders += 1;

        if (recordedTrader[key][msg.sender] == false) {
            recordedTrader[key][msg.sender] = true;
            insightInfo[key].totalTraders += 1;
        }
    }

    /**
     * @dev Internal function to update an order's state.
     * @param order The order to be updated.
     * @param newState The new state of the order.
     */
    function updateOrder(Order memory order, OrderState newState) internal {
        if (orders.length == 1) {
            orders.pop();
        } else if (orders.length > 1) {
            uint openId = order.ordersI;
            uint lastId = orders[orders.length - 1];
            if (openId != orders.length - 1) {
                Order storage lastOrder = orderBook[lastId];
                lastOrder.ordersI = openId;
                orders[openId] = lastId;
            }
            orders.pop();
        }

        order.orderState = newState;
        order.updated = block.timestamp;

        orderBook[order.id] = order;
    }

    /**
     * @dev Internal function to cancel an order.
     * @param orderId The ID of the order to be cancelled.
     */
    function _cancelOrder(uint orderId) internal {
        Order memory order = orderBook[orderId];
        require(order.traderAddress != address(0), "Invalid Order");
        require(msg.sender == order.traderAddress, "Not your order");
        require(order.orderState == OrderState.Created, "Invalid orderState");

        updateOrder(order, OrderState.Cancelled);

        uint refundEth = 0;
        uint refundToken = 0;

        if (order.orderType != OrderType.EthForTokens) {
            refundEth = order.executorFee;
            refundToken = order.assetInOffered;
            (order.traderAddress).transfer(refundEth);
            ERC20(order.assetIn).transfer(order.traderAddress, refundToken);
        } else {
            refundEth = order.assetInOffered + order.executorFee;
            (order.traderAddress).transfer(refundEth);
        }
    }

    /**
     * @dev Cancels an order.
     * @param orderId The ID of the order to be cancelled.
     */
    function cancelOrder(uint orderId) external {
        _cancelOrder(orderId);
    }

    /**
     * @dev Executes a batch of orders starting from a specific index.
     * @param startIndex The index to start executing orders from.
     * @param count The number of orders to execute.
     */
    function executeOrders(uint startIndex, uint count) external {
        uint totalOrders = orders.length;
        uint endIndex = startIndex + count;

        require(startIndex < totalOrders, "Invalid start index");
        require(endIndex <= totalOrders, "Invalid count");

        for (uint i = startIndex; i < endIndex; i++) {
            uint orderId = orders[i];
            if (orderBook[orderId].expire < block.timestamp) {
                _cancelOrder(orderId);
            } else {
                executeOrder(orderId);
            }
        }
    }

    /**
     * @dev Calculates the expected output amount after applying slippage.
     * @param amountsOut Array of output amounts.
     * @param slippage The slippage percentage.
     * @return amountOut The expected output amount.
     */
    function getExpectedOut(
        uint[] memory amountsOut,
        uint slippage
    ) internal pure returns (uint amountOut) {
        amountOut =
            (amountsOut[amountsOut.length - 1] * (1e18 - slippage)) /
            1e18;
    }

    /**
     * @dev Internal function to execute a specific order.
     * @param orderId The ID of the order to be executed.
     * @return success Boolean indicating whether the execution was successful.
     */
    function executeOrder(uint orderId) internal returns (bool success) {
        Order memory order = orderBook[orderId];
        require(order.traderAddress != address(0), "Invalid order");
        require(order.orderState == OrderState.Created, "Invalid order state");

        uint[] memory amountsOut;
        success = false;
        uint amountOutExactly;

        if (order.orderType == OrderType.EthForTokens) {
            amountsOut = uniswapV2Router.getAmountsOut(
                order.assetInOffered,
                order.path
            );

            if (getExpectedOut(amountsOut, 0) >= order.assetOutExpected) {
                try
                    uniswapV2Router.swapExactETHForTokens{
                        value: order.assetInOffered
                    }(
                        getExpectedOut(amountsOut, 0),
                        order.path,
                        order.traderAddress,
                        block.timestamp
                    )
                returns (uint[] memory result) {
                    amountOutExactly = result[result.length - 1];
                    success = true;
                } catch {}
            }
        } else if (order.orderType == OrderType.TokensForEth) {
            amountsOut = uniswapV2Router.getAmountsOut(
                order.assetInOffered,
                order.path
            );

            if (getExpectedOut(amountsOut, 0) >= order.assetOutExpected) {
                ERC20(order.assetIn).approve(
                    address(uniswapV2Router),
                    order.assetInOffered
                );
                try
                    uniswapV2Router.swapExactTokensForETH(
                        order.assetInOffered,
                        getExpectedOut(amountsOut, 0),
                        order.path,
                        order.traderAddress,
                        block.timestamp
                    )
                returns (uint[] memory result) {
                    success = true;
                    amountOutExactly = result[result.length - 1];
                } catch {}
            }
        } else if (order.orderType == OrderType.TokensForToken) {
            amountsOut = uniswapV2Router.getAmountsOut(
                order.assetInOffered,
                order.path
            );

            if (getExpectedOut(amountsOut, 0) >= order.assetOutExpected) {
                ERC20(order.assetIn).approve(
                    address(uniswapV2Router),
                    order.assetInOffered
                );
                try
                    uniswapV2Router.swapExactTokensForTokens(
                        order.assetInOffered,
                        getExpectedOut(amountsOut, 0),
                        order.path,
                        order.traderAddress,
                        block.timestamp
                    )
                returns (uint[] memory result) {
                    success = true;
                    amountOutExactly = result[result.length - 1];
                } catch {}
            }
        }

        if (success) {
            updateOrder(order, OrderState.Finished);
            payable(msg.sender).transfer(order.executorFee);
        }
    }

    /**
     * @dev Returns the total number of orders.
     * @return The length of the orders array.
     */
    function getOrdersLength() external view returns (uint) {
        return orders.length;
    }

    /**
     * @dev Returns the orders for a specific address starting from an offset.
     * @param _address The address to query orders for.
     * @param offset The offset to start querying from.
     * @return An array of orders and the total count.
     */
    function getOrdersForAddress(
        address _address,
        uint offset
    ) public view returns (Order[] memory, uint) {
        uint totalCount = 0;
        Order[] memory orders_address = new Order[](MAX_POSITIONS);

        for (uint i = offset; i < ordersForAddress[_address].length; i++) {
            orders_address[totalCount] = orderBook[
                ordersForAddress[_address][i]
            ];
            totalCount++;
            if (totalCount >= (MAX_POSITIONS - 1)) break;
        }

        return (orders_address, totalCount);
    }

    /**
     * @dev Returns the total number of orders for a specific address.
     * @param _address The address to query orders for.
     * @return The number of orders for the address.
     */
    function getOrdersForAddressLength(
        address _address
    ) external view returns (uint) {
        return ordersForAddress[_address].length;
    }

    /**
     * @dev Returns the order ID for a specific address and index.
     * @param _address The address to query orders for.
     * @param index The index of the order.
     * @return The order ID.
     */
    function getOrderIdForAddress(
        address _address,
        uint index
    ) external view returns (uint) {
        return ordersForAddress[_address][index];
    }

    /**
     * @dev Returns a list of insights starting from an offset.
     * @param offset The offset to start querying from.
     * @param size The number of insights to return.
     * @return An array of insights and the total count.
     */
    function getInsight(
        uint offset,
        uint size
    ) public view returns (Insight[] memory, uint) {
        uint totalCount = 0;
        Insight[] memory insightTotal = new Insight[](size);
        for (uint i = offset; i < insightId.length; i++) {
            insightTotal[totalCount] = insightInfo[insightId[i]];
            totalCount++;
            if (totalCount >= size) break;
        }
        return (insightTotal, totalCount);
    }

    /**
     * @dev Returns a list of open orders starting from an offset.
     * @param offset The offset to start querying from.
     * @param size The number of open orders to return.
     * @return An array of open orders and the total count.
     */
    function getOpenOrders(
        uint offset,
        uint size
    ) public view returns (Order[] memory, uint) {
        uint totalCount = 0;
        Order[] memory orders_total = new Order[](size);
        for (uint i = offset; i < orders.length; i++) {
            orders_total[totalCount] = orderBook[orders[i]];
            totalCount++;
            if (totalCount >= size) break;
        }
        return (orders_total, totalCount);
    }

    /**
     * @dev Returns a list of orders starting from an offset.
     * @param offset The offset to start querying from.
     * @param size The number of orders to return.
     * @return An array of orders and the total count.
     */
    function getOrders(
        uint offset,
        uint size
    ) public view returns (Order[] memory, uint) {
        uint totalCount = 0;
        Order[] memory orders_total = new Order[](size);
        for (uint i = offset; i < ordersNum; i++) {
            orders_total[totalCount] = orderBook[i];
            totalCount++;
            if (totalCount >= size) break;
        }
        return (orders_total, totalCount);
    }

    function getOrderFromOrderBook(
        uint orderId
    ) external view returns (Order memory) {
        return orderBook[orderId];
    }

    /**
     * @dev Fallback function to receive Ether.
     */
    receive() external payable {}
}

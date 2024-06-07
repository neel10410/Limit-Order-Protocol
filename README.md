# Limit Order Protocol

## Overview

The Limit Order Protocol is a smart contract built using the Foundry framework that allows users to create limit orders for token swaps on UniswapV2. This protocol enables users to specify a desired price for a token swap, and the order will only be executed when the specified limit is reached. The contract leverages UniswapV2Router's swap functions for token swapping and is deployed on the Sepolia test network.

## Features

- **Limit Order Creation:** Users can create limit orders specifying the desired price for token swaps.
- **Automatic Execution:** Orders are executed automatically when the specified limit price is reached.
- **Integration with UniswapV2:** Utilizes UniswapV2Router’s swap functions for executing token swaps.
- **Tested with Foundry Framework:** Comprehensive testing of the protocol functionalities using the Foundry framework.
- **Deployed on Sepolia Test Network:** The contract is deployed and operational on the Sepolia test network.

## Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) - The framework used for development and testing.
- Sepolia test network access - For deployment and interaction with the contract.

### Installation

- **Clone the Repository**
   
      git clone https://github.com/neel10410/Limit-Order-Protocol.git
      cd Limit-Order-Protocol
   
- **Install Dependencies**
  
      forge install

- **Compile the Contracts**
  
      forge build
  
- **Run Tests**
  
      forge test

### Deployment
**Deploy the contract to the Sepolia test network:**

- **Configure Network**   
Set up your Sepolia network configuration in foundry.toml.

- **Deploy Contract**
  
      forge create --rpc-url <SEPOLIA_RPC_URL> --private-key <YOUR_PRIVATE_KEY> src/limitOrder.sol:LimitOrder

## Usage
- **Create a Limit Order**  
Users can create a limit order by specifying the token pair, the desired swap amount, and the limit price.

- **Monitor and Execute Orders**  
The protocol will monitor the market prices and execute the order automatically when the specified limit price is reached.

## Testing
The protocol functionalities are tested using the Foundry framework. To run the tests:

    forge test

Ensure that all tests pass to verify the correct implementation of the protocol features.

## Contributing
Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contact
For any inquiries or support, please contact [neelshah1041@gmail.com].
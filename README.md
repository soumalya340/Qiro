# Blockchain Lending Vault Smart Contract

This repository houses a Move smart contract that implements a basic vault or pool on the Aptos blockchain. Users can deposit tokens, earn interest, and withdraw funds.

## Prerequisites

- Aptos node and tools (`aptos-cli`)
- Move compiler (`move`)
- Token addresses for deposits and withdrawals (replace with your specific tokens)

## Deployment Guide

### Clone the Repository:

```bash
git clone https://github.com/your-repo/lending-vault.git
```


## Set Up Your Environment:
Ensure you have Aptos node and tools installed and configured.
Replace TOKEN_ADDRESS in the main function with your desired token address for deposits.
Compile the Smart Contract:
```bash
Copy code
cd lending-vault
move build
# Use code with caution.
```
## Deploy to the Aptos Network:

Run aptos-cli account create --faucet --no-wait to create a new account and get its address.
Run sh deploy.sh <DEPLOYMENT_ADDRESS> where <DEPLOYMENT_ADDRESS> is the address from step 4.
Using the Contract
1. Whitelist Users:
Run sh add_to_whitelist.sh <ADDRESS1> <ADDRESS2> ... to add users to the whitelist. Replace <ADDRESS1> and <ADDRESS2> with user addresses.

2. Deposit Tokens:
Use a Move wallet or tool like aptos-cli to send tokens to the deployed contract address.

3. Withdraw Tokens:
Call the withdraw function from your wallet or tool, specifying the desired amount and user address.

Events
Deposited: Emitted when a user deposits tokens.
Withdrew: Emitted when a user withdraws tokens.
InterestAccrued: Emitted periodically when interest accrues on the total pool balance.

This README.md template provides a basic outline for deploying and interacting with a blockchain lending vault smart contract on the Aptos blockchain, including prerequisites, deployment guide, usage instructions, and events description.



## Compiling the Module

To compile the Move smart contract module, follow these steps in your VSCode terminal:

1. Open the VSCode terminal.
2. Navigate to the root directory of your lending vault project.
3. Run the following command to compile the module:

```bash
aptos move compile
```

### Test the module:
Run aptos move test in vscode terminal for running the unit test. make the whole details into markdown language.

```bash
aptos move test
```
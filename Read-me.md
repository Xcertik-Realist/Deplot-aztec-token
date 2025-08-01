Aztec Token ContractThis project contains a simple token contract written in Aztec.nr for the Aztec Network, a Layer 2 zkRollup on Ethereum. The contract supports private and public state management, allowing private token minting, transfers, and balance queries, with a public total supply. The project includes a bash script to automate setup, compilation, and deployment using the Aztec sandbox.FeaturesPrivate Balances: Token balances are stored privately using zero-knowledge proofs.
Public Total Supply: Tracks the total token supply publicly on the blockchain.
Functions: Private minting, private transfers, private balance queries, and public total supply retrieval.
Automated Setup: A bash script prompts for configuration variables and sets up the project.

PrerequisitesNode.js: Version specified during setup (default: 22.15.0).
Yarn: Install globally with npm install -g yarn.
Aztec Sandbox: Install via npx @aztec/aztec-sandbox@<version> (version specified during setup, default: 0.87.9).
Aztec CLI and Nargo: Included with the Aztec sandbox or installed via npx @aztec/cli@<version>.
Unix-like System: Linux or macOS (Windows users can use WSL).

InstallationClone or Create the Project:If starting fresh, run the provided setup script to generate the project.
Alternatively, clone this repository:bash

git clone <repository-url>
cd token_contract

Run the Setup Script:Make the script executable:bash

chmod +x setup_token_contract.sh

Execute the script and provide the prompted variables (or accept defaults):bash

./setup_token_contract.sh

Prompted Variables:Project directory name (default: token_contract)
Aztec version (default: 0.87.9)
Node.js version (default: 22.15.0)
PXE URL (default: http://localhost:8080)
Contract name (default: TokenContract)
Admin secret (default: your_secret)
Admin salt (default: your_salt)

Start the Aztec Sandbox:In a separate terminal, start the sandbox:bash

npx @aztec/aztec-sandbox@<aztec-version>

Replace <aztec-version> with the version specified during setup.

Project Structure

├── Nargo.toml          # Aztec.nr project configuration
├── src/
│   └── main.nr         # Token contract source code
├── target/
│   └── token_contract.json  # Compiled contract artifact
├── index.ts            # Deployment script
├── setup_token_contract.sh  # Setup automation script
├── package.json        # Node.js project configuration
└── README.md           # This file

UsageCompile the Contract:If you ran the setup script, the contract is already compiled. To recompile:bash

cd <project-directory>
nargo compile

Generate TypeScript Bindings:If not already generated, create TypeScript interfaces:bash

aztec-cli codegen target/<project-directory>.json

Deploy the Contract:Ensure the Aztec sandbox is running.
Run the deployment script:bash

npx ts-node index.ts

Output includes the contract address, minted tokens (1,000,000 to the admin), and admin balance.

Contract DetailsContract Name: Specified during setup (default: TokenContract).
Functions:constructor(admin, name, symbol, decimals): Initializes the contract (public).
mint_to_private(recipient, amount): Mints tokens privately.
transfer_private(from, to, amount): Transfers tokens privately.
balance_of_private(owner): Queries private balance.
get_total_supply(): Retrieves public total supply.

State:Private balances: Maps addresses to token balances.
Public total_supply: Tracks total tokens minted.

TestingAdd tests in src/test/e2e/index.test.ts using Jest and @aztec/aztec.js.
Example test setup:typescript

import { <ContractName> } from '../../target/<project-directory>.js';
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { createPXEClient } from '@aztec/aztec.js';

describe('<ContractName>', () => {
    it('should mint and check balance', async () => {
        const pxe = createPXEClient('<pxe-url>');
        const wallet = await getSchnorrAccount(pxe, '<admin-secret>', '<admin-salt>').deploy();
        const contract = await <ContractName>.deploy(wallet, wallet.getAddress(), 'MyToken', 'MTK', 18).send().deployed();
        await contract.methods.mint_to_private(wallet.getAddress(), 1000n).send().wait();
        const balance = await contract.methods.balance_of_private(wallet.getAddress()).simulate();
        expect(balance).toBe(1000n);
    });
});

Run tests:bash

yarn test

TroubleshootingSandbox Not Running: Ensure the sandbox is active at the specified PXE URL (default: http://localhost:8080).
Version Mismatch: Verify Node.js and Aztec versions match those specified during setup.
Compilation Errors: Check Nargo.toml dependencies and Aztec version compatibility.
Deployment Fails: Confirm the admin secret and salt are valid, and the sandbox is accessible.

ResourcesAztec Documentation
Aztec Starter Repo
Aztec Token Contract Tutorial
Aztec Sandbox Setup

LicenseMIT License. See LICENSE for details.


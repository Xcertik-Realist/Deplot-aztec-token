#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to prompt for input with validation
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local default="$3"
    local input

    while true; do
        read -p "$prompt [$default]: " input
        input="${input:-$default}"
        if [ -n "$input" ]; then
            eval "$var_name='$input'"
            break
        else
            echo -e "${RED}This field is required.${NC}"
        fi
    done
}

# Prompt for all variables
prompt_input "Enter project directory name" PROJECT_DIR "token_contract"
prompt_input "Enter Aztec version" AZTEC_VERSION "0.87.9"
prompt_input "Enter Node.js version (e.g., 22.15.0)" NODE_VERSION "22.15.0"
prompt_input "Enter PXE URL" PXE_URL "http://localhost:8080"
prompt_input "Enter contract name" CONTRACT_NAME "TokenContract"
prompt_input "Enter admin secret" ADMIN_SECRET "your_secret"
prompt_input "Enter admin salt" ADMIN_SALT "your_salt"

# Check for required tools
command -v node >/dev/null 2>&1 || { echo -e "${RED}Node.js is required. Please install Node.js $NODE_VERSION.${NC}"; exit 1; }
command -v yarn >/dev/null 2>&1 || { echo -e "${RED}Yarn is required. Please install Yarn.${NC}"; exit 1; }
command -v aztec-cli >/dev/null 2>&1 || { echo -e "${RED}Aztec CLI is required. Run 'npx @aztec/cli@$AZTEC_VERSION -v' to install.${NC}"; exit 1; }
command -v nargo >/dev/null 2>&1 || { echo -e "${RED}Nargo is required. Install via Aztec sandbox setup.${NC}"; exit 1; }

# Check Node.js version
NODE_MAJOR=$(node -v | cut -d. -f1 | tr -d 'v')
EXPECTED_MAJOR=${NODE_VERSION%%.*}
if [ "$NODE_MAJOR" -ne "$EXPECTED_MAJOR" ]; then
    echo -e "${RED}Node.js version $NODE_VERSION is required. Found $(node -v).${NC}"
    exit 1
fi

echo -e "${GREEN}Setting up token contract project in $PROJECT_DIR...${NC}"

# Step 1: Create project directory and initialize
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Directory $PROJECT_DIR already exists. Remove or choose a different directory.${NC}"
    exit 1
fi

mkdir "$PROJECT_DIR"
cd "$PROJECT_DIR"
yarn init -y
yarn add @aztec/aztec.js@$AZTEC_VERSION @aztec/noir-contracts.js@$AZTEC_VERSION typescript @types/node

# Step 2: Create Nargo.toml
cat << EOF > Nargo.toml
[package]
name = "${PROJECT_DIR}"
type = "contract"
authors = []
compiler_version = ">=$AZTEC_VERSION"

[dependencies]
aztec = { git="https://github.com/AztecProtocol/aztec-packages/", tag="aztec-packages-v$AZTEC_VERSION", directory="noir-projects/aztec-nr/aztec" }
EOF

# Step 3: Create src directory and main.nr for the token contract
mkdir -p src
cat << EOF > src/main.nr
contract $CONTRACT_NAME {
    use dep::aztec::{
        context::{ PrivateContext, PublicContext },
        state_vars::{ Map, PublicState },
        types::address::AztecAddress
    };

    private balances: Map<AztecAddress, Field>;
    public total_supply: PublicState<Field>;

    public fn constructor(admin: AztecAddress, name: str, symbol: str, decimals: u8) {
        let ctx = PublicContext::new();
        total_supply.write(ctx, 0);
    }

    private fn mint_to_private(ctx: PrivateContext, recipient: AztecAddress, amount: Field) {
        balances.at(recipient).add(amount);
        total_supply.add(ctx, amount);
    }

    private fn transfer_private(ctx: PrivateContext, from: AztecAddress, to: AztecAddress, amount: Field) {
        assert(balances.at(from).read() >= amount, "Insufficient balance");
        balances.at(from).sub(amount);
        balances.at(to).add(amount);
    }

    private fn balance_of_private(ctx: PrivateContext, owner: AztecAddress) -> Field {
        balances.at(owner).read()
    }

    public fn get_total_supply(ctx: PublicContext) -> Field {
        total_supply.read(ctx)
    }
}
EOF

# Step 4: Create index.ts for deployment
cat << EOF > index.ts
import { getSchnorrAccount } from '@aztec/accounts/schnorr';
import { createPXEClient, waitForPXE } from '@aztec/aztec.js';
import { ${CONTRACT_NAME} } from './target/${PROJECT_DIR}.js';
import { createLogger } from '@aztec/aztec.js';

const PXE_URL = '$PXE_URL';
const logger = createLogger('token');

async function main() {
    const pxe = createPXEClient(PXE_URL);
    await waitForPXE(pxe, logger);

    const adminWallet = await getSchnorrAccount(pxe, '$ADMIN_SECRET', '$ADMIN_SALT').deploy();
    const adminAddress = adminWallet.getAddress();

    logger.info('Deploying $CONTRACT_NAME...');
    const contract = await ${CONTRACT_NAME}.deploy(adminWallet, adminAddress, 'MyToken', 'MTK', 18)
        .send()
        .deployed();
    logger.info(\`Token contract deployed at \${contract.address}\`);

    const initialSupply = 1_000_000n;
    await contract.methods.mint_to_private(adminAddress, initialSupply).send().wait();
    logger.info(\`Minted \${initialSupply} tokens to \${adminAddress}\`);

    const balance = await contract.methods.balance_of_private(adminAddress).simulate();
    logger.info(\`Admin balance: \${balance}\`);
}

main().catch(console.error);
EOF

# Step 5: Compile the contract
echo -e "${GREEN}Compiling the contract...${NC}"
nargo compile

# Step 6: Generate TypeScript bindings
echo -e "${GREEN}Generating TypeScript bindings...${NC}"
aztec-cli codegen target/${PROJECT_DIR}.json

# Step 7: Run the deployment script
echo -e "${GREEN}Running deployment script...${NC}"
if ! ts-node index.ts; then
    echo -e "${RED}Deployment failed. Ensure the Aztec sandbox is running at $PXE_URL.${NC}"
    exit 1
fi

echo -e "${GREEN}Token contract setup and deployment complete!${NC}"


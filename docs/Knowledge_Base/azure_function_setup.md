# Azure Functions Python Development on Mac

- Uses Visual Studio Code

## Prerequisites

Before setting up Azure Functions development on Mac, ensure you have the following installed:

### 1. Homebrew

Homebrew is the package manager for macOS that we'll use to install dependencies.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

For more information: [Homebrew](https://brew.sh/)

### 2. Miniconda or Anaconda

Azure Functions supports Python 3.8, 3.9, 3.10, and 3.11. We'll use conda to manage Python environments.

Install Miniconda (lightweight) using Homebrew:

```bash
brew install --cask miniconda
```

Or install Anaconda (full distribution):

```bash
brew install --cask anaconda
```

After installation, initialize conda for your shell:

```bash
conda init zsh
```

Restart your terminal, then verify installation:

```bash
conda --version
python --version
```

For more information: [Miniconda](https://docs.conda.io/en/latest/miniconda.html) | [Anaconda](https://www.anaconda.com/)

### 3. Visual Studio Code

Download and install Visual Studio Code:

```bash
brew install --cask visual-studio-code
```

Or download directly from: [Visual Studio Code](https://code.visualstudio.com/)

### 4. Azure CLI (Optional but Recommended)

The Azure CLI is useful for managing Azure resources:

```bash
brew install azure-cli
```

Verify installation:

```bash
az --version
```

Login to Azure:

```bash
az login
```

For more information: [Install Azure CLI on macOS](https://learn.microsoft.com/cli/azure/install-azure-cli-macos)

## Setup

### Install Azure Functions Core Tools

Azure Functions Core Tools lets you develop and test your functions on your local computer.

Install using Homebrew:

```bash
brew tap azure/functions
brew install azure-functions-core-tools@4
```

If upgrading on a machine that already has Core Tools installed:

```bash
brew link --overwrite azure-functions-core-tools@4
```

Verify installation:

```bash
func --version
```

For more information: [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local)

### Install Azure Functions Extension for Visual Studio Code

1. Open Visual Studio Code
2. Go to Extensions (⌘+Shift+X)
3. Search for "Azure Functions"
4. Install the extension published by Microsoft (`ms-azuretools.vscode-azurefunctions`)

Or install via command line:

```bash
code --install-extension ms-azuretools.vscode-azurefunctions
```

### Install Python Extension for Visual Studio Code

The Python extension provides rich support for Python development:

1. Open Visual Studio Code
2. Go to Extensions (⌘+Shift+X)
3. Search for "Python"
4. Install the extension published by Microsoft (`ms-python.python`)

Or install via command line:

```bash
code --install-extension ms-python.python
```

## Getting Started

### Create a New Azure Functions Project

1. **Open VS Code** and press `⌘+Shift+P` to open the command palette
2. Type and select `Azure Functions: Create New Project`
3. Select a folder for your project
4. Choose **Python** as the language
5. Select your Python interpreter (from your conda environment)
6. Choose a template for your first function:
    - **HTTP trigger** - responds to HTTP requests
    - **Timer trigger** - runs on a schedule
    - **Blob trigger** - processes blob storage events
    - And more...

7. Provide a function name
8. For HTTP trigger, select authorization level:
    - **Anonymous** - no authentication required
    - **Function** - requires a function key
    - **Admin** - requires a master key

### Project Structure

After creating a project, you'll see the following structure:

```
MyFunctionApp/
├── .venv/                  # Virtual environment (if using venv)
├── .vscode/                # VS Code settings
│   ├── extensions.json
│   ├── launch.json
│   ├── settings.json
│   └── tasks.json
├── function_name/          # Your function folder
│   ├── __init__.py        # Function code
│   └── function.json      # Function configuration
├── .funcignore            # Files to ignore when deploying
├── .gitignore
├── host.json              # Global configuration
├── local.settings.json    # Local environment variables
└── requirements.txt       # Python dependencies
```

### Run Functions Locally

1. **Create and activate a conda environment**:

    ```bash
    # Create a new conda environment with Python 3.11
    conda create -n azurefunctions python=3.11
    
    # Activate the environment
    conda activate azurefunctions
    ```

2. **Install dependencies**:

    ```bash
    pip install -r requirements.txt
    ```

3. **Configure VS Code to use the conda environment**:
    - Press `⌘+Shift+P` and select `Python: Select Interpreter`
    - Choose the conda environment you created (e.g., `Python 3.11.x ('azurefunctions')`)

4. **Start the function app**:

    ```bash
    func start
    ```

    Or press `F5` in VS Code to start debugging

5. **Test the function**: The terminal will show the local URL (typically `http://localhost:7071/api/your-function-name`)

### Deploy to Azure

#### Using VS Code

1. Press `⌘+Shift+P` and select `Azure Functions: Deploy to Function App`
2. Select your subscription
3. Choose to create a new Function App or select an existing one
4. Follow the prompts to configure:

    - Globally unique name
    - Runtime (Python 3.11)
    - Region
    - Operating system (Linux)

#### Using Azure CLI

```bash
# Create a resource group
az group create --name MyResourceGroup --location eastus

# Create a storage account
az storage account create --name mystorageaccount --resource-group MyResourceGroup --location eastus --sku Standard_LRS

# Create a function app
az functionapp create --resource-group MyResourceGroup --consumption-plan-location eastus \
  --runtime python --runtime-version 3.11 --functions-version 4 \
  --name MyFunctionApp --storage-account mystorageaccount --os-type Linux

# Deploy the code
func azure functionapp publish MyFunctionApp
```

### Configure Application Settings

Local settings are stored in `local.settings.json` and are **not** deployed to Azure. To configure settings in Azure:

#### Using VS Code

1. Open the Azure extension
2. Find your Function App
3. Right-click on "Application Settings"
4. Select "Add New Setting"

#### Using Azure CLI

```bash
az functionapp config appsettings set --name MyFunctionApp --resource-group MyResourceGroup \
  --settings "SETTING_NAME=value"
```

### Best Practices

1. **Use conda environments** to isolate dependencies and manage Python versions
2. **Keep secrets out of code** - use Application Settings or Azure Key Vault
3. **Test locally** before deploying
4. **Use logging** - `logging.info()` instead of `print()`
5. **Handle errors gracefully** with try-except blocks
6. **Set appropriate timeout values** in `host.json`
7. **Monitor your functions** using Application Insights
8. **Use managed identities** for authentication when possible

### Common Issues on Mac

#### Issue: Conda not found after installation

**Solution**: Initialize conda and restart terminal:

```bash
conda init zsh
# Restart terminal
```

#### Issue: Permission denied when installing packages

**Solution**: Ensure you're in an activated conda environment:

```bash
conda activate azurefunctions
pip install package-name
```

#### Issue: func command not found

**Solution**: Restart terminal or add Homebrew to PATH:

```bash
echo 'export PATH="/opt/homebrew/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### Issue: Python version mismatch

**Solution**: Ensure your conda environment Python version matches Azure runtime:

```bash
# Check current environment version
conda activate azurefunctions
python --version

# Create a new environment with specific Python version if needed
conda create -n azurefunctions python=3.11

# Update function app settings if needed
az functionapp config set --name MyFunctionApp --resource-group MyResourceGroup \
  --linux-fx-version "Python|3.11"
```

#### Issue: VS Code not detecting conda environment

**Solution**: Ensure conda is in your PATH and restart VS Code:

```bash
# Add conda to PATH (if using Miniconda installed via Homebrew)
echo 'export PATH="/opt/homebrew/Caskroom/miniconda/base/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

## References

- [Azure Functions Python Developer Guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)
- [Azure Functions Core Tools Reference](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
- [VSCode Azure Functions Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
- [VSCode Azure Functions Wiki](https://github.com/Microsoft/vscode-azurefunctions/wiki)
- [Install Azure CLI on macOS](https://learn.microsoft.com/cli/azure/install-azure-cli-macos)
- [Azure Functions Triggers and Bindings](https://learn.microsoft.com/azure/azure-functions/functions-triggers-bindings)
- [Azure Functions Best Practices](https://learn.microsoft.com/azure/azure-functions/functions-best-practices)
- [Azure Functions Pricing](https://azure.microsoft.com/pricing/details/functions/)
- [Homebrew](https://brew.sh/)
- [Conda User Guide](https://docs.conda.io/projects/conda/en/latest/user-guide/index.html)
- [Managing Conda Environments](https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html)
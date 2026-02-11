# Model Context Protocol (MCP) Servers Overview

## What is an MCP Server?

The **Model Context Protocol (MCP)** is an open standard that enables AI assistants like GitHub Copilot, Claude, and other LLMs to securely connect to external data sources and tools. An MCP server is a program that implements this protocol to expose specific capabilities, data, or services to AI assistants.

Think of MCP servers as specialized plugins or extensions that give AI assistants superpowers:

- Access to databases, APIs, and file systems
- Integration with business tools (Slack, Jira, GitHub, etc.)
- Custom domain-specific operations
- Real-time data retrieval and manipulation

### Key Concepts

**MCP Architecture:**
```
AI Assistant (Client) <--> MCP Server <--> Resources/Tools/Data
```

**Core Components:**

- **Resources**: Data or content the AI can read (files, database records, API responses)
- **Tools**: Actions the AI can perform (run queries, create records, execute commands)
- **Prompts**: Templated interactions or workflows
- **Sampling**: Ability for servers to request AI completions

## Why Create an MCP Server?

### Use Cases for Building Custom MCP Servers

1. **Enterprise Data Access**

    - Connect AI to internal databases, data warehouses, or document repositories
    - Enable AI to query proprietary data sources securely
    - Provide context from company wikis, knowledge bases, or CRMs

2. **Workflow Automation**

    - Create custom tools for domain-specific tasks
    - Automate complex multi-step processes
    - Integrate with existing business systems (ERP, monitoring tools, etc.)

3. **Specialized Domain Knowledge**

    - Expose industry-specific APIs and data
    - Provide access to scientific instruments or simulation systems
    - Enable AI to interact with IoT devices or industrial equipment

4. **Security and Compliance**

    - Control exactly what data AI assistants can access
    - Implement custom authentication and authorization
    - Audit and log all AI interactions with sensitive systems

5. **Development Tools**

    - Create specialized debugging or testing tools
    - Integrate with CI/CD pipelines
    - Provide access to deployment systems and infrastructure

### Benefits

- **Standardized Interface**: One implementation works across multiple AI assistants
- **Security**: Servers run locally or in controlled environments
- **Modularity**: Mix and match different MCP servers for different capabilities
- **Reusability**: Share servers across teams and organizations

## How to Use Existing MCP Servers

### Popular MCP Servers

**Official Servers (by Anthropic):**

- `@modelcontextprotocol/server-filesystem` - File system access
- `@modelcontextprotocol/server-github` - GitHub integration
- `@modelcontextprotocol/server-postgres` - PostgreSQL database access
- `@modelcontextprotocol/server-sqlite` - SQLite database access
- `@modelcontextprotocol/server-google-drive` - Google Drive integration
- `@modelcontextprotocol/server-slack` - Slack integration

**Azure & Microsoft Ecosystem:**

- `azure-mcp` - Azure resource management and operations
- Various Azure service-specific servers (Cosmos DB, App Service, etc.)

**Community Servers:**

- Browse the [MCP Server Registry](https://github.com/modelcontextprotocol/servers)

### Installing MCP Servers

#### For VS Code / GitHub Copilot

1. **Install the MCP server package** (typically via npm, pip, or binary):

        ```bash
        # Node.js-based server
        npm install -g @modelcontextprotocol/server-filesystem

        # Python-based server
        pip install mcp-server-example
        ```

2. **Configure in VS Code settings** (`settings.json`):

        ```json
        {
        "mcp.servers": {
        "filesystem": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/allowed/directory"]
        },
        "postgres": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-postgres"],
            "env": {
            "POSTGRES_CONNECTION_STRING": "postgresql://user:pass@localhost/db"
            }
        }
        }
        }
        ```

3. **Reload VS Code** to activate the servers

#### For Claude Desktop

Edit the Claude configuration file:

**macOS:** `~/Library/Application Support/Claude/claude_desktop_config.json`

**Windows:** `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/Users/username/Documents"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your-token-here"
      }
    }
  }
}
```

### Using MCP Servers in AI Conversations

Once configured, you can naturally interact with MCP server capabilities:

**Example with filesystem server:**
```
You: "Read the contents of config.json in my project"
AI: [Uses filesystem server to read the file]

You: "Create a new file called test.py with a hello world script"
AI: [Uses filesystem server to create the file]
```

**Example with database server:**
```
You: "Show me all users created in the last 30 days"
AI: [Queries the database via MCP server]

You: "Create a new user record for john.doe@example.com"
AI: [Executes INSERT via MCP server]
```

### Best Practices

1. **Principle of Least Privilege**: Configure servers with minimal necessary permissions
2. **Use Environment Variables**: Store credentials and sensitive data in env vars, not config
3. **Start Small**: Begin with one or two servers and expand as needed
4. **Review Logs**: Monitor MCP server activity for debugging and security
5. **Update Regularly**: Keep server packages updated for security and features

## Creating Your Own MCP Server

### Quick Start

**TypeScript/Node.js:**

```bash
# Use the official template
npx @modelcontextprotocol/create-server my-server

cd my-server
npm install
npm run build
```

**Python:**

```bash
# Install MCP SDK
pip install mcp

# Create server file
# (See official Python examples in MCP documentation)
```

### Basic Server Structure

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

const server = new Server({
  name: "my-custom-server",
  version: "1.0.0",
}, {
  capabilities: {
    resources: {},
    tools: {},
  },
});

// Define a tool
server.setRequestHandler("tools/call", async (request) => {
  if (request.params.name === "my_tool") {
    // Implement tool logic
    return {
      content: [{ type: "text", text: "Tool executed successfully" }],
    };
  }
});

// Start server
const transport = new StdioServerTransport();
await server.connect(transport);
```

## Resources

- **Official Documentation**: https://modelcontextprotocol.io
- **MCP Specification**: https://spec.modelcontextprotocol.io
- **Server Examples**: https://github.com/modelcontextprotocol/servers
- **TypeScript SDK**: https://github.com/modelcontextprotocol/typescript-sdk
- **Python SDK**: https://github.com/modelcontextprotocol/python-sdk

## Related Topics

- [Azure Function Setup](azure_function_setup.md)
- [Visual Studio Code Remote SSH](visual_studio_code_remote_ssh.md)

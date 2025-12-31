# CHANGELOG

## 0.0.1

### Initial Release

First stable release of `local_websocket` - a pure Dart library for local network WebSocket communication.

#### Core Features

- **WebSocket Server** - Create WebSocket servers with minimal configuration
  - Two messaging modes: Broadcast (echo: false) and Echo (echo: true)
  - Custom server metadata/details support
  - Automatic client management
  - Real-time client tracking with reactive streams
  
- **WebSocket Client** - Simple client connection and messaging
  - Automatic UUID generation for each client
  - Custom client metadata via query parameters
  - Reactive message and connection streams
  - Clean connection/disconnection handling
  
- **Network Scanner** - Automatic server discovery on local networks
  - Subnet scanning (e.g., 192.168.1.0/24)
  - Configurable scan intervals and ports
  - HTTP header-based server identification
  - Returns discovered servers with metadata

#### Delegate System

Extensible delegate-based architecture for customization:

- **RequestAuthenticationDelegate** - Authenticate HTTP requests before WebSocket upgrade
  
- **ClientValidationDelegate** - Validate clients after WebSocket connection
  - Custom validation logic support
  - Max clients enforcement
  - Metadata validation
  
- **ClientConnectionDelegate** - Handle connection lifecycle events
  - Perfect for logging, analytics, and notifications
  
- **MessageValidationDelegate** - Validate individual messages
  - Content filtering support
  - Rate limiting capabilities
  - Message format validation

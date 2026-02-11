# iOS Application Development with ArcGIS in Visual Studio Code

This guide walks you through setting up Visual Studio Code for iOS development, creating a new project with the ArcGIS Swift API, and building a simple map application.

## Prerequisites

Before starting, ensure you have:

- **macOS**: iOS development requires a Mac
- **Xcode**: Install from the App Store (includes iOS SDK and simulators)
- **Xcode Command Line Tools**: Run `xcode-select --install` in Terminal
- **Homebrew**: Package manager for macOS ([https://brew.sh](https://brew.sh))
- **Visual Studio Code**: Download from [https://code.visualstudio.com](https://code.visualstudio.com)

## Part 1: Install Requirements for VS Code iOS Development

### Step 1: Install Xcode Build Server

The xcode-build-server provides LSP (Language Server Protocol) integration for Xcode projects in VS Code.

```bash
brew install xcode-build-server
```

### Step 2: Install VS Code Extensions

Install the following extensions in Visual Studio Code:

1. **Swift Extension** (official)

    - Extension ID: `sde.languageserver.swift`
    - Open VS Code and go to Extensions (`Cmd + Shift + X`)
    - Search for "Swift" and install the official extension from the Swift community

2. **Sweetpad Extension**

    - Extension ID: `Sweetpad.sweetpad`
    - Provides iOS-specific development features (build, run, debug)
    - Documentation: [https://sweetpad.hyzyla.dev/](https://sweetpad.hyzyla.dev/)

### Step 3: Verify Installation

1. Open Terminal and verify Xcode is properly configured:

    ```bash
    xcode-select -p
    ```
    
    Should output: `/Applications/Xcode.app/Contents/Developer`

2. Verify Swift is available:

    ```bash
    swift --version
    ```

## Part 2: Create a New iOS Project with ArcGIS Swift API

### Option A: Create Project Using Xcode (Easiest)

Since VS Code doesn't have a built-in iOS project generator, we'll create the initial project structure using Xcode:

1. Open Xcode
2. Select **File → New → Project**
3. Choose **iOS → App**
4. Configure your project:
    - **Product Name**: `ArcGISMapApp`
    - **Team**: Select your Apple Developer account (or leave as "None" for simulator-only testing)
    - **Organization Identifier**: Use a reverse domain (e.g., `com.yourname`)
    - **Interface**: **SwiftUI**
    - **Language**: **Swift**
    - **Uncheck** "Include Tests" (optional)
5. Save the project to your desired location
6. Close Xcode

### Option B: Create Project from Terminal/VS Code (No Xcode GUI)

You can create an iOS project entirely from the command line using `xcodegen` or by manually creating the project structure:

#### Step 1: Install xcodegen

```bash
brew install xcodegen
```

#### Step 2: Create Project Directory

```bash
mkdir ArcGISMapApp
cd ArcGISMapApp
```

#### Step 3: Create project.yml Configuration

Create a file named `project.yml` in your project root:

```yaml
name: ArcGISMapApp
options:
  bundleIdPrefix: com.yourname
  deploymentTarget:
    iOS: "16.0"

packages:
  ArcGIS:
    url: https://github.com/Esri/arcgis-maps-sdk-swift
    majorVersion: 200.5.0

targets:
  ArcGISMapApp:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - ArcGISMapApp
    dependencies:
      - package: ArcGIS
        product: ArcGIS
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.yourname.ArcGISMapApp
      DEVELOPMENT_TEAM: "" # Add your team ID if you have one
      INFOPLIST_FILE: ArcGISMapApp/Info.plist
    info:
      path: ArcGISMapApp/Info.plist
      properties:
        CFBundleDisplayName: ArcGISMapApp
        CFBundleShortVersionString: "1.0"
        CFBundleVersion: "1"
        UILaunchScreen: {}
        ArcGISMapItemID: "41281c51f9de45edaf1c8ed44bb10e30"
        ArcGISAPIKey: "YOUR-API-KEY-HERE"
        NSLocationWhenInUseUsageDescription: "We need your location to show you on the map"
```

#### Step 4: Create Source Files

Create the directory structure:

```bash
mkdir -p ArcGISMapApp
```

Create `ArcGISMapApp/ArcGISMapAppApp.swift`:

```bash
cat > ArcGISMapApp/ArcGISMapAppApp.swift << 'EOF'
import SwiftUI
import ArcGIS

@main
struct ArcGISMapAppApp: App {
    init() {
        // Configure ArcGIS API key from Info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "ArcGISAPIKey") as? String,
           !apiKey.isEmpty && apiKey != "YOUR-API-KEY-HERE" {
            ArcGISEnvironment.apiKey = APIKey(apiKey)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
EOF
```

Create `ArcGISMapApp/ContentView.swift`:

```bash
cat > ArcGISMapApp/ContentView.swift << 'EOF'
import SwiftUI
import ArcGIS

struct ContentView: View {
    @State private var map: Map?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if let map = map {
                MapView(map: map)
                    .edgesIgnoringSafeArea(.all)
            } else if let error = errorMessage {
                Text("Error loading map: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ProgressView("Loading map...")
            }
        }
        .task {
            await loadMap()
        }
    }
    
    func loadMap() async {
        // Read map ID from Info.plist
        guard let mapID = Bundle.main.object(forInfoDictionaryKey: "ArcGISMapItemID") as? String else {
            errorMessage = "Map ID not found in Info.plist"
            return
        }
        
        do {
            // Create a portal item from the map ID
            let portal = Portal.arcGISOnline(connection: .anonymous)
            let portalItem = PortalItem(portal: portal, id: Item.ID(mapID)!)
            
            // Create map from portal item
            let loadedMap = Map(item: portalItem)
            
            // Load the map
            try await loadedMap.load()
            
            self.map = loadedMap
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
EOF
```

#### Step 5: Generate Xcode Project

```bash
xcodegen generate
```

This creates `ArcGISMapApp.xcodeproj` from your `project.yml` configuration.

#### Step 6: Open in VS Code

```bash
code .
```

Now continue with [Step 3: Configure VS Code for the Project](#step-3-configure-vs-code-for-the-project) below.

### Step 2: Add ArcGIS Swift SDK Dependency

The ArcGIS Swift SDK is distributed via Swift Package Manager.

#### If you used Option A (Xcode):

1. Open your project in VS Code:

    ```bash
    code /path/to/ArcGISMapApp
    ```

2. Open the Xcode project file in Xcode temporarily to add the package:

    ```bash
    open ArcGISMapApp.xcodeproj
    ```

3. In Xcode, go to **File → Add Package Dependencies**

4. In the search bar, enter:

    ```
    https://github.com/Esri/arcgis-maps-sdk-swift
    ```

5. Select the package and click **Add Package**

6. Choose the following products to add:

    - **ArcGIS** (main SDK)
    - **ArcGISToolkit** (optional, for additional UI components)

7. Click **Add Package**

8. Close Xcode and return to VS Code

#### If you used Option B (xcodegen):

The dependency was already added in your `project.yml` file! The ArcGIS SDK will be fetched when you first build the project. No additional steps needed.

### Step 3: Configure VS Code for the Project

1. Open the project folder in VS Code:

    ```bash
    cd /path/to/ArcGISMapApp
    code .
    ```

2. Open the **Sweetpad** panel in VS Code (left sidebar)

3. If your project isn't automatically detected, manually select it:
    - Click on the Sweetpad icon
    - Browse to your `.xcodeproj` file

4. This will create `.vscode/settings.json`:

    ```json
    {
        "sweetpad.build.xcodeWorkspacePath": "ArcGISMapApp.xcodeproj/project.xcworkspace"
    }
    ```

5. **Reload VS Code** (`Cmd + Shift + P` → "Developer: Reload Window")

6. Generate the build server configuration:

    - Open Command Palette (`Cmd + Shift + P`)
    - Type "Sweetpad: Generate Build Server Config"
    - Select your project target

This creates a `buildServer.json` file in your project root.

7. Build the project to verify setup:
    - Open Command Palette (`Cmd + Shift + P`)
    - Run "Sweetpad: Build Without Run"
    - Wait for the build to complete (this resolves dependencies)

### Step 4: Configure Debug Settings

1. Open the Debug panel in VS Code (`Cmd + Shift + D`)

2. Click **"Create a launch.json file"**

3. Select **"Sweetpad (LLDB)"** from the dropdown

4. This creates `.vscode/launch.json`:
   ```json
   {
       "version": "0.2.0",
       "configurations": [
           {
               "type": "sweetpad-lldb",
               "request": "attach",
               "name": "Attach to running app (SweetPad)",
               "preLaunchTask": "sweetpad: launch"
           }
       ]
   }
   ```

5. Save the file

## Part 3: Build a Simple Map Application

### Step 1: Configure Info.plist for Map ID and API Key

1. Open `ArcGISMapApp/Info.plist` (or create it if it doesn't exist)

2. Add custom keys for the map ID and API key:
   ```xml
   <key>ArcGISMapItemID</key>
   <string>41281c51f9de45edaf1c8ed44bb10e30</string>
   <key>ArcGISAPIKey</key>
   <string>YOUR-API-KEY-HERE</string>
   ```

   **Map ID Configuration:**

    - Replace the map ID value with an actual ArcGIS Online map ID
    - Example IDs:

        - `41281c51f9de45edaf1c8ed44bb10e30` - Topographic
        - `d5e02a0c1f2b4ec399823fdd3c2fdebd` - Streets
        - `7dc6cea0b1764a1f9af2e679f642f0f5` - Imagery
    - Or create your own map at [https://www.arcgis.com](https://www.arcgis.com)

   **API Key Configuration:**

    - Get an API key from [https://developers.arcgis.com](https://developers.arcgis.com)
    - Replace `YOUR-API-KEY-HERE` with your actual API key
    - For development/testing with **public maps only**, you can leave this as-is or use an empty string
    - For production apps or accessing secured services, a valid API key is required

3. To support location services (optional), add this key:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>We need your location to show you on the map</string>
   ```

### Step 2: Create the Map View

1. Open `ArcGISMapApp/ContentView.swift`

2. Replace the contents with:

```swift
import SwiftUI
import ArcGIS

struct ContentView: View {
    @State private var map: Map?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            if let map = map {
                MapView(map: map)
                    .edgesIgnoringSafeArea(.all)
            } else if let error = errorMessage {
                Text("Error loading map: \(error)")
                    .foregroundColor(.red)
                    .padding()
            } else {
                ProgressView("Loading map...")
            }
        }
        .task {
            await loadMap()
        }
    }
    
    func loadMap() async {
        // Read map ID from Info.plist
        guard let mapID = Bundle.main.object(forInfoDictionaryKey: "ArcGISMapItemID") as? String else {
            errorMessage = "Map ID not found in Info.plist"
            return
        }
        
        do {
            // Create a portal item from the map ID
            let portal = Portal.arcGISOnline(connection: .anonymous)
            let portalItem = PortalItem(portal: portal, id: Item.ID(mapID)!)
            
            // Create map from portal item
            let loadedMap = Map(item: portalItem)
            
            // Load the map
            try await loadedMap.load()
            
            self.map = loadedMap
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
```

### Step 3: Update the App Entry Point

1. Open `ArcGISMapApp/ArcGISMapAppApp.swift` (or whatever your app file is named)

2. Ensure it looks like this:

```swift
import SwiftUI
import ArcGIS

@main
struct ArcGISMapAppApp: App {
    init() {
        // Configure ArcGIS API key from Info.plist
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "ArcGISAPIKey") as? String,
           !apiKey.isEmpty && apiKey != "YOUR-API-KEY-HERE" {
            ArcGISEnvironment.apiKey = APIKey(apiKey)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

**How this works:**

- The app reads the `ArcGISAPIKey` value from `Info.plist` at launch
- If a valid API key is found (not empty or placeholder), it configures the ArcGIS environment
- For development with public maps, you can skip configuring an API key
- For production or secured services, add your API key to the plist file

### Step 4: Build and Run the Application

#### Using VS Code:

1. Press **F5** or click the **Run** button in the Debug panel

2. Select the target device:

    - Choose an iOS simulator from the Sweetpad panel
    - Or connect a physical device (requires Apple Developer account)

3. The app will build, launch, and the debugger will attach

4. You should see a map displayed in the simulator/device

#### Using Terminal (alternative):

```bash
# List available simulators
xcrun simctl list devices

# Build for simulator
xcodebuild -project ArcGISMapApp.xcodeproj \
    -scheme ArcGISMapApp \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPhone 15'

# Run on simulator
xcrun simctl boot "iPhone 15"
xcrun simctl install booted path/to/ArcGISMapApp.app
xcrun simctl launch booted com.yourname.ArcGISMapApp
```

### Step 5: Changing the Map or API Key

To use a different map or update your API key, simply modify the values in `Info.plist`:

1. Open `Info.plist`
2. **To change the map**: Update the `ArcGISMapItemID` value to another ArcGIS Online map ID
3. **To add/update API key**: Update the `ArcGISAPIKey` value with your API key
4. Rebuild and run the app

Example map IDs to try:

- `41281c51f9de45edaf1c8ed44bb10e30` - Topographic
- `d5e02a0c1f2b4ec399823fdd3c2fdebd` - Streets
- `7dc6cea0b1764a1f9af2e679f642f0f5` - Imagery

**Note**: Keeping configuration values in `Info.plist` makes it easy to change settings without modifying code, which is especially useful for:

- Switching between development and production API keys
- Testing different maps
- Managing app configurations across different environments

## Debugging and Development

### Setting Breakpoints

1. Click in the gutter (left of line numbers) to set breakpoints
2. Press **F5** to run with debugger attached
3. App will pause at breakpoints
4. Use the Debug toolbar to step through code

### Viewing Console Output

- Debug console appears at the bottom of VS Code
- Use `print()` statements in Swift for logging
- View real-time logs during development

### Common Issues

**Issue**: "No bundle URL present" error

- **Solution**: Clean build folder and rebuild

**Issue**: ArcGIS SDK not found

- **Solution**: Ensure package was added via Xcode's Package Dependencies
- Verify `Package.swift` or project file includes the dependency

**Issue**: Simulator doesn't launch

- **Solution**: Ensure Xcode Command Line Tools are set correctly:
    ```bash
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
    ```

**Issue**: Map doesn't load

- **Solution**: Check the map ID in `Info.plist` is valid
- Ensure internet connectivity (maps load from ArcGIS Online)

## Additional Resources

- **VS Code iOS Setup**: [https://blog.kulman.sk/vscode-ios-setup/](https://blog.kulman.sk/vscode-ios-setup/)
- **Sweetpad Documentation**: [https://sweetpad.hyzyla.dev/](https://sweetpad.hyzyla.dev/)
- **ArcGIS Swift SDK**: [https://developers.arcgis.com/swift/](https://developers.arcgis.com/swift/)
- **ArcGIS Maps SDK Documentation**: [https://developers.arcgis.com/swift/maps-2d/](https://developers.arcgis.com/swift/maps-2d/)
- **Swift Package Manager**: [https://swift.org/package-manager/](https://swift.org/package-manager/)

## Next Steps

- **Add location tracking to show user position on the map** - [Location and sensors tutorial](https://developers.arcgis.com/swift/device-location/)
- **Implement map interactions (zoom, pan, tap to identify)** - [Identify features tutorial](https://developers.arcgis.com/swift/identify-features/) and [Display map viewpoint](https://developers.arcgis.com/swift/display-map/)
- **Add search functionality** - [Search for an address or place tutorial](https://developers.arcgis.com/swift/search-for-an-address/)
- **Display custom graphics and symbols on the map** - [Display graphics tutorial](https://developers.arcgis.com/swift/add-a-point-line-and-polygon/)
- **Integrate with ArcGIS services** - [Geocoding tutorial](https://developers.arcgis.com/swift/search-for-an-address/), [Routing tutorial](https://developers.arcgis.com/swift/find-a-route/), and [Network analysis](https://developers.arcgis.com/swift/network-analysis/)

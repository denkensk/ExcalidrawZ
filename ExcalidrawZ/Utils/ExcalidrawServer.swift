//
//  ExcalidrawServer.swift
//  ExcalidrawZ
//
//  Created by Dove Zachary on 2024/8/9.
//

import Foundation
import FlyingFox
import FlyingSocks

import ChocofordUI

struct ExcalidrawServerLogger: Logging {
    func logDebug(_ debug: @autoclosure () -> String) {
            
    }
    
    func logInfo(_ info: @autoclosure () -> String) {
        
    }
    
    func logWarning(_ warning: @autoclosure () -> String) {
        
    }
    
    func logError(_ error: @autoclosure () -> String) {
        
    }
    
    func logCritical(_ critical: @autoclosure () -> String) {
        
    }
}

class ExcalidrawServer {
    #if DEBUG
    static let port: UInt16 = 8486
    #else
    // Self-built copy: the official release binds 8487, and whichever app
    // starts second would silently load the other app's Excalidraw core.
    static let port: UInt16 = 8497
    #endif
    /// The bundled Excalidraw page served by this server.
    static let indexURL = URL(string: "http://127.0.0.1:\(port)/index.html")!
    // Keep both the editor resources and local Viewer transport on loopback.
    let server = HTTPServer(
        address: try! .inet(ip4: "127.0.0.1", port: ExcalidrawServer.port),
        logger: ExcalidrawServerLogger()
    )
    init(autoStart: Bool = true) {
        if isPreview { return }
        if autoStart {
            Task {
                try? await self.start()
            }
        }
    }
    
    deinit {
        let server = self.server
        Task {
            await server.stop()
        }
    }
    
    func start() async throws {
#if os(macOS)
        // Register before the catch-all resource route.
        await server.appendRoute("GET /viewer/*", to: ViewerLocalRouteHandler())
#endif
        await server.appendRoute(
            "GET /*",
            to: .directory(
                for: .main,
                subPath: "excalidraw-latest",
                serverPath: ""
            )
        )
        try await server.run()
    }
    
    
    func stop() async {
        await server.stop()
    }
}

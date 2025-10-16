//
//  PropertyWrappers.swift
//  FitnessTracker
//
//  Created by Oskar Zhang on 10/16/25.
//

import Foundation

final class Container {
    static let shared = Container()
    
    private var factories: [String: () -> Any] = [:]
    private var singletons: [String: Any] = [:]
    
    private init() {}
    
    // Register a factory (creates new instance each time)
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    // Register a singleton (creates once, reuses)
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        if singletons[key] == nil {
            singletons[key] = factory()
        }
    }
    
    // Resolve a dependency
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        
        // Check singletons first
        if let singleton = singletons[key] as? T {
            return singleton
        }
        
        // Then check factories
        if let factory = factories[key] {
            guard let instance = factory() as? T else {
                fatalError("Could not resolve \(type)")
            }
            return instance
        }
        
        fatalError("No registration found for \(type)")
    }
}

// MARK: - Property Wrapper for Convenience
@propertyWrapper
struct Injected<T> {
    var wrappedValue: T {
        Container.shared.resolve(T.self)
    }
}

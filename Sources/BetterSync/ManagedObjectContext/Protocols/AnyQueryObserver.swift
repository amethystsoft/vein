//
//  AnyQueryObserver.swift
//  BetterSync
//
//  Created by Mia Koring on 27.10.25.
//
@MainActor
public protocol AnyQueryObserver: AnyObject {
    func appendAny(_ models: [AnyObject])
}

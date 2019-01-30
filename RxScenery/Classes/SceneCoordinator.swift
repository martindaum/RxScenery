//
//  SceneCoordinator.swift
//  Scenery
//
//  Created by Martin Daum on 08.06.18.
//  Copyright © 2018 Waterlytics. All rights reserved.
//

import Foundation
import UIKit
import RxSwift
import RxCocoa

public protocol UnwrappedViewController {}

extension UINavigationController: UnwrappedViewController {}
extension UITabBarController: UnwrappedViewController {}
extension UISplitViewController: UnwrappedViewController {}

public protocol SceneType {}

public protocol SceneCreatorType {
    func createViewController(for scene: SceneType, with sceneCoordinator: SceneCoordinator) -> UIViewController
}

public enum SceneTransitionError: Error {
    case noNavigationController
    case popNotPossible
}

public final class SceneCoordinator {
    private let window: UIWindow
    private let sceneCreator: SceneCreatorType
    private let navigationControllerClass: UINavigationController.Type
    
    public required init(window: UIWindow, initialScene: SceneType, sceneCreator: SceneCreatorType, navigationControllerClass: UINavigationController.Type = UINavigationController.self) {
        self.window = window
        self.sceneCreator = sceneCreator
        self.navigationControllerClass = navigationControllerClass
        window.rootViewController = wrappedViewController(sceneCreator.createViewController(for: initialScene, with: self))
        window.makeKeyAndVisible()
    }
}

// MARK: - ViewController creation

extension SceneCoordinator {
    public func getViewController(for scene: SceneType, wrapInNavigationController: Bool = false) -> UIViewController {
        let viewController = sceneCreator.createViewController(for: scene, with: self)
        return wrapInNavigationController ? wrappedViewController(viewController) : viewController
    }
}

// MARK: - transitions

extension SceneCoordinator {
    @discardableResult
    public func push(_ scene: SceneType, from viewController: UIViewController, animated: Bool) -> Completable {
        let subject = PublishSubject<Void>()
        let nextViewController = sceneCreator.createViewController(for: scene, with: self)
        
        guard let navigationController = viewController.navigationController else {
            subject.onError(SceneTransitionError.noNavigationController)
            return subject.asObservable().ignoreElements()
        }
        
        _ = navigationController.rx.delegate
            .sentMessage(#selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:)))
            .map { _ in }
            .bind(to: subject)
        navigationController.pushViewController(nextViewController, animated: animated)
        return subject.asObservable()
            .take(1)
            .ignoreElements()
    }
    
    @discardableResult
    public func present(_ scene: SceneType, from viewController: UIViewController, animated: Bool) -> Completable {
        let subject = PublishSubject<Void>()
        let nextViewController = wrappedViewController(sceneCreator.createViewController(for: scene, with: self))
        viewController.present(nextViewController, animated: animated, completion: {
            subject.onCompleted()
        })
        return subject.asObservable()
            .take(1)
            .ignoreElements()
    }
    
    @discardableResult
    public func changeRoot(to scene: SceneType, animated: Bool) -> Completable {
        let subject = PublishSubject<Void>()
        let nextViewController = wrappedViewController(sceneCreator.createViewController(for: scene, with: self))
        
        if animated && window.rootViewController != nil, let snapshot = self.window.snapshotView(afterScreenUpdates: true) {
            nextViewController.view.addSubview(snapshot)
            
            UIView.animate(withDuration: 0.3, animations: {
                snapshot.alpha = 0
            }, completion: { _ in
                self.window.rootViewController = nextViewController
                snapshot.removeFromSuperview()
            })
        } else {
            window.rootViewController = nextViewController
        }
        
        return subject.asObservable()
            .take(1)
            .ignoreElements()
    }
    
    private func wrappedViewController(_ viewController: UIViewController) -> UIViewController {
        if viewController is UnwrappedViewController {
            return viewController
        }
        return navigationControllerClass.init(rootViewController: viewController)
    }
}

// MARK: - pop

extension SceneCoordinator {
    @discardableResult
    public func dismiss(viewController: UIViewController, animated: Bool = true) -> Completable {
        let subject = PublishSubject<Void>()
        
        viewController.dismiss(animated: animated) {
            subject.onCompleted()
        }
        
        return subject.asObservable()
            .take(1)
            .ignoreElements()
    }
    
    @discardableResult
    public func pop(viewController: UIViewController, animated: Bool = true) -> Completable {
        let subject = PublishSubject<Void>()
        guard let navigationController = viewController.navigationController else {
            subject.onError(SceneTransitionError.popNotPossible)
            return subject.asObservable().ignoreElements()
        }
        _ = navigationController.rx.delegate
            .sentMessage(#selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:)))
            .map { _ in }
            .bind(to: subject)
        guard navigationController.popViewController(animated: animated) != nil else {
            subject.onError(SceneTransitionError.popNotPossible)
            return subject.asObservable().ignoreElements()
        }
        return subject.asObservable()
            .take(1)
            .ignoreElements()
    }
}
